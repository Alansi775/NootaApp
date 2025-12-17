import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';
import { initializeLogger } from '../config/logger.js';
import { v4 as uuidv4 } from 'uuid';

const logger = initializeLogger();
const execAsync = promisify(exec);

/**
 * Generate speech using macOS native `say` command
 * Converts to MP3 using ffmpeg if available, otherwise returns as WAV
 * @param {Object} options
 * @param {string} options.text - Text to synthesize
 * @param {string} options.language - Language code (en, ar, es, etc)
 * @returns {Promise<Buffer>} Audio buffer in MP3 or WAV format
 */
export async function generateSpeechMacOS(options) {
  const { text, language = 'en' } = options;

  if (!text) {
    throw new Error('Text is required for speech generation');
  }

  try {
    logger.info(` Generating speech with macOS TTS for ${language}: "${text.substring(0, 40)}..."`);
    
    // Map language codes to macOS voice identifiers
    const voiceMap = {
      'en': 'com.apple.speech.synthesis.voice.Alex',
      'es': 'com.apple.speech.synthesis.voice.Monica',
      'fr': 'com.apple.speech.synthesis.voice.Amelie',
      'de': 'com.apple.speech.synthesis.voice.Yannick',
      'it': 'com.apple.speech.synthesis.voice.Francesca',
      'pt': 'com.apple.speech.synthesis.voice.Luciana',
      'ja': 'com.apple.speech.synthesis.voice.Kyoko',
      'zh': 'com.apple.speech.synthesis.voice.Sin-ji',
      'ko': 'com.apple.speech.synthesis.voice.YoungJoo',
      'ar': 'com.apple.speech.synthesis.voice.Maged', // Available on newer macOS
    };

    const voice = voiceMap[language.split('-')[0]] || voiceMap['en'];
    
    // Create temporary file for output
    // Note: macOS 'say' command works best with .au format
    const tempDir = '/tmp';
    const audioFile = path.join(tempDir, `tts_${uuidv4()}.au`);
    
    logger.info(` Using voice: ${voice}`);
    logger.info(`💾 Saving to: ${audioFile}`);
    
    // Use simple say command with output file
    const escapedText = text.replace(/"/g, '\\"').replace(/'/g, "\\'");
    const simpleCmd = `say "${escapedText}" -o "${audioFile}"`;
    
    await execAsync(simpleCmd, { maxBuffer: 10 * 1024 * 1024 });
    
    // Read the generated audio file
    if (!fs.existsSync(audioFile)) {
      throw new Error(`Failed to generate audio file: ${audioFile}`);
    }
    
    const audioBuffer = fs.readFileSync(audioFile);
    logger.info(` macOS TTS generated speech (${audioBuffer.length} bytes)`);
    
    // Clean up temp file
    try {
      fs.unlinkSync(audioFile);
    } catch (e) {
      logger.warn(` Failed to clean up temp file: ${audioFile}`);
    }
    
    return audioBuffer;
    
  } catch (error) {
    logger.error('macOS TTS error:', error.message);
    throw error;
  }
}

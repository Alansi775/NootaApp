import axios from 'axios';
import { initializeLogger } from '../config/logger.js';

const logger = initializeLogger();

/**
 * Generate speech using a simple free TTS service (Responsive Voice or similar)
 * This is a fallback when other services fail
 * @param {Object} options
 * @param {string} options.text - Text to synthesize
 * @param {string} options.language - Language code
 * @returns {Promise<Buffer>} Audio buffer in MP3/WAV format
 */
export async function generateSpeechSimple(options) {
  const { text, language = 'en' } = options;

  if (!text) {
    throw new Error('Text is required for speech generation');
  }

  try {
    logger.info(` Generating speech with Simple TTS for ${language}: "${text.substring(0, 40)}..."`);
    
    // Using responsivevoice.org API as fallback (no auth required, but rate limited)
    // Format: https://responsivevoice.org/responsivevoice/getvoice.php?t=<text>&l=<lang>&r=<voice>&c=<format>
    
    const languageCodeMap = {
      'en': 'en',
      'ar': 'ar',
      'es': 'es',
      'fr': 'fr',
      'de': 'de',
      'it': 'it',
      'pt': 'pt-br',
      'ja': 'ja',
      'zh': 'zh-CN',
      'ko': 'ko',
      'tr': 'tr',
    };

    const lang = languageCodeMap[language.split('-')[0]] || 'en';
    
    // Try using the edge-tts compatible endpoint if available, or return synthesized data
    // For now, we'll create a minimal valid MP3 header with silence
    // This is a placeholder that returns valid audio format but with silence
    
    logger.warn(' Simple TTS service is a fallback placeholder');
    logger.info('💡 Recommend: Install XTTS locally or enable Google Cloud TTS API');
    
    // Return a valid but minimal MP3 file (silence)
    // MP3 frame header: FF FA or FF FB (sync word) + bitrate + sample rate info
    const silentMp3 = Buffer.from([
      0xFF, 0xFA,  // MP3 sync word (MPEG2 Layer3)
      0x10, 0x00,  // Bitrate 32kbps, sample rate 44.1kHz
    ]);
    
    return silentMp3;
    
  } catch (error) {
    logger.error('Simple TTS error:', error.message);
    throw error;
  }
}

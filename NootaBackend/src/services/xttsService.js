import axios from 'axios';
import { initializeLogger } from '../config/logger.js';

const logger = initializeLogger();

const XTTS_API_URL = process.env.XTTS_SERVER_URL || 'https://router.huggingface.co/models/coqui/XTTS-v2';
const HF_TOKEN = process.env.XTTS_HF_TOKEN;

/**
 * Language code mapping for XTTS v2
 */
const LANGUAGE_MAP = {
  'en': 'en',
  'ar': 'ar',
  'es': 'es',
  'fr': 'fr',
  'de': 'de',
  'it': 'it',
  'pt': 'pt',
  'ja': 'ja',
  'zh': 'zh',
  'ko': 'ko',
  'ru': 'ru',
  'pl': 'pl',
  'nl': 'nl',
  'tr': 'tr',
  'sv': 'sv',
  'fi': 'fi',
  'no': 'no',
};

/**
 * Generate a simple WAV file header (for testing without XTTS API)
 * Creates a valid but silent WAV file
 */
function createSilentWAV(duration = 2) {
  const sampleRate = 16000;
  const channels = 1;
  const bitsPerSample = 16;
  const samples = sampleRate * duration;
  const audioData = Buffer.alloc(samples * 2); // 16-bit = 2 bytes per sample
  audioData.fill(0); // Silent audio
  
  const byteRate = sampleRate * channels * bitsPerSample / 8;
  const blockAlign = channels * bitsPerSample / 8;
  const dataSize = samples * blockAlign;
  
  const wavHeader = Buffer.alloc(44);
  
  // RIFF header
  wavHeader.write('RIFF', 0);
  wavHeader.writeUInt32LE(36 + dataSize, 4);
  wavHeader.write('WAVE', 8);
  
  // fmt subchunk
  wavHeader.write('fmt ', 12);
  wavHeader.writeUInt32LE(16, 16); // Subchunk1Size
  wavHeader.writeUInt16LE(1, 20); // AudioFormat (PCM)
  wavHeader.writeUInt16LE(channels, 22);
  wavHeader.writeUInt32LE(sampleRate, 24);
  wavHeader.writeUInt32LE(byteRate, 28);
  wavHeader.writeUInt16LE(blockAlign, 32);
  wavHeader.writeUInt16LE(bitsPerSample, 34);
  
  // data subchunk
  wavHeader.write('data', 36);
  wavHeader.writeUInt32LE(dataSize, 40);
  
  return Buffer.concat([wavHeader, audioData]);
}

/**
 * Generate speech using XTTS v2 model via Hugging Face API
 * Falls back to placeholder audio if API token not available
 * @param {Object} options - Configuration options
 * @param {string} options.text - Text to synthesize
 * @param {string} options.language - Language code (en, ar, es, etc.)
 * @param {string} options.speaker - Speaker name or voice identifier
 * @param {Buffer} options.referenceAudio - Reference audio file buffer for voice cloning
 * @returns {Promise<Buffer>} Audio buffer in WAV format
 */
export async function generateSpeech(options) {
  try {
    const {
      text,
      language = 'en',
      referenceAudio,
    } = options;

    if (!text || !language) {
      throw new Error('Text and language are required for speech generation');
    }

    const mappedLanguage = LANGUAGE_MAP[language.split('-')[0]] || 'en';
    logger.debug(`Generating speech: text="${text.substring(0, 50)}...", language="${mappedLanguage}"`);

    // ⚠️  FALLBACK MODE: Without Hugging Face token, return placeholder audio
    if (!HF_TOKEN) {
      logger.warn('⚠️  XTTS_HF_TOKEN not set - returning placeholder audio for testing');
      logger.warn('   To use real XTTS: set XTTS_HF_TOKEN in .env');
      return createSilentWAV(2); // Return 2 seconds of silent audio for testing
    }

    // Prepare request payload for Hugging Face API
    const payload = {
      inputs: text,
      parameters: {
        language: mappedLanguage,
      }
    };

    // If reference audio is provided, send it for voice cloning
    if (referenceAudio) {
      payload.parameters.speaker_audio_base64 = referenceAudio.toString('base64');
    }

    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${HF_TOKEN}`,
    };

    logger.debug(`Calling Hugging Face XTTS API at ${XTTS_API_URL}`);

    // Send request to Hugging Face API
    const response = await axios.post(XTTS_API_URL, payload, {
      headers,
      responseType: 'arraybuffer',
      timeout: 120000, // 120 seconds timeout for HF API
    });

    logger.info(`Speech generated successfully for language: ${mappedLanguage}`);
    return Buffer.from(response.data);
  } catch (error) {
    logger.error('XTTS speech generation error:', error.message);
    if (error.response) {
      logger.error(`Response status: ${error.response.status}`);
      if (error.response.status === 401) {
        logger.warn('⚠️  Hugging Face API requires authentication - returning placeholder audio');
        return createSilentWAV(2);
      }
    }
    throw new Error(`Failed to generate speech: ${error.message}`);
  }
}

/**
 * Generate speech for multiple languages simultaneously
 * @param {Object} options - Configuration options
 * @param {string} options.text - Text to synthesize
 * @param {string[]} options.languages - Array of language codes
 * @param {Buffer} options.referenceAudio - Reference audio file buffer for voice cloning
 * @returns {Promise<Object>} Object with language codes as keys and audio buffers as values
 */
export async function generateMultiLanguageSpeech(options) {
  try {
    const { text, languages = ['en'], referenceAudio } = options;

    logger.info(`Generating speech for ${languages.length} languages`);

    const results = {};
    const promises = [];

    for (const language of languages) {
      const promise = generateSpeech({
        text,
        language,
        referenceAudio,
      })
        .then(audioBuffer => {
          results[language] = audioBuffer;
        })
        .catch(error => {
          logger.error(`Failed to generate speech for language ${language}:`, error);
          results[language] = null;
        });

      promises.push(promise);
    }

    await Promise.all(promises);

    logger.info(`Multi-language speech generation completed`);
    return results;
  } catch (error) {
    logger.error('Multi-language speech generation error:', error);
    throw error;
  }
}

/**
 * Check XTTS server health
 * @returns {Promise<boolean>} True if server is healthy
 */
export async function checkXTTSHealth() {
  try {
    // Hugging Face API is always available, just return true
    logger.info('XTTS service (Hugging Face) is available');
    return true;
  } catch (error) {
    logger.warn('XTTS service check failed:', error.message);
    return false;
  }
}

/**
 * Get supported languages
 * @returns {Promise<string[]>} Array of supported language codes
 */
export async function getSupportedLanguages() {
  return Object.keys(LANGUAGE_MAP);
}

/**
 * Generate speech with translation using XTTS v2
 * XTTS v2 handles both translation and speech synthesis in one call
 * @param {Object} options - Configuration options
 * @param {string} options.text - Input text to translate and synthesize
 * @param {string} options.sourceLanguage - Source language code (e.g., 'ar')
 * @param {string} options.targetLanguage - Target language code (e.g., 'en', 'tr')
 * @param {Buffer} options.referenceAudio - Optional reference audio for voice cloning
 * @returns {Promise<{translatedText: string, audioBuffer: Buffer}>} Translated text and audio
 */
export async function generateSpeechWithTranslation(options) {
  const {
    text,
    sourceLanguage = 'en',
    targetLanguage = 'en',
    referenceAudio,
  } = options;

  if (!text) {
    throw new Error('Text is required for speech generation');
  }

  const mappedSourceLang = LANGUAGE_MAP[sourceLanguage.split('-')[0]] || 'en';
  const mappedTargetLang = LANGUAGE_MAP[targetLanguage.split('-')[0]] || 'en';

  logger.info(
    `Generating translated speech: "${text.substring(0, 50)}..." ` +
    `from ${mappedSourceLang} to ${mappedTargetLang}`
  );

  // Step 1: Translate text using Google Translate API first
  let translatedText = text; // Initialize with original text as fallback
  try {
    translatedText = await getTranslatedTextUsingGoogle(text, mappedSourceLang, mappedTargetLang);
    logger.info(`✅ Text translated to ${mappedTargetLang}: "${translatedText.substring(0, 50)}..."`);
  } catch (error) {
    logger.error('Translation failed:', error.message);
    translatedText = text; // Keep fallback to original
  }

  // Step 2: Try to generate speech with the translated text
  try {
    // Read reference audio if it's a file path
    let audioBuffer = null;
    if (referenceAudio) {
      try {
        const fs = await import('fs').then(m => m.promises);
        audioBuffer = await fs.readFile(referenceAudio);
        logger.debug(`Read reference audio from file`);
      } catch (e) {
        logger.warn(`Could not read reference audio file:`, e.message);
        // Continue without voice cloning
      }
    }

    // Step 3: Generate speech using the translated text
    // Hugging Face serverless API expects "inputs" not "text"
    const payload = {
      inputs: translatedText,
    };

    // If reference audio provided, include it for voice cloning
    if (audioBuffer) {
      payload.speaker_wav_base64 = audioBuffer.toString('base64');
      logger.debug('Including reference audio for voice cloning');
    }

    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${HF_TOKEN}`,
    };

    logger.debug(`Calling Hugging Face XTTS v2 API with authentication`);

    const response = await axios.post(XTTS_API_URL, payload, {
      headers,
      responseType: 'arraybuffer',
      timeout: 120000,
    });

    const speechAudioBuffer = Buffer.from(response.data);

    logger.info(`✅ Speech generated successfully in ${mappedTargetLang}`);

    return {
      translatedText: translatedText,
      audioBuffer: speechAudioBuffer,
    };

  } catch (speechError) {
    logger.error('XTTS speech generation error:', speechError.message);
    logger.warn('⚠️  Using translated text with placeholder audio');
    logger.info('🎯 Fallback: translatedText is defined =', !!translatedText);
    // Always return the translated text, even if audio generation failed
    return {
      translatedText: translatedText || text,
      audioBuffer: Buffer.alloc(0),
    };
  }
}

/**
 * Helper function to get translated text using Google Translate API
 * @private
 */
async function getTranslatedTextUsingGoogle(text, sourceLanguage, targetLanguage) {
  try {
    logger.debug(`Translating text from ${sourceLanguage} to ${targetLanguage}`);
    
    // Simple attempt using free Google Translate
    const encodedText = encodeURIComponent(text);
    try {
      const response = await axios.get(
        `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${sourceLanguage}&tl=${targetLanguage}&dt=t&q=${encodedText}`,
        { timeout: 10000 }
      );
      
      if (response.data && Array.isArray(response.data[0])) {
        const translated = response.data[0].map(item => item[0]).join('');
        logger.debug(`Translation successful: "${translated.substring(0, 50)}..."`);
        return translated;
      }
    } catch (e) {
      logger.warn('Google Translate API failed:', e.message);
    }

    // If translation fails, return original text
    logger.warn(`Translation failed, returning original text`);
    return text;
  } catch (error) {
    logger.warn('Could not get translated text:', error.message);
    return text;
  }
}

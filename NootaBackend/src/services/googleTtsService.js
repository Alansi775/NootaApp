import axios from 'axios';
import { initializeLogger } from '../config/logger.js';

const logger = initializeLogger();

const GOOGLE_TTS_URL = 'https://texttospeech.googleapis.com/v1/text:synthesize';

/**
 * Generate speech using Google Cloud Text-to-Speech (free tier: 4M chars/month)
 * @param {Object} options
 * @param {string} options.text - Text to synthesize
 * @param {string} options.language - Language code (en, ar, es, etc)
 * @returns {Promise<Buffer>} Audio buffer in MP3 format
 */
export async function generateSpeechGoogle(options) {
  const { text, language = 'en' } = options;

  // Get API key from environment
  const GOOGLE_API_KEY = process.env.GOOGLE_CLOUD_API_KEY;

  if (!text) {
    throw new Error('Text is required for speech generation');
  }

  if (!GOOGLE_API_KEY) {
    logger.warn(' GOOGLE_CLOUD_API_KEY not configured');
    logger.warn('Available env vars keys:', Object.keys(process.env).filter(k => k.includes('GOOGLE')));
    throw new Error('GOOGLE_CLOUD_API_KEY not set');
  }
  
  logger.info(` Google TTS API Key loaded: ${GOOGLE_API_KEY.substring(0, 10)}...`);

  try {
    const languageCodeMap = {
      'en': 'en-US',
      'ar': 'ar-SA',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-BR',
      'ja': 'ja-JP',
      'zh': 'zh-CN',
      'ko': 'ko-KR',
      'tr': 'tr-TR',
    };

    const languageCode = languageCodeMap[language.split('-')[0]] || 'en-US';

    logger.info(`🔊 Generating speech with Google TTS for ${language}: "${text.substring(0, 40)}..."`);

    const response = await axios.post(`${GOOGLE_TTS_URL}?key=${GOOGLE_API_KEY}`, {
      input: { text },
      voice: {
        languageCode,
        name: `${languageCode}-Neural2-A`,
      },
      audioConfig: {
        audioEncoding: 'MP3',
        pitch: 0,
        speakingRate: 1.0,
      },
    }, {
      timeout: 30000,
    });

    if (response.data.audioContent) {
      const audioBuffer = Buffer.from(response.data.audioContent, 'base64');
      logger.info(` Google TTS generated speech (${audioBuffer.length} bytes)`);
      return audioBuffer;
    }

    throw new Error('No audio content in response');

  } catch (error) {
    logger.error('Google TTS error:', error.message);
    logger.error('Error status:', error.response?.status);
    if (error.response?.data?.error) {
      logger.error('Error reason:', error.response.data.error.message);
      logger.warn('💡 To fix: Enable Google Cloud Text-to-Speech API in your GCP project');
    }
    throw error;
  }
}

import pkg from '@google-cloud/translate';
const { Translate } = pkg;
import { initializeLogger } from './logger.js';

const logger = initializeLogger();
let translateClient;

export function initializeTranslation() {
  try {
    const apiKey = process.env.GOOGLE_CLOUD_API_KEY;
    if (!apiKey) {
      throw new Error('GOOGLE_CLOUD_API_KEY not configured');
    }

    translateClient = new Translate({
      key: apiKey,
    });

    logger.info('Google Cloud Translation API initialized');
    return translateClient;
  } catch (error) {
    logger.error('Translation API initialization error:', error);
    throw error;
  }
}

export async function translateText(text, targetLanguage, sourceLanguage = 'en') {
  try {
    if (!translateClient) {
      initializeTranslation();
    }

    // Handle language code conversion (en-US -> en, ar-SA -> ar)
    const targetLang = targetLanguage.split('-')[0];
    const sourceLang = sourceLanguage.split('-')[0];

    if (targetLang === sourceLang) {
      return text; // No translation needed
    }

    const [translation] = await translateClient.translate(text, {
      to: targetLang,
      from: sourceLang,
    });

    logger.debug(`Translated text from ${sourceLang} to ${targetLang}`);
    return translation;
  } catch (error) {
    logger.error('Translation error:', error);
    throw new Error(`Failed to translate text: ${error.message}`);
  }
}

export function getTranslationClient() {
  return translateClient;
}

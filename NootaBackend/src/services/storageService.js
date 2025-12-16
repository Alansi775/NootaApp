import { getStorage } from '../config/firebase.js';
import { initializeLogger } from '../config/logger.js';
import { v4 as uuidv4 } from 'uuid';

const logger = initializeLogger();

/**
 * Upload audio file to Firebase Storage
 * @param {Buffer} audioBuffer - Audio file buffer
 * @param {Object} metadata - File metadata (messageId, roomId, language, etc.)
 * @returns {Promise<string>} Public download URL for the audio file
 */
export async function uploadAudio(audioBuffer, metadata = {}) {
  try {
    const storage = getStorage();
    const bucket = storage.bucket();

    // Generate file path: audio/messages/{roomId}/{messageId}/{language}.wav
    const {
      roomId = 'default',
      messageId = uuidv4(),
      language = 'en',
      timestamp = Date.now(),
    } = metadata;

    const fileName = `${language}.wav`;
    const filePath = `${process.env.STORAGE_BASE_PATH || 'audio/messages'}/${roomId}/${messageId}/${fileName}`;

    logger.debug(`Uploading audio file: ${filePath}`);

    const file = bucket.file(filePath);

    // Upload with metadata
    await file.save(audioBuffer, {
      metadata: {
        contentType: 'audio/wav',
        cacheControl: 'public, max-age=31536000', // Cache for 1 year
        custom_metadata: {
          messageId,
          roomId,
          language,
          uploadedAt: new Date(timestamp).toISOString(),
        },
      },
    });

    // Make file public (or use signed URLs for more control)
    await file.makePublic();

    // Get public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;

    logger.info(`Audio uploaded successfully: ${publicUrl}`);
    return publicUrl;
  } catch (error) {
    logger.error('Storage upload error:', error);
    throw new Error(`Failed to upload audio: ${error.message}`);
  }
}

/**
 * Upload multiple audio files for different languages
 * @param {Object} audioBuffers - Object with language codes as keys and audio buffers as values
 * @param {Object} metadata - File metadata
 * @returns {Promise<Object>} Object with language codes as keys and public URLs as values
 */
export async function uploadMultiLanguageAudio(audioBuffers, metadata = {}) {
  try {
    logger.info(`Uploading ${Object.keys(audioBuffers).length} audio files`);

    const results = {};
    const promises = [];

    for (const [language, audioBuffer] of Object.entries(audioBuffers)) {
      if (audioBuffer) {
        const promise = uploadAudio(audioBuffer, { ...metadata, language })
          .then(url => {
            results[language] = url;
            logger.debug(`Audio URL for ${language}: ${url}`);
          })
          .catch(error => {
            logger.error(`Failed to upload audio for language ${language}:`, error);
            results[language] = null;
          });

        promises.push(promise);
      }
    }

    await Promise.all(promises);

    logger.info(`Multi-language audio upload completed`);
    return results;
  } catch (error) {
    logger.error('Multi-language upload error:', error);
    throw error;
  }
}

/**
 * Delete audio file from Firebase Storage
 * @param {string} filePath - Path to the file in storage
 * @returns {Promise<void>}
 */
export async function deleteAudio(filePath) {
  try {
    const storage = getStorage();
    const bucket = storage.bucket();
    const file = bucket.file(filePath);

    await file.delete();
    logger.info(`Audio file deleted: ${filePath}`);
  } catch (error) {
    logger.error('Storage delete error:', error);
    throw new Error(`Failed to delete audio: ${error.message}`);
  }
}

/**
 * Generate signed URL for private audio files
 * @param {string} filePath - Path to the file in storage
 * @param {number} expirationMinutes - URL expiration time in minutes (default: 1 day)
 * @returns {Promise<string>} Signed URL
 */
export async function generateSignedUrl(filePath, expirationMinutes = 1440) {
  try {
    const storage = getStorage();
    const bucket = storage.bucket();
    const file = bucket.file(filePath);

    const [signedUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'read',
      expires: Date.now() + expirationMinutes * 60 * 1000,
    });

    return signedUrl;
  } catch (error) {
    logger.error('Signed URL generation error:', error);
    throw new Error(`Failed to generate signed URL: ${error.message}`);
  }
}

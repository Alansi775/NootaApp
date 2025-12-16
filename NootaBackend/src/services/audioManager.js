import { initializeLogger } from '../config/logger.js';
import axios from 'axios';
import fs from 'fs';
import path from 'path';
import os from 'os';
import dotenv from 'dotenv';

dotenv.config();
const logger = initializeLogger();
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:5001';

/**
 * Download user's original audio (from local disk or Firebase Storage)
 * This audio will be used as reference for XTTS v2 voice cloning
 * @param {string} audioUrl - http://localhost:5001/audio/voice/... or gs:// URL
 * @returns {Promise<Buffer>} Audio file buffer
 */
export async function downloadUserAudio(audioUrl) {
  try {
    if (!audioUrl) {
      throw new Error('Audio URL is required');
    }

    logger.info(`📥 Loading user audio from: ${audioUrl.substring(0, 60)}...`);

    // Check if it's a local Backend URL
    if (audioUrl.includes('/audio/voice/')) {
      // Extract filename from URL
      const fileName = audioUrl.split('/').pop();
      const filePath = path.join(path.dirname(new URL(import.meta.url).pathname), '../../uploads/voice', fileName);
      
      logger.info(`📂 Reading local voice file: ${filePath}`);
      const audioBuffer = fs.readFileSync(filePath);
      logger.info(`✅ Loaded user audio: ${audioBuffer.length} bytes`);
      return audioBuffer;
    }

    // If it's a gs:// URL, convert it to HTTPS download URL
    let downloadUrl = audioUrl;
    if (audioUrl.startsWith('gs://')) {
      downloadUrl = audioUrl
        .replace('gs://', 'https://firebasestorage.googleapis.com/v0/b/')
        .replace(/\//g, (match, offset) => {
          // Replace the first / after bucket name with /o/
          return offset === audioUrl.indexOf('/') + 5 ? '/o/' : match;
        }) + '?alt=media';
    }

    // Download the file from Firebase Storage
    const response = await axios.get(downloadUrl, {
      responseType: 'arraybuffer',
      timeout: 30000,
    });

    const audioBuffer = Buffer.from(response.data);
    logger.info(`✅ Downloaded user audio: ${audioBuffer.length} bytes`);

    return audioBuffer;
  } catch (error) {
    logger.error('❌ Error loading user audio:', error.message);
    throw new Error(`Failed to load audio: ${error.message}`);
  }
}

/**
 * Save audio buffer to temporary file
 * XTTS v2 requires file path, not buffer
 * @param {Buffer} audioBuffer
 * @returns {string} Path to temporary file
 */
export function saveAudioToTemp(audioBuffer) {
  try {
    const tempDir = os.tmpdir();
    const tempFile = path.join(tempDir, `speaker_${Date.now()}.wav`);
    
    fs.writeFileSync(tempFile, audioBuffer);
    logger.debug(`💾 Audio saved to temp file: ${tempFile}`);
    
    return tempFile;
  } catch (error) {
    logger.error('Error saving audio to temp:', error.message);
    throw error;
  }
}

/**
 * Clean up temporary audio file
 * @param {string} filePath
 */
export function cleanupTempFile(filePath) {
  try {
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      logger.debug(`🗑️ Cleaned up temp file: ${filePath}`);
    }
  } catch (error) {
    logger.warn('Warning: Could not clean up temp file:', error.message);
  }
}

/**
 * Upload generated audio chunk to local backend storage
 * @param {Buffer} audioBuffer - Generated audio
 * @param {Object} metadata - {messageId, languageCode, chunkIndex, totalChunks, roomId}
 * @returns {Promise<string>} Local URL (http://localhost:5001/audio/chunks/...)
 */
export async function uploadAudioChunk(audioBuffer, metadata) {
  try {
    const { messageId, languageCode, chunkIndex, totalChunks, roomId } = metadata;

    // Create filename
    const chunkFileName = `${languageCode}_${messageId}_chunk${chunkIndex}.wav`;
    
    // Get the uploads directory path
    // Navigate from src/services/audioManager.js to /uploads
    const uploadsDir = path.join(path.dirname(new URL(import.meta.url).pathname), '../../uploads/audio/chunks');
    const chunkPath = path.join(uploadsDir, chunkFileName);

    // Create directory if it doesn't exist
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }

    logger.info(`📤 Saving audio chunk: ${chunkFileName} (${chunkIndex}/${totalChunks})`);

    // Save the audio chunk to disk
    fs.writeFileSync(chunkPath, audioBuffer);

    // Generate local URL
    const localUrl = `${BACKEND_URL}/audio/chunks/${chunkFileName}`;
    logger.info(`✅ Chunk saved: ${localUrl}`);

    return localUrl;
  } catch (error) {
    logger.error('❌ Error saving audio chunk:', error.message);
    throw error;
  }
}

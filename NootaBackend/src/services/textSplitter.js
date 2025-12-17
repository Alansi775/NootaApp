import { initializeLogger } from '../config/logger.js';

const logger = initializeLogger();

/**
 * Split text into manageable chunks for XTTS v2
 * XTTS works better with shorter texts (recommended: 50-500 chars per chunk)
 * @param {string} text - Original text to split
 * @param {number} maxCharsPerChunk - Max characters per chunk (default: 300)
 * @returns {Array<string>} Array of text chunks
 */
export function splitTextIntoChunks(text, maxCharsPerChunk = 300) {
  try {
    if (!text || text.trim().length === 0) {
      throw new Error('Text cannot be empty');
    }

    const chunks = [];
    let currentChunk = '';

    // Split by sentences first
    const sentences = splitBySentences(text);
    
    logger.debug(` Text split into ${sentences.length} sentences`);

    for (const sentence of sentences) {
      const trimmedSentence = sentence.trim();
      
      // If adding this sentence exceeds max length, save current chunk first
      if (currentChunk.length + trimmedSentence.length > maxCharsPerChunk && currentChunk.length > 0) {
        chunks.push(currentChunk.trim());
        currentChunk = '';
      }

      currentChunk += (currentChunk.length > 0 ? ' ' : '') + trimmedSentence;
    }

    // Add any remaining text
    if (currentChunk.trim().length > 0) {
      chunks.push(currentChunk.trim());
    }

    logger.info(`✂️ Split text into ${chunks.length} chunks (max ${maxCharsPerChunk} chars/chunk)`);
    
    // Log chunk info for debugging
    chunks.forEach((chunk, idx) => {
      logger.debug(`   Chunk ${idx + 1}: ${chunk.substring(0, 50)}... (${chunk.length} chars)`);
    });

    return chunks;
  } catch (error) {
    logger.error('Error splitting text:', error.message);
    throw error;
  }
}

/**
 * Split text by sentence boundaries
 * Handles English, Arabic, Spanish, Turkish, etc.
 * @param {string} text
 * @returns {Array<string>}
 */
function splitBySentences(text) {
  // Regex to split by common sentence endings
  // Supports: . ! ? ، ؟ and their variations
  const sentencePattern = /[.!?؟،\n]+/g;
  
  const parts = text.split(sentencePattern);
  const sentences = [];

  for (let i = 0; i < parts.length; i++) {
    const part = parts[i].trim();
    if (part.length > 0) {
      sentences.push(part);
    }
  }

  return sentences.length > 0 ? sentences : [text];
}

/**
 * Validate chunks before sending to XTTS
 * @param {Array<string>} chunks
 * @returns {boolean}
 */
export function validateChunks(chunks) {
  try {
    if (!Array.isArray(chunks) || chunks.length === 0) {
      throw new Error('Chunks must be a non-empty array');
    }

    for (let i = 0; i < chunks.length; i++) {
      if (!chunks[i] || chunks[i].trim().length === 0) {
        throw new Error(`Chunk ${i} is empty`);
      }
      if (chunks[i].length > 1000) {
        logger.warn(` Chunk ${i} is very long (${chunks[i].length} chars), XTTS may truncate it`);
      }
    }

    logger.debug(` All ${chunks.length} chunks validated successfully`);
    return true;
  } catch (error) {
    logger.error('Chunk validation error:', error.message);
    throw error;
  }
}

/**
 * Get chunk metadata
 * @param {Array<string>} chunks
 * @returns {Object}
 */
export function getChunkMetadata(chunks) {
  return {
    totalChunks: chunks.length,
    totalLength: chunks.reduce((sum, chunk) => sum + chunk.length, 0),
    averageChunkLength: Math.round(chunks.reduce((sum, chunk) => sum + chunk.length, 0) / chunks.length),
  };
}

import { getFirestore } from '../config/firebase.js';
import { initializeLogger } from '../config/logger.js';
import { generateSpeechWithTranslation } from './xttsService.js';
import { downloadUserAudio, saveAudioToTemp, cleanupTempFile, uploadAudioChunk } from './audioManager.js';
import { splitTextIntoChunks, validateChunks, getChunkMetadata } from './textSplitter.js';

const logger = initializeLogger();

/**
 * Process a message with streaming chunk generation
 * Splits text into chunks, generates audio for each chunk in real-time,
 * and uploads them to Firebase as they're generated
 */
export async function processMessage(params) {
  const { messageId, roomId, message, docRef } = params;
  const db = getFirestore();
  let speakerAudioPath = null;

  try {
    // Mark message as processing
    await docRef.update({
      processingStatus: 'processing',
      processingStartedAt: new Date(),
      totalChunks: 0,
      processedChunks: 0,
    });

    logger.info(`✅ Started processing message ${messageId} in room ${roomId}`);

    // Extract message data
    const originalText = message.originalText || message.text;
    const senderUID = message.senderUID || message.senderId;
    const sourceLanguage = message.originalLanguageCode || 'en';
    const originalAudioUrl = message.originalAudioUrl; // URL to user's voice recording

    if (!originalText) {
      throw new Error('Message text is empty');
    }

    logger.info(
      `📝 Message: "${originalText.substring(0, 50)}..." | ` +
      `Sender: ${senderUID} | Language: ${sourceLanguage}`
    );

    // Get room info
    const roomDoc = await db.collection('rooms').doc(roomId).get();
    const roomData = roomDoc.data() || {};
    const participantLanguages = roomData.participantLanguages || {};
    
    // Determine target languages
    const targetLanguages = Object.entries(participantLanguages)
      .filter(([uid]) => uid !== senderUID)
      .map(([_, lang]) => lang);

    if (targetLanguages.length === 0) {
      logger.warn(`⚠️ No target languages found, defaulting to English`);
      targetLanguages.push('en');
    }

    logger.info(`🗣️ Target languages: ${targetLanguages.join(', ')}`);

    // Step 1: Download user's original audio for voice cloning
    let userAudioPath = null;
    if (originalAudioUrl) {
      try {
        logger.info(`📥 Downloading user's original audio for voice cloning...`);
        const audioBuffer = await downloadUserAudio(originalAudioUrl);
        userAudioPath = saveAudioToTemp(audioBuffer);
        logger.info(`✅ User audio ready: ${userAudioPath}`);
      } catch (error) {
        logger.warn(`⚠️ Could not download user audio:`, error.message);
        // Continue without user audio (will use default TTS voice)
      }
    }

    // Step 2: Split text into chunks
    const chunks = splitTextIntoChunks(originalText, 300);
    validateChunks(chunks);
    
    const chunkMetadata = getChunkMetadata(chunks);
    logger.info(`📊 Split into ${chunks.length} chunks: ${chunkMetadata.totalLength} total chars, avg ${chunkMetadata.averageChunkLength} chars/chunk`);

    // Update Firestore with chunk count
    await docRef.update({
      totalChunks: chunks.length,
    });

    // Step 3: Initialize data structures for chunks
    const translations = {
      [sourceLanguage]: chunks, // Store original chunks
    };

    const audioUrls = {};
    let processedChunkCount = 0;

    // Step 4: Generate audio for each chunk in each target language
    for (const targetLang of targetLanguages) {
      try {
        logger.info(`\n🔄 Starting generation for language: ${targetLang}`);
        
        const langTranslations = [];
        const langAudioUrls = [];
        processedChunkCount = 0;

        // Process each chunk
        for (let chunkIdx = 0; chunkIdx < chunks.length; chunkIdx++) {
          const chunk = chunks[chunkIdx];
          
          try {
            logger.info(
              `   Chunk ${chunkIdx + 1}/${chunks.length}: ` +
              `"${chunk.substring(0, 40)}..." → ${targetLang}`
            );

            // Generate speech with translation for this chunk
            logger.info(`🔄 Calling generateSpeechWithTranslation for chunk ${chunkIdx + 1}...`);
            let result;
            try {
              result = await generateSpeechWithTranslation({
                text: chunk,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLang,
                referenceAudio: userAudioPath, // Pass user's audio for voice cloning
              });
              logger.info(`✅ generateSpeechWithTranslation returned successfully with translatedText: "${result.translatedText}"`);
            } catch (innerError) {
              logger.error(`❌ generateSpeechWithTranslation threw an error:`, innerError.message);
              // DON'T re-throw - xttsService handles errors gracefully and returns translated text
              result = {
                translatedText: chunk, // Fallback to original text
                audioBuffer: Buffer.alloc(0),
              };
              logger.warn(`⚠️  Using fallback with original text`);
            }

            // Store translated text (always save it, even if audio generation failed)
            logger.info(`📥 About to push translatedText to array: "${result.translatedText}"`);
            langTranslations.push(result.translatedText);
            logger.info(`✅ Successfully pushed translation. Array now has ${langTranslations.length} items`);

            // Upload audio chunk immediately
            const audioUrl = await uploadAudioChunk(result.audioBuffer, {
              messageId,
              roomId,
              languageCode: targetLang,
              chunkIndex: chunkIdx,
              totalChunks: chunks.length,
            });

            langAudioUrls.push(audioUrl);
            processedChunkCount++;

            // Update Firestore with new chunk (streaming update)
            await docRef.update({
              [`translations.${targetLang}`]: langTranslations,
              [`audioUrls.${targetLang}`]: langAudioUrls,
              processedChunks: processedChunkCount,
              lastUpdated: new Date(),
            });

            logger.info(`   ✅ Chunk ${chunkIdx + 1} uploaded and Firestore updated`);

          } catch (chunkError) {
            logger.error(`   ❌ Error processing chunk ${chunkIdx + 1}:`, chunkError.message);
            logger.error(`   Current langTranslations array:`, JSON.stringify(langTranslations));
            // Continue with next chunk despite error
            langTranslations.push(chunk); // Store original as fallback
            logger.error(`   After fallback, langTranslations array:`, JSON.stringify(langTranslations));
            langAudioUrls.push(null); // Mark as failed
          }
        }

        translations[targetLang] = langTranslations;
        audioUrls[targetLang] = langAudioUrls;

        logger.info(`✅ Completed language ${targetLang}: ${processedChunkCount}/${chunks.length} chunks`);
        logger.info(`🔥 About to save translations[${targetLang}]:`, JSON.stringify(langTranslations));

      } catch (error) {
        logger.error(`❌ Error processing language ${targetLang}:`, error.message);
        // Continue with other languages
      }
    }

    // Step 5: Save final translations and audioUrls, then mark as completed
    await docRef.update({
      translations: translations,
      audioUrls: audioUrls,
      processingStatus: 'completed',
      processingEndedAt: new Date(),
    });

    logger.info(`🎉 Successfully completed processing message ${messageId}`);

    return { success: true, messageId, chunksProcessed: processedChunkCount };

  } catch (error) {
    logger.error(`❌ Failed to process message ${messageId}:`, error.message);
    try {
      await docRef.update({
        processingStatus: 'failed',
        processingError: error.message,
        processingEndedAt: new Date(),
      });
    } catch (updateError) {
      logger.error(`Failed to update error status:`, updateError.message);
    }
    throw error;

  } finally {
    // Cleanup temporary files
    if (speakerAudioPath) {
      cleanupTempFile(speakerAudioPath);
    }
  }
}

/**
 * Reprocess failed message
 */
export async function reprocessFailedMessage(roomId, messageId) {
  try {
    const db = getFirestore();
    const docRef = db.collection('rooms').doc(roomId).collection('messages').doc(messageId);
    
    const messageDoc = await docRef.get();
    if (!messageDoc.exists) {
      throw new Error(`Message ${messageId} not found`);
    }

    const message = messageDoc.data();
    
    logger.info(`Reprocessing failed message ${messageId}`);

    await processMessage({
      messageId,
      roomId,
      message,
      docRef,
    });

    return { success: true, messageId };
  } catch (error) {
    logger.error(`Failed to reprocess message ${messageId}:`, error);
    throw error;
  }
}

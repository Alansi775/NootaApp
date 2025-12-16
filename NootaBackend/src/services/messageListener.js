import { getFirestore } from '../config/firebase.js';
import { initializeLogger } from '../config/logger.js';
import { processMessage } from './messageProcessor.js';

const logger = initializeLogger();
const activeListeners = new Map();

/**
 * Start listening to all rooms and their messages
 */
export function startMessageListener() {
  try {
    const db = getFirestore();
    let roomListenerInitialized = false;

    // First, listen to all rooms
    const roomsQuery = db.collection('rooms');

    logger.info('📡 Setting up Firestore listeners...');

    const roomsUnsubscribe = roomsQuery.onSnapshot(
      async (roomsSnapshot) => {
        logger.info(`🔔 ROOMS LISTENER TRIGGERED - ${new Date().toISOString()}`);
        if (!roomListenerInitialized) {
          roomListenerInitialized = true;
          logger.info(`✅ Room listener initialized with ${roomsSnapshot.docs.length} rooms`);
        }

        logger.debug(`📊 Rooms snapshot: ${roomsSnapshot.docs.length} rooms`);

        for (const roomDoc of roomsSnapshot.docs) {
          const roomId = roomDoc.id;
          logger.debug(`🏠 Found room: ${roomId}`);

          // Skip if we're already listening to this room
          if (activeListeners.has(`room-${roomId}`)) {
            logger.debug(`⏭️ Already listening to room ${roomId}`);
            continue;
          }

          logger.info(`🔗 Attaching message listener to room: ${roomId}`);

          // Now listen to messages in this specific room
          const messagesQuery = db
            .collection('rooms')
            .doc(roomId)
            .collection('messages');

          const messagesUnsubscribe = messagesQuery.onSnapshot(
            async (messagesSnapshot) => {
              logger.info(`🔔 MESSAGES LISTENER TRIGGERED for room ${roomId} - ${new Date().toISOString()}`);
              logger.debug(
                `💬 Room ${roomId}: ${messagesSnapshot.docs.length} messages total`
              );

              // Count by type for debugging
              let addedCount = 0;
              let modifiedCount = 0;

              for (const docChange of messagesSnapshot.docChanges()) {
                if (docChange.type === 'added') {
                  addedCount++;
                  const message = docChange.doc.data();
                  const messageId = docChange.doc.id;

                  // Skip if already processed
                  if (
                    message.processingStatus === 'processing' ||
                    message.processingStatus === 'completed' ||
                    message.processingStatus === 'failed'
                  ) {
                    logger.debug(
                      `⏭️ Skipping message ${messageId} (status: ${message.processingStatus})`
                    );
                    continue;
                  }

                  // Check for required fields
                  const hasText = message.originalText || message.text;
                  const hasSender = message.senderUID || message.senderId;

                  if (!hasText || !hasSender) {
                    logger.warn(
                      `⚠️ Skipping message ${messageId}: missing text or sender`,
                      {
                        hasOriginalText: !!message.originalText,
                        hasText: !!message.text,
                        hasSenderUID: !!message.senderUID,
                        hasSenderId: !!message.senderId,
                      }
                    );
                    continue;
                  }

                  logger.info(
                    `� NEW MESSAGE DETECTED: ${messageId} in room ${roomId}`
                  );
                  logger.info(`   📝 Text: "${hasText.substring(0, 50)}..."`);
                  logger.info(`   👤 Sender: ${hasSender}`);
                  logger.info(`   ⏱️ Status: ${message.processingStatus || 'undefined'}`);

                  // Process message asynchronously
                  processMessage({
                    messageId,
                    roomId,
                    message,
                    docRef: docChange.doc.ref,
                  }).catch((error) => {
                    logger.error(
                      `❌ Error processing message ${messageId}:`,
                      error.message
                    );
                  });
                } else if (docChange.type === 'modified') {
                  modifiedCount++;
                  logger.debug(`📝 Message modified: ${docChange.doc.id}`);
                }
              }

              if (addedCount > 0 || modifiedCount > 0) {
                logger.debug(
                  `📊 Snapshot summary - Added: ${addedCount}, Modified: ${modifiedCount}`
                );
              }
            },
            (error) => {
              logger.error(
                `❌ Messages listener error for room ${roomId}:`,
                error.message
              );
            }
          );

          activeListeners.set(`room-${roomId}`, messagesUnsubscribe);
          logger.info(`✅ Message listener attached to room: ${roomId}`);
        }
      },
      (error) => {
        logger.error('❌ Rooms listener error:', error.message, error.code);
        console.error('FULL ERROR DETAILS:', error);
      }
    );

    activeListeners.set('rooms-main', roomsUnsubscribe);
    logger.info('✅ Message listener framework started successfully');

    return roomsUnsubscribe;
  } catch (error) {
    logger.error('❌ Failed to start message listener:', error.message);
    throw error;
  }
}

/**
 * Stop all active message listeners
 */
export function stopMessageListeners() {
  try {
    for (const [name, unsubscribe] of activeListeners) {
      unsubscribe();
      logger.info(`Stopped listener: ${name}`);
    }
    activeListeners.clear();
  } catch (error) {
    logger.error('Error stopping listeners:', error);
  }
}

/**
 * Get listener status
 */
export function getListenerStatus() {
  return {
    isActive: activeListeners.size > 0,
    listeners: Array.from(activeListeners.keys()),
  };
}

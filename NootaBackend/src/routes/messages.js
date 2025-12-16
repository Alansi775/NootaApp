import express from 'express';
import { getLogger } from '../config/logger.js';
import { reprocessFailedMessage } from '../services/messageProcessor.js';
import { getFirestore } from '../config/firebase.js';

const router = express.Router();
const logger = getLogger();

/**
 * GET /api/messages/status/:roomId/:messageId
 * Get the processing status of a message
 */
router.get('/status/:roomId/:messageId', async (req, res) => {
  try {
    const { roomId, messageId } = req.params;
    const db = getFirestore();

    const messageDoc = await db
      .collection('rooms')
      .doc(roomId)
      .collection('messages')
      .doc(messageId)
      .get();

    if (!messageDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'Message not found',
      });
    }

    const message = messageDoc.data();
    res.json({
      success: true,
      messageId,
      roomId,
      processingStatus: message.processingStatus,
      translations: message.translations || {},
      audioUrls: message.audioUrls || {},
      processingError: message.processingError || null,
    });
  } catch (error) {
    logger.error('Error getting message status:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * POST /api/messages/reprocess/:roomId/:messageId
 * Reprocess a failed message
 */
router.post('/reprocess/:roomId/:messageId', async (req, res) => {
  try {
    const { roomId, messageId } = req.params;

    logger.info(`Reprocessing message ${messageId} from room ${roomId}`);

    const result = await reprocessFailedMessage(roomId, messageId);

    res.json({
      success: true,
      message: 'Message reprocessing started',
      result,
    });
  } catch (error) {
    logger.error('Error reprocessing message:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * GET /api/messages/room/:roomId
 * Get all messages in a room with their processing status
 */
router.get('/room/:roomId', async (req, res) => {
  try {
    const { roomId } = req.params;
    const db = getFirestore();

    const messagesSnapshot = await db
      .collection('rooms')
      .doc(roomId)
      .collection('messages')
      .orderBy('timestamp', 'desc')
      .limit(50)
      .get();

    const messages = [];
    messagesSnapshot.forEach(doc => {
      const message = doc.data();
      messages.push({
        id: doc.id,
        text: message.text,
        processingStatus: message.processingStatus,
        audioUrls: message.audioUrls || {},
        translations: message.translations || {},
        timestamp: message.timestamp,
        senderName: message.senderName,
      });
    });

    res.json({
      success: true,
      roomId,
      messageCount: messages.length,
      messages,
    });
  } catch (error) {
    logger.error('Error getting room messages:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

export default router;

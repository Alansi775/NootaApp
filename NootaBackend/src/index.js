import express from 'express';
import cors from 'cors';
import bodyParser from 'body-parser';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import { initializeFirebase, getFirestore } from './config/firebase.js';
import { initializeLogger } from './config/logger.js';
import messageRoutes from './routes/messages.js';
import healthRoutes from './routes/health.js';
import { startMessageListener } from './services/messageListener.js';

dotenv.config();

const app = express();
const logger = initializeLogger();

// Get __dirname for ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Backend URL from env
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:5001';

// Create directories for uploads
const uploadsDir = path.join(__dirname, '../uploads');
const voiceDir = path.join(uploadsDir, 'voice');
const chunksDir = path.join(uploadsDir, 'audio', 'chunks');

[uploadsDir, voiceDir, chunksDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    logger.info(`📁 Created directory: ${dir}`);
  }
});

// Configure multer for voice uploads
const voiceStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, voiceDir);
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    const uid = req.body.senderUID || 'unknown';
    cb(null, `voice_${uid}_${timestamp}.wav`);
  }
});

const voiceUpload = multer({
  storage: voiceStorage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB max
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('audio/')) {
      cb(null, true);
    } else {
      cb(new Error('Only audio files are allowed'));
    }
  }
});

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));

// Serve uploaded files statically
app.use('/audio/voice', express.static(voiceDir));
app.use('/audio/chunks', express.static(chunksDir));

// Initialize Firebase
try {
  initializeFirebase();
  logger.info('Firebase initialized successfully');
} catch (error) {
  logger.error('Failed to initialize Firebase:', error);
  process.exit(1);
}

// Routes
app.use('/api/health', healthRoutes);
app.use('/api/messages', messageRoutes);

// 🎙️ API لإنشاء رسالة مع تحميل الملف الصوتي
app.post('/api/messages/create', voiceUpload.single('audioFile'), async (req, res) => {
  try {
    const { roomID, senderUID, originalText, originalLanguageCode, targetLanguageCode } = req.body;
    const audioFile = req.file;

    logger.info(`📨 Received message from ${senderUID}`);
    logger.info(`   Text: ${originalText.substring(0, 50)}...`);

    if (!roomID || !senderUID || !originalText) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: roomID, senderUID, originalText'
      });
    }

    const db = getFirestore();

    // Create message object
    const messageData = {
      senderUID,
      originalText,
      originalLanguageCode: originalLanguageCode || 'ar-SA',
      targetLanguageCode: targetLanguageCode || 'en-US',
      senderPreferredVoiceGender: 'default', // Default voice preference
      processingStatus: 'pending',
      timestamp: new Date(),
      audioUrls: {},
      translations: {},
      totalChunks: 0,
      processedChunks: 0
    };

    // Add audio URL if file was uploaded
    if (audioFile) {
      messageData.originalAudioUrl = `${BACKEND_URL}/audio/voice/${audioFile.filename}`;
      logger.info(`🎙️ Voice file uploaded: ${audioFile.filename} (${audioFile.size} bytes)`);
    } else {
      logger.warn('⚠️  No audio file provided');
    }

    // Save message to Firestore
    const messageRef = await db
      .collection('rooms')
      .doc(roomID)
      .collection('messages')
      .add(messageData);

    const messageID = messageRef.id;
    logger.info(`✅ Message saved to Firestore: ${messageID}`);

    // Return success response
    res.json({
      success: true,
      messageID,
      message: 'Message received and saved for processing'
    });

  } catch (error) {
    logger.error('Error creating message:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Check Firestore connection (optional debug)
setTimeout(async () => {
  try {
    const db = getFirestore();
    logger.info('✅ Firestore instance created successfully');
  } catch (error) {
    logger.warn('⚠️ Firestore check failed:', error.message);
  }
}, 200);

// Start message listener after a short delay to ensure Firestore is ready
setTimeout(() => {
  try {
    logger.info('⏳ Starting message listener (500ms delay to ensure Firestore is ready)...');
    startMessageListener();
    logger.info('Message listener started');
  } catch (error) {
    logger.error('Failed to start message listener:', error);
  }
}, 500);

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(err.status || 500).json({
    success: false,
    error: err.message || 'Internal server error'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found'
  });
});

// Start server
const PORT = process.env.PORT || 5001;
app.listen(PORT, '0.0.0.0', () => {
  logger.info(`🚀 Noota Backend Server running on port ${PORT}`);
  logger.info(`📡 Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`🔗 XTTS Server: ${process.env.XTTS_SERVER_URL || 'Not configured'}`);
  logger.info(`📁 Uploads directory: ${uploadsDir}`);
});

export default app;

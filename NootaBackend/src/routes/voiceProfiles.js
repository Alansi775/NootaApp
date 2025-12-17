// NootaBackend/src/routes/voiceProfiles.js
import express from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { getFirestore } from '../config/firebase.js';

const router = express.Router();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configure upload directory
const voiceProfileDir = path.join(__dirname, '../../uploads/audio_references');

if (!fs.existsSync(voiceProfileDir)) {
  fs.mkdirSync(voiceProfileDir, { recursive: true });
}

// Configure multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, voiceProfileDir);
  },
  filename: (req, file, cb) => {
    const userId = req.body.userId;
    //  Only ONE file per user - no language suffix
    cb(null, `${userId}.wav`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB max
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('audio/')) {
      cb(null, true);
    } else {
      cb(new Error('Only audio files are allowed'));
    }
  }
});

// POST /api/voice-profiles/upload
router.post('/upload', (req, res, next) => {
  upload.single('audio')(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      console.error(' Multer Error:', err.message);
      return res.status(400).json({ success: false, error: `Upload error: ${err.message}` });
    } else if (err) {
      console.error(' Unknown Error:', err.message);
      return res.status(400).json({ success: false, error: err.message });
    }
    next();
  });
}, async (req, res) => {
  try {
    console.log('\n🎙️ ===== VOICE PROFILE UPLOAD REQUEST =====');
    console.log(` Body fields:`, req.body);
    console.log(`📁 File info:`, req.file ? {
      fieldname: req.file.fieldname,
      originalname: req.file.originalname,
      encoding: req.file.encoding,
      mimetype: req.file.mimetype,
      size: req.file.size,
      destination: req.file.destination,
      filename: req.file.filename,
      path: req.file.path
    } : 'NO FILE');
    
    const { userId, language } = req.body;
    
    console.log(`👤 UserID: ${userId}`);
    console.log(`🗣️ Language: ${language}`);
    
    if (!userId || !req.file) {
      console.log(` Missing: userId=${!!userId}, file=${!!req.file}`);
      return res.status(400).json({
        success: false,
        error: 'Missing userId or audio file'
      });
    }
    
    const audioPath = `/audio_references/${req.file.filename}`;
    const newFilePath = req.file.path;
    
    console.log(` Multer saved file to: ${newFilePath}`);
    console.log(`📍 Audio path for Firestore: ${audioPath}`);
    
    // FIRST: Verify NEW file exists
    const newFileExists = fs.existsSync(newFilePath);
    console.log(` NEW file exists: ${newFileExists}`);
    if (!newFileExists) {
      console.error(` ERROR: New file was not saved by multer!`);
      return res.status(500).json({
        success: false,
        error: 'File upload failed - file not saved'
      });
    }
    
    const newStats = fs.statSync(newFilePath);
    console.log(`📊 NEW file size: ${newStats.size} bytes`);
    
    // THEN: DELETE old voice file (ONLY if new one exists and is valid)
    const oldFilePath = path.join(voiceProfileDir, `${userId}.wav`);
    if (fs.existsSync(oldFilePath) && newFilePath !== oldFilePath) {
      try {
        fs.unlinkSync(oldFilePath);
        console.log(`🗑️ Deleted old voice file: ${userId}.wav`);
      } catch (err) {
        console.error(`Failed to delete old file:`, err);
      }
    }
    
    // VERIFY again after delete
    const finalFileExists = fs.existsSync(newFilePath);
    console.log(` FINAL verification - file exists: ${finalFileExists}`);
    
    // Store reference in Firestore
    const db = getFirestore();
    const userRef = db.collection('users').doc(userId);
    
    await userRef.set({
      voiceProfilePath: audioPath,
      voiceProfileLanguage: language || 'en',
      voiceProfileUploadedAt: new Date(),
      hasVoiceProfile: true
    }, { merge: true });
    
    console.log(` Voice profile saved for user ${userId}`);
    console.log(`🎙️ ===== UPLOAD COMPLETE =====\n`);
    
    res.json({
      success: true,
      userID: userId,
      audioPath: audioPath,
      message: 'Voice profile uploaded successfully'
    });
  } catch (error) {
    console.error(' Error uploading voice profile:', error.message);
    console.error('Stack:', error.stack);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// GET /api/voice-profiles/:userId
router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const db = getFirestore();
    
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists || !userDoc.data().voiceProfilePath) {
      return res.status(404).json({
        success: false,
        error: 'Voice profile not found'
      });
    }
    
    const voiceProfile = userDoc.data();
    
    res.json({
      success: true,
      audioPath: voiceProfile.voiceProfilePath,
      language: voiceProfile.voiceProfileLanguage || 'en',
      uploadedAt: voiceProfile.voiceProfileUploadedAt
    });
  } catch (error) {
    console.error('Error retrieving voice profile:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// DELETE /api/voice-profiles/:userId
router.delete('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const db = getFirestore();
    
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (userDoc.exists && userDoc.data().voiceProfilePath) {
      const filePath = path.join(voiceProfileDir, path.basename(userDoc.data().voiceProfilePath));
      
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }
    
    await db.collection('users').doc(userId).set({
      voiceProfilePath: null,
      voiceProfileLanguage: null,
      hasVoiceProfile: false
    }, { merge: true });
    
    res.json({
      success: true,
      message: 'Voice profile deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting voice profile:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

export default router;

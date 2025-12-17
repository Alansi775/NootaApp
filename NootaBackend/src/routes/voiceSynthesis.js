import express from 'express';
import fs from 'fs';
import path from 'path';
import { initializeLogger } from '../config/logger.js';
import { generateSpeechWithTranslation } from '../services/xttsService.js';

const router = express.Router();
const logger = initializeLogger();

/**
 * POST /api/voice-synthesis/test
 * Test endpoint to generate speech with voice reference
 * 
 * Request body:
 * {
 *   "text": "Hello world",
 *   "sourceLanguage": "en",
 *   "targetLanguage": "ar",
 *   "voiceProfileUserId": "EsAY5lPWvjhsqVQNMonWo7Je7vn2",
 *   "voiceProfileLanguage": "en"
 * }
 */
router.post('/test', async (req, res) => {
  try {
    const { text, sourceLanguage = 'en', targetLanguage = 'ar', voiceProfileUserId, voiceProfileLanguage } = req.body;

    if (!text) {
      return res.status(400).json({ error: 'Text is required' });
    }

    logger.info(`🎤 Voice Synthesis Test Request:`);
    logger.info(`   Text: "${text}"`);
    logger.info(`   Source: ${sourceLanguage} → Target: ${targetLanguage}`);
    logger.info(`   Voice Profile: ${voiceProfileUserId} (${voiceProfileLanguage})`);

    // Try to find the voice profile
    let voiceProfilePath = null;
    if (voiceProfileUserId) {
      const uploadsDir = path.join(path.dirname(new URL(import.meta.url).pathname), '../../uploads/audio_references');
      const possibleNames = [
        `${voiceProfileUserId}_${voiceProfileLanguage}.wav`,
        `${voiceProfileUserId}_${targetLanguage}.wav`,
        `${voiceProfileUserId}.wav`,
      ];

      for (const fileName of possibleNames) {
        const filePath = path.join(uploadsDir, fileName);
        if (fs.existsSync(filePath)) {
          voiceProfilePath = filePath;
          logger.info(` Found voice profile: ${fileName}`);
          break;
        }
      }

      if (!voiceProfilePath) {
        logger.warn(` Voice profile not found. Available files:`);
        const files = fs.readdirSync(uploadsDir).filter(f => f.endsWith('.wav'));
        logger.warn(`   ${files.join(', ')}`);
        logger.warn(` Proceeding without voice reference`);
      }
    }

    // Generate speech
    logger.info(` Calling generateSpeechWithTranslation...`);
    const result = await generateSpeechWithTranslation({
      text,
      sourceLanguage,
      targetLanguage,
      referenceAudio: voiceProfilePath, // Pass the voice profile path
    });

    logger.info(` Speech generation successful`);
    logger.info(`   Translated Text: "${result.translatedText}"`);
    logger.info(`   Audio Size: ${result.audioBuffer.length} bytes`);

    // Return audio as response
    res.set({
      'Content-Type': 'audio/wav',
      'Content-Disposition': `attachment; filename="synthesis_${targetLanguage}.wav"`,
      'Content-Length': result.audioBuffer.length,
    });

    res.send(result.audioBuffer);

  } catch (error) {
    logger.error('Voice synthesis error:', error.message);
    logger.error(error.stack);
    res.status(500).json({
      error: 'Voice synthesis failed',
      message: error.message,
    });
  }
});

/**
 * GET /api/voice-synthesis/health
 * Check if voice synthesis service is available
 */
router.get('/health', async (req, res) => {
  try {
    const uploadsDir = path.join(path.dirname(new URL(import.meta.url).pathname), '../../uploads/audio_references');
    const files = fs.readdirSync(uploadsDir).filter(f => f.endsWith('.wav'));

    res.json({
      status: 'ready',
      voiceProfiles: files.length,
      availableVoices: files,
      backend: process.env.BACKEND_URL || 'http://localhost:5001',
      xttsToken: process.env.XTTS_HF_TOKEN ? ' Configured' : 'Missing',
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;

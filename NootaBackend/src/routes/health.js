import express from 'express';
import { getLogger } from '../config/logger.js';
import { getListenerStatus } from '../services/messageListener.js';
import { checkXTTSHealth } from '../services/xttsService.js';

const router = express.Router();
const logger = getLogger();

/**
 * GET /api/health
 * Check server health and status
 */
router.get('/', async (req, res) => {
  try {
    const xttsHealth = await checkXTTSHealth();
    const listenerStatus = getListenerStatus();

    const health = {
      success: true,
      status: 'healthy',
      timestamp: new Date().toISOString(),
      services: {
        express: 'running',
        firebase: 'configured',
        xtts: xttsHealth ? 'connected' : 'disconnected',
        messageListener: listenerStatus.isActive ? 'active' : 'inactive',
      },
      environment: process.env.NODE_ENV || 'development',
    };

    const statusCode = xttsHealth && listenerStatus.isActive ? 200 : 503;
    res.status(statusCode).json(health);
  } catch (error) {
    logger.error('Health check error:', error);
    res.status(500).json({
      success: false,
      status: 'unhealthy',
      error: error.message,
    });
  }
});

/**
 * GET /api/health/detailed
 * Get detailed health and diagnostics information
 */
router.get('/detailed', async (req, res) => {
  try {
    const xttsHealth = await checkXTTSHealth();
    const listenerStatus = getListenerStatus();

    res.json({
      success: true,
      timestamp: new Date().toISOString(),
      services: {
        express: {
          status: 'running',
          port: process.env.PORT || 5000,
        },
        firebase: {
          status: 'configured',
          projectId: process.env.FIREBASE_PROJECT_ID,
        },
        xtts: {
          status: xttsHealth ? 'connected' : 'disconnected',
          serverUrl: process.env.XTTS_SERVER_URL,
        },
        translation: {
          status: process.env.GOOGLE_CLOUD_API_KEY ? 'configured' : 'not_configured',
          provider: 'Google Cloud Translation',
        },
        messageListener: {
          status: listenerStatus.isActive ? 'active' : 'inactive',
          listeners: listenerStatus.listeners,
        },
      },
      environment: {
        nodeEnv: process.env.NODE_ENV || 'development',
        logLevel: process.env.LOG_LEVEL || 'info',
      },
    });
  } catch (error) {
    logger.error('Detailed health check error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

export default router;

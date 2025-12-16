import admin from 'firebase-admin';
import { initializeLogger } from './logger.js';

const logger = initializeLogger();

export function initializeFirebase() {
  try {
    const serviceAccount = {
      projectId: process.env.FIREBASE_PROJECT_ID,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    };

    if (!serviceAccount.projectId || !serviceAccount.privateKey || !serviceAccount.clientEmail) {
      throw new Error('Missing Firebase configuration in environment variables');
    }

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: process.env.FIREBASE_DATABASE_URL,
      storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
    });

    logger.info('Firebase Admin SDK initialized successfully');
    return admin;
  } catch (error) {
    logger.error('Firebase initialization error:', error);
    throw error;
  }
}

export function getFirebaseAdmin() {
  return admin;
}

export function getFirestore() {
  return admin.firestore();
}

export function getStorage() {
  return admin.storage();
}

export function getAuth() {
  return admin.auth();
}

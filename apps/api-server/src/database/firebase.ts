import { cert, getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
import { getFirestore } from 'firebase-admin/firestore';
import { env } from '../config/env.js';

function createFirebaseApp() {
  if (getApps().length > 0) {
    return getApp();
  }

  return initializeApp({
    credential: cert({
      projectId: env.FIREBASE_PROJECT_ID,
      clientEmail: env.FIREBASE_CLIENT_EMAIL,
      privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    }),
    databaseURL: env.FIREBASE_DATABASE_URL,
  });
}

const firebaseApp = createFirebaseApp();

export const firestore = getFirestore(firebaseApp);
export const rtdb = getDatabase(firebaseApp);

export async function checkFirestoreConnection() {
  await firestore.listCollections();
}
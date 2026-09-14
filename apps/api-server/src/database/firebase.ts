import { cert, getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getDatabase } from 'firebase-admin/database';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getStorage, type Storage } from 'firebase-admin/storage';
import { env } from '../config/env.js';

function createFirebaseApp() {
  if (getApps().length > 0) {
    return getApp();
  }

  if (process.env.VITEST) {
    return initializeApp({
      projectId: env.FIREBASE_PROJECT_ID,
      databaseURL: env.FIREBASE_DATABASE_URL,
      storageBucket: env.FIREBASE_STORAGE_BUCKET,
    });
  }

  return initializeApp({
    credential: cert({
      projectId: env.FIREBASE_PROJECT_ID,
      clientEmail: env.FIREBASE_CLIENT_EMAIL,
      privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    }),
    databaseURL: env.FIREBASE_DATABASE_URL,
    storageBucket: env.FIREBASE_STORAGE_BUCKET,
  });
}

const firebaseApp = createFirebaseApp();

export const auth = getAuth(firebaseApp);
export const firestore = getFirestore(firebaseApp);
export const rtdb = getDatabase(firebaseApp);
export const messaging = getMessaging(firebaseApp);
export const storageBucket: ReturnType<Storage['bucket']> = getStorage(firebaseApp).bucket();

export async function checkFirestoreConnection() {
  await firestore.listCollections();
}

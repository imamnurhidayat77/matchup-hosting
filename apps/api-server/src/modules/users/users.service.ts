import { FieldValue } from 'firebase-admin/firestore';
import { firestore } from '../../database/firebase.js';

export type CreateUserInput = {
  authUid: string;
  email: string;
};

export type UserRecord = {
  authUid: string;
  email: string;
  createdAt: FirebaseFirestore.Timestamp;
};

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export async function createUser(input: CreateUserInput): Promise<void> {
  const authUid = input.authUid.trim();
  const normalizedEmail = normalizeEmail(input.email);

  if (!authUid) {
    throw new Error('authUid is required');
  }

  if (!normalizedEmail) {
    throw new Error('email is required');
  }

  const userRef = firestore.collection('users').doc(authUid);
  const emailRef = firestore.collection('userEmails').doc(normalizedEmail);

  await firestore.runTransaction(async (transaction) => {
    const [userDoc, emailDoc] = await Promise.all([
      transaction.get(userRef),
      transaction.get(emailRef),
    ]);

    if (userDoc.exists) {
      throw new Error('User already exists');
    }

    if (emailDoc.exists) {
      throw new Error('Email already in use');
    }

    transaction.set(userRef, {
      authUid,
      email: normalizedEmail,
      createdAt: FieldValue.serverTimestamp(),
    });

    transaction.set(emailRef, {
      authUid,
    });
  });
}

export async function getUserByAuthUid(authUid: string): Promise<UserRecord | null> {
  const normalizedAuthUid = authUid.trim();

  if (!normalizedAuthUid) {
    throw new Error('authUid is required');
  }

  const userDoc = await firestore.collection('users').doc(normalizedAuthUid).get();

  if (!userDoc.exists) {
    return null;
  }

  const data = userDoc.data();

  if (!data) {
    return null;
  }

  if (typeof data.email !== "string") throw new Error(`Invalid user record: email must be a string`)

  if (!data.createdAt || typeof data.createdAt !== 'object' || !('toDate' in data.createdAt)) {
    throw new Error('Invalid user record: createdAt must be a Firestore Timestamp');
  }

  return {
    authUid: userDoc.id,
    email: data.email,
    createdAt: data.createdAt as FirebaseFirestore.Timestamp,
  };
}
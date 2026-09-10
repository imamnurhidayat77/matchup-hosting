import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { auth, firestore } from '../../database/firebase.js';

export type BootstrapUserInput = {
  authUid: string;
  email: string;
};

export type BootstrapUserResult = {
  authUid: string;
  email: string;
  created: boolean;
};

export type SportRatingAggregate = {
  average: number;
  count: number;
};

export type UserRecord = {
  authUid: string;
  email: string;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
  displayName?: string;
  photoUrl?: string;
  bio?: string;
  gender?: string;
  dateOfBirth?: string;
  skillLevel?: SkillLevel;
  preferredSports?: string[];
  preferredLocations?: string[];
  profileCompleted?: boolean;
  ratingBySport?: Record<string, SportRatingAggregate>;
  totalRatingCount?: number;
};

export type SkillLevel = 'beginner' | 'intermediate' | 'advanced' | 'any';

export type UpdateUserProfileInput = {
  displayName?: string;
  photoUrl?: string;
  bio?: string;
  gender?: string;
  dateOfBirth?: string;
  skillLevel?: SkillLevel;
  preferredSports?: string[];
  preferredLocations?: string[];
};

export type PublicUserProfile = {
  authUid: string;
  displayName?: string;
  photoUrl?: string;
  bio?: string;
  skillLevel?: SkillLevel;
  preferredSports?: string[];
  preferredLocations?: string[];
  profileCompleted?: boolean;
  ratingBySport?: Record<string, SportRatingAggregate>;
  totalRatingCount?: number;
};

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function isSkillLevel(value: unknown): value is SkillLevel {
  return (
    value === 'beginner' ||
    value === 'intermediate' ||
    value === 'advanced' ||
    value === 'any'
  );
}

function assertStringArray(value: unknown, fieldName: string): string[] {
  if (!Array.isArray(value) || !value.every((item) => typeof item === 'string')) {
    throw new Error(`Invalid user record: ${fieldName} must be a string array`);
  }

  return value;
}

function assertRatingBySport(value: unknown): Record<string, SportRatingAggregate> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error('Invalid user record: ratingBySport must be an object');
  }

  const result: Record<string, SportRatingAggregate> = {};

  for (const [sport, entry] of Object.entries(value as Record<string, unknown>)) {
    if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) {
      throw new Error(`Invalid user record: ratingBySport.${sport} must be an object`);
    }

    const { average, count } = entry as Record<string, unknown>;

    if (typeof average !== 'number' || typeof count !== 'number') {
      throw new Error(
        `Invalid user record: ratingBySport.${sport} must have numeric average and count`,
      );
    }

    result[sport] = { average, count };
  }

  return result;
}

function mapUserDoc(userDoc: FirebaseFirestore.DocumentSnapshot): UserRecord | null {
  if (!userDoc.exists) {
    return null;
  }

  const data = userDoc.data();

  if (!data) {
    return null;
  }

  if (typeof data.email !== 'string') {
    throw new Error('Invalid user record: email must be a string');
  }

  if (!data.createdAt || typeof data.createdAt !== 'object' || !('toDate' in data.createdAt)) {
    throw new Error('Invalid user record: createdAt must be a Firestore Timestamp');
  }

  if (
    data.updatedAt !== undefined &&
    (!data.updatedAt || typeof data.updatedAt !== 'object' || !('toDate' in data.updatedAt))
  ) {
    throw new Error('Invalid user record: updatedAt must be a Firestore Timestamp');
  }

  if (data.skillLevel !== undefined && !isSkillLevel(data.skillLevel)) {
    throw new Error('Invalid user record: skillLevel must be beginner, intermediate, advanced, or any');
  }

  if (data.profileCompleted !== undefined && typeof data.profileCompleted !== 'boolean') {
    throw new Error('Invalid user record: profileCompleted must be a boolean');
  }

  return {
    authUid: userDoc.id,
    email: data.email,
    createdAt: data.createdAt as FirebaseFirestore.Timestamp,
    ...(data.updatedAt !== undefined
      ? { updatedAt: data.updatedAt as FirebaseFirestore.Timestamp }
      : {}),
    ...(typeof data.displayName === 'string' ? { displayName: data.displayName } : {}),
    ...(typeof data.photoUrl === 'string' ? { photoUrl: data.photoUrl } : {}),
    ...(typeof data.bio === 'string' ? { bio: data.bio } : {}),
    ...(typeof data.gender === 'string' ? { gender: data.gender } : {}),
    ...(typeof data.dateOfBirth === 'string' ? { dateOfBirth: data.dateOfBirth } : {}),
    ...(isSkillLevel(data.skillLevel) ? { skillLevel: data.skillLevel } : {}),
    ...(data.preferredSports !== undefined
      ? { preferredSports: assertStringArray(data.preferredSports, 'preferredSports') }
      : {}),
    ...(data.preferredLocations !== undefined
      ? { preferredLocations: assertStringArray(data.preferredLocations, 'preferredLocations') }
      : {}),
    ...(typeof data.profileCompleted === 'boolean'
      ? { profileCompleted: data.profileCompleted }
      : {}),
    ...(data.ratingBySport !== undefined
      ? { ratingBySport: assertRatingBySport(data.ratingBySport) }
      : {}),
    ...(typeof data.totalRatingCount === 'number'
      ? { totalRatingCount: data.totalRatingCount }
      : {}),
  };
}

function toPublicUserProfile(user: UserRecord): PublicUserProfile {
  return {
    authUid: user.authUid,
    ...(user.displayName !== undefined ? { displayName: user.displayName } : {}),
    ...(user.photoUrl !== undefined ? { photoUrl: user.photoUrl } : {}),
    ...(user.bio !== undefined ? { bio: user.bio } : {}),
    ...(user.skillLevel !== undefined ? { skillLevel: user.skillLevel } : {}),
    ...(user.preferredSports !== undefined ? { preferredSports: user.preferredSports } : {}),
    ...(user.preferredLocations !== undefined ? { preferredLocations: user.preferredLocations } : {}),
    ...(user.profileCompleted !== undefined ? { profileCompleted: user.profileCompleted } : {}),
    ...(user.ratingBySport !== undefined ? { ratingBySport: user.ratingBySport } : {}),
    ...(user.totalRatingCount !== undefined ? { totalRatingCount: user.totalRatingCount } : {}),
  };
}

function isProfileCompleted(profile: UserRecord | UpdateUserProfileInput): boolean {
  return Boolean(
    profile.displayName?.trim() &&
    profile.skillLevel &&
    profile.preferredSports &&
    profile.preferredSports.length > 0,
  );
}

export async function bootstrapUser(input: BootstrapUserInput): Promise<BootstrapUserResult> {
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

  return firestore.runTransaction(async (transaction) => {
    const [userDoc, emailDoc] = await Promise.all([
      transaction.get(userRef),
      transaction.get(emailRef),
    ]);

    if (userDoc.exists) {
      const data = userDoc.data();

      if (!data || typeof data.email !== 'string') {
        throw new Error('Invalid user record: email must be a string');
      }

      return {
        authUid: userDoc.id,
        email: data.email,
        created: false,
      };
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

    return {
      authUid,
      email: normalizedEmail,
      created: true,
    };
  });
}

export async function mintCustomToken(authUid: string): Promise<string> {
  const normalizedAuthUid = authUid.trim();

  if (!normalizedAuthUid) {
    throw new Error('authUid is required');
  }

  return auth.createCustomToken(normalizedAuthUid);
}

export async function getUserByAuthUid(authUid: string): Promise<UserRecord | null> {
  const normalizedAuthUid = authUid.trim();

  if (!normalizedAuthUid) {
    throw new Error('authUid is required');
  }

  const userDoc = await firestore.collection('users').doc(normalizedAuthUid).get();

  return mapUserDoc(userDoc);
}

export async function updateUserProfile(
  authUid: string,
  input: UpdateUserProfileInput,
): Promise<UserRecord> {
  const normalizedAuthUid = authUid.trim();

  if (!normalizedAuthUid) {
    throw new Error('authUid is required');
  }

  if (Object.keys(input).length === 0) {
    throw new Error('At least one profile field is required');
  }

  const userRef = firestore.collection('users').doc(normalizedAuthUid);
  const updatedAt = Timestamp.now();

  return firestore.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    const existingUser = mapUserDoc(userDoc);

    if (!existingUser) {
      throw new Error('User not found');
    }

    const mergedUser = {
      ...existingUser,
      ...input,
    };

    const updateData = {
      ...input,
      profileCompleted: isProfileCompleted(mergedUser),
      updatedAt,
    };

    transaction.update(userRef, updateData);

    return {
      ...mergedUser,
      profileCompleted: updateData.profileCompleted,
      updatedAt,
    };
  });
}

export async function getPublicUserProfile(authUid: string): Promise<PublicUserProfile | null> {
  const user = await getUserByAuthUid(authUid);

  if (!user) {
    return null;
  }

  return toPublicUserProfile(user);
}

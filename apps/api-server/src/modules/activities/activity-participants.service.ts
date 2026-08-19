import { Timestamp } from 'firebase-admin/firestore';
import { firestore } from '../../database/firebase.js';
import {
  activityDocPath,
  activityParticipantDocPath,
  activityParticipantsCollectionPath,
} from '../../database/paths.js';
import type { ActivityStatus } from './activities.service.js';

export type ActivityParticipantRecord = {
  uid: string;
  joinedAt: FirebaseFirestore.Timestamp;
};

export type ActivityParticipantWithId = ActivityParticipantRecord & {
  participantId: string;
};

export async function joinActivity(
  activityId: string,
  uid: string,
): Promise<void> {
  const normalizedActivityId = activityId.trim();
  const normalizedUid = uid.trim();

  if (!normalizedActivityId) {
    throw new Error('activityId is required');
  }

  if (!normalizedUid) {
    throw new Error('uid is required');
  }

  const activityRef = firestore.doc(activityDocPath(normalizedActivityId));
  const participantRef = firestore.doc(
    activityParticipantDocPath(normalizedActivityId, normalizedUid),
  );

  await firestore.runTransaction(async (transaction) => {
    const now = Timestamp.now();

    const activitySnap = await transaction.get(activityRef);

    if (!activitySnap.exists) {
      throw new Error('Activity not found');
    }

    const activityData = activitySnap.data();

    if (!activityData) {
      throw new Error('Activity not found');
    }

    if (typeof activityData.status !== 'string') {
      throw new Error('Invalid activity record: status must be a string');
    }

    if (typeof activityData.capacity !== 'number') {
      throw new Error('Invalid activity record: capacity must be a number');
    }

    if (typeof activityData.participantCount !== 'number') {
      throw new Error(
        'Invalid activity record: participantCount must be a number',
      );
    }

    if (activityData.status !== 'open') {
      throw new Error('Activity is not open for joining');
    }

    if (activityData.participantCount >= activityData.capacity) {
      throw new Error('Activity is full');
    }

    const participantSnap = await transaction.get(participantRef);

    if (participantSnap.exists) {
      throw new Error('User already joined this activity');
    }

    transaction.set(participantRef, {
      uid: normalizedUid,
      joinedAt: now,
    } satisfies ActivityParticipantRecord);

    const nextParticipantCount = activityData.participantCount + 1;
    const nextStatus: ActivityStatus =
      nextParticipantCount >= activityData.capacity ? 'full' : 'open';

    transaction.update(activityRef, {
      participantCount: nextParticipantCount,
      status: nextStatus,
      updatedAt: now,
    });
  });
}

export async function getParticipants(
  activityId: string,
): Promise<ActivityParticipantWithId[]> {
  const normalizedActivityId = activityId.trim();

  if (!normalizedActivityId) {
    throw new Error('activityId is required');
  }

  const participantsSnap = await firestore
    .collection(activityParticipantsCollectionPath(normalizedActivityId))
    .get();

  return participantsSnap.docs.map((doc) => {
    const data = doc.data();

    if (typeof data.uid !== 'string') {
      throw new Error('Invalid participant record: uid must be a string');
    }

    if (
      !data.joinedAt ||
      typeof data.joinedAt !== 'object' ||
      !('toDate' in data.joinedAt)
    ) {
      throw new Error(
        'Invalid participant record: joinedAt must be a Firestore Timestamp',
      );
    }

    return {
      participantId: doc.id,
      uid: data.uid,
      joinedAt: data.joinedAt as FirebaseFirestore.Timestamp,
    };
  });
}

export async function leaveActivity(
  activityId: string,
  uid: string,
): Promise<void> {
  const normalizedActivityId = activityId.trim();
  const normalizedUid = uid.trim();

  if (!normalizedActivityId) {
    throw new Error('activityId is required');
  }

  if (!normalizedUid) {
    throw new Error('uid is required');
  }

  const activityRef = firestore.doc(activityDocPath(normalizedActivityId));
  const participantRef = firestore.doc(
    activityParticipantDocPath(normalizedActivityId, normalizedUid),
  );

  await firestore.runTransaction(async (transaction) => {
    const now = Timestamp.now();

    const activitySnap = await transaction.get(activityRef);

    if (!activitySnap.exists) {
      throw new Error('Activity not found');
    }

    const activityData = activitySnap.data();

    if (!activityData) {
      throw new Error('Activity not found');
    }

    if (typeof activityData.capacity !== 'number') {
      throw new Error('Invalid activity record: capacity must be a number');
    }

    if (typeof activityData.participantCount !== 'number') {
      throw new Error(
        'Invalid activity record: participantCount must be a number',
      );
    }

    if (typeof activityData.status !== 'string') {
      throw new Error('Invalid activity record: status must be a string');
    }

    const participantSnap = await transaction.get(participantRef);

    if (!participantSnap.exists) {
      throw new Error('Participant not found');
    }

    transaction.delete(participantRef);

    const nextParticipantCount = Math.max(activityData.participantCount - 1, 0);

    let nextStatus = activityData.status as ActivityStatus;

    if (activityData.status === 'full' && nextParticipantCount < activityData.capacity) {
      nextStatus = 'open';
    }

    transaction.update(activityRef, {
      participantCount: nextParticipantCount,
      status: nextStatus,
      updatedAt: now,
    });
  });
}
import { Timestamp } from 'firebase-admin/firestore';
import { firestore } from '../../database/firebase.js';
import {
  activityDocPath,
  activityParticipantDocPath,
  activityParticipantsCollectionPath,
} from '../../database/paths.js';
import type { ActivityStatus } from './activities.service.js';
import {
  getPublicUserProfile,
  type PublicUserProfile,
} from '../users/users.service.js';

export type ActivityParticipantRecord = {
  uid: string;
  joinedAt: FirebaseFirestore.Timestamp;
};

export type LeaveActivityInput = {
  activityId: string;
  targetUid: string;
  actorUid: string;
};

export type ActivityParticipantWithId = ActivityParticipantRecord & {
  participantId: string;
  profile: PublicUserProfile | null;
};

type ActivityParticipantBaseWithId = ActivityParticipantRecord & {
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

  const participants = participantsSnap.docs.map((doc) => {
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

  return Promise.all(participants.map(enrichParticipantWithProfile));
}

async function enrichParticipantWithProfile(
  participant: ActivityParticipantBaseWithId,
): Promise<ActivityParticipantWithId> {
  const profile = await getPublicUserProfile(participant.uid);

  return {
    ...participant,
    profile,
  };
}

export async function canAccessActivityChat(
  activityId: string,
  uid: string,
): Promise<boolean> {
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

  const [activitySnap, participantSnap] = await Promise.all([
    activityRef.get(),
    participantRef.get(),
  ]);

  if (!activitySnap.exists) {
    throw new Error('Activity not found');
  }

  const activityData = activitySnap.data();

  if (!activityData || typeof activityData.hostId !== 'string') {
    throw new Error('Invalid activity record: hostId must be a string');
  }

  return activityData.hostId === normalizedUid || participantSnap.exists;
}

export async function leaveActivity(
  input: LeaveActivityInput,
): Promise<void> {
  const normalizedActivityId = input.activityId.trim();
  const normalizedTargetUid = input.targetUid.trim();
  const normalizedActorUid = input.actorUid.trim();

  if (!normalizedActivityId) {
    throw new Error('activityId is required');
  }

  if (!normalizedTargetUid) {
    throw new Error('targetUid is required');
  }

  if (!normalizedActorUid) {
    throw new Error('actorUid is required');
  }

  const activityRef = firestore.doc(activityDocPath(normalizedActivityId));
  const participantRef = firestore.doc(
    activityParticipantDocPath(normalizedActivityId, normalizedTargetUid),
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

    if(typeof activityData.hostId !== 'string'){
      throw new Error('Invalid activity record: hostId must be a string');
    }

    const isSelfRemoval = normalizedActorUid === normalizedTargetUid;
    const isHostRemoval = activityData.hostId === normalizedActorUid;

    if(!isSelfRemoval && !isHostRemoval){
      throw new Error('Only the participant or activity host can remove this participant');
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

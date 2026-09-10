import { Timestamp } from 'firebase-admin/firestore';
import { firestore } from '../../database/firebase.js';
import {
  activityDocPath,
  activityJoinRequestDocPath,
  activityJoinRequestsCollectionPath,
  activityParticipantDocPath,
  activityParticipantsCollectionPath,
} from '../../database/paths.js';
import type { ActivityStatus } from './activities.service.js';
import {
  getPublicUserProfile,
  type PublicUserProfile,
} from '../users/users.service.js';
import { createNotification } from '../notifications/notifications.service.js';

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

    if (activityData.joinPolicy === 'approval') {
      throw new Error('This activity requires host approval — request to join instead');
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

  // Withdrawing a *pending* request is not a membership change: the
  // requester was never counted, so there is nothing to decrement and
  // no status to recompute — just delete the request row.
  if (normalizedActorUid === normalizedTargetUid) {
    const [memberSnap, pendingSnap] = await Promise.all([
      participantRef.get(),
      firestore
        .doc(activityJoinRequestDocPath(normalizedActivityId, normalizedTargetUid))
        .get(),
    ]);

    if (!memberSnap.exists && pendingSnap.exists && pendingSnap.data()?.status === 'pending') {
      await firestore
        .doc(activityJoinRequestDocPath(normalizedActivityId, normalizedTargetUid))
        .delete();
      return;
    }
  }

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

    const isHostSelfRemoval =
      activityData.hostId === normalizedActorUid &&
      normalizedActorUid === normalizedTargetUid;
    const participantSnap = await transaction.get(participantRef);

    if (!participantSnap.exists && !isHostSelfRemoval) {
      throw new Error('Participant not found');
    }

    if (participantSnap.exists) {
      transaction.delete(participantRef);
    }

    const nextParticipantCount = participantSnap.exists
      ? Math.max(activityData.participantCount - 1, 0)
      : activityData.participantCount;

    let nextStatus = activityData.status as ActivityStatus;

    if (isHostSelfRemoval) {
      nextStatus = 'cancelled';
    } else if (activityData.status === 'full' && nextParticipantCount < activityData.capacity) {
      nextStatus = 'open';
    }

    transaction.update(activityRef, {
      participantCount: nextParticipantCount,
      status: nextStatus,
      ...(isHostSelfRemoval ? { cancelledAt: now, cancelledBy: normalizedActorUid } : {}),
      updatedAt: now,
    });
  });
}

export type JoinRequestStatus = 'pending' | 'approved' | 'declined';

export type JoinRequestRecord = {
  uid: string;
  activityId: string;
  status: JoinRequestStatus;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  decidedBy?: string;
  decidedAt?: FirebaseFirestore.Timestamp;
};

export type JoinRequestWithId = JoinRequestRecord & {
  requestId: string;
  profile: PublicUserProfile | null;
};

/**
 * Parks the user in a pending join request on approval-gated
 * activities. Open activities bypass requests entirely — callers must
 * route through [joinActivity] semantics instead, so this throws when
 * the policy is `open`.
 */
export async function requestToJoin(activityId: string, uid: string): Promise<void> {
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
  const requestRef = firestore.doc(
    activityJoinRequestDocPath(normalizedActivityId, normalizedUid),
  );

  await firestore.runTransaction(async (transaction) => {
    const now = Timestamp.now();
    const [activitySnap, participantSnap, requestSnap] = await Promise.all([
      transaction.get(activityRef),
      transaction.get(participantRef),
      transaction.get(requestRef),
    ]);

    if (!activitySnap.exists) {
      throw new Error('Activity not found');
    }

    const activityData = activitySnap.data();

    if (!activityData || typeof activityData.hostId !== 'string') {
      throw new Error('Invalid activity record: hostId must be a string');
    }

    if (activityData.hostId === normalizedUid) {
      throw new Error('The host is already in this activity');
    }

    if (activityData.status !== 'open') {
      throw new Error('Activity is not open for joining');
    }

    if (activityData.joinPolicy !== 'approval') {
      throw new Error('This activity does not require approval — join directly');
    }

    if (participantSnap.exists) {
      throw new Error('User already joined this activity');
    }

    const existingStatus = requestSnap.exists
      ? (requestSnap.data()?.status as string | undefined)
      : undefined;

    if (existingStatus === 'pending') {
      throw new Error('Join request already pending');
    }

    transaction.set(requestRef, {
      uid: normalizedUid,
      activityId: normalizedActivityId,
      status: 'pending',
      createdAt: requestSnap.exists && requestSnap.data()?.createdAt
        ? (requestSnap.data() as { createdAt: FirebaseFirestore.Timestamp }).createdAt
        : now,
      updatedAt: now,
    } satisfies JoinRequestRecord);
  });

  const activitySnap = await activityRef.get();
  const hostId = activitySnap.data()?.hostId;

  if (typeof hostId === 'string' && hostId !== normalizedUid) {
    await createNotification({
      recipientUid: hostId,
      type: 'join_request',
      title: 'New join request',
      body: 'Someone requested to join your activity',
      activityId: normalizedActivityId,
      senderUid: normalizedUid,
    });
  }
}

export async function listJoinRequests(activityId: string): Promise<JoinRequestWithId[]> {
  const normalizedActivityId = activityId.trim();

  if (!normalizedActivityId) {
    throw new Error('activityId is required');
  }

  const snap = await firestore
    .collection(activityJoinRequestsCollectionPath(normalizedActivityId))
    .where('status', '==', 'pending')
    .get();

  return Promise.all(
    snap.docs.map(async (doc) => {
      const data = doc.data();
      const profile = typeof data.uid === 'string'
        ? await getPublicUserProfile(data.uid)
        : null;

      return {
        requestId: doc.id,
        uid: typeof data.uid === 'string' ? data.uid : '',
        activityId: normalizedActivityId,
        status: 'pending' as const,
        createdAt: data.createdAt as FirebaseFirestore.Timestamp,
        updatedAt: data.updatedAt as FirebaseFirestore.Timestamp,
        profile,
      };
    }),
  );
}

async function decideJoinRequest(
  activityId: string,
  targetUid: string,
  actorUid: string,
  decision: 'approved' | 'declined',
): Promise<void> {
  const normalizedActivityId = activityId.trim();
  const normalizedTargetUid = targetUid.trim();
  const normalizedActorUid = actorUid.trim();

  if (!normalizedActivityId) {
    throw new Error('activityId is required');
  }

  if (!normalizedTargetUid) {
    throw new Error('uid is required');
  }

  if (!normalizedActorUid) {
    throw new Error('actorUid is required');
  }

  const activityRef = firestore.doc(activityDocPath(normalizedActivityId));
  const requestRef = firestore.doc(
    activityJoinRequestDocPath(normalizedActivityId, normalizedTargetUid),
  );
  const participantRef = firestore.doc(
    activityParticipantDocPath(normalizedActivityId, normalizedTargetUid),
  );

  await firestore.runTransaction(async (transaction) => {
    const now = Timestamp.now();
    const [activitySnap, requestSnap, participantSnap] = await Promise.all([
      transaction.get(activityRef),
      transaction.get(requestRef),
      transaction.get(participantRef),
    ]);

    if (!activitySnap.exists) {
      throw new Error('Activity not found');
    }

    const activityData = activitySnap.data();

    if (!activityData || typeof activityData.hostId !== 'string') {
      throw new Error('Invalid activity record: hostId must be a string');
    }

    if (activityData.hostId !== normalizedActorUid) {
      throw new Error('Only the activity host can decide join requests');
    }

    if (!requestSnap.exists || requestSnap.data()?.status !== 'pending') {
      throw new Error('Join request not found');
    }

    if (decision === 'declined') {
      transaction.update(requestRef, {
        status: 'declined',
        decidedBy: normalizedActorUid,
        decidedAt: now,
        updatedAt: now,
      });
      return;
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

    if (!participantSnap.exists) {
      transaction.set(participantRef, {
        uid: normalizedTargetUid,
        joinedAt: now,
      });
    }

    const nextParticipantCount = participantSnap.exists
      ? activityData.participantCount
      : activityData.participantCount + 1;

    transaction.update(activityRef, {
      participantCount: nextParticipantCount,
      status: nextParticipantCount >= activityData.capacity ? 'full' : 'open',
      updatedAt: now,
    });
    transaction.update(requestRef, {
      status: 'approved',
      decidedBy: normalizedActorUid,
      decidedAt: now,
      updatedAt: now,
    });
  });

  await createNotification({
    recipientUid: normalizedTargetUid,
    type: decision === 'approved' ? 'activity_joined' : 'system',
    title: decision === 'approved' ? 'Request approved' : 'Request declined',
    body: decision === 'approved'
      ? 'The host approved your request — see you there!'
      : 'The host declined your join request for this activity.',
    activityId: normalizedActivityId,
    senderUid: normalizedActorUid,
  });
}

export async function approveJoinRequest(
  activityId: string,
  targetUid: string,
  actorUid: string,
): Promise<void> {
  await decideJoinRequest(activityId, targetUid, actorUid, 'approved');
}

export async function declineJoinRequest(
  activityId: string,
  targetUid: string,
  actorUid: string,
): Promise<void> {
  await decideJoinRequest(activityId, targetUid, actorUid, 'declined');
}

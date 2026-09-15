import { firestore } from '../../database/firebase.js';
import { activityAttendanceDocPath } from '../../database/paths.js';

export type CheckInInput = {
  activityId: string;
  uid: string;
  latitude?: number | undefined;
  longitude?: number | undefined;
};

export type CheckInStatus = {
  checkedIn: boolean;
  checkedInAt: number | null;
};

/**
 * Persists a check-in row at `activities/{activityId}/attendance/{uid}`.
 * Idempotent — re-checking in overwrites the row with a fresh timestamp.
 * Returns the stored `checkedInAt` millis.
 */
export async function checkIn(input: CheckInInput): Promise<number> {
  const normalizedActivityId = input.activityId.trim();
  const normalizedUid = input.uid.trim();

  if (!normalizedActivityId) {
    throw new Error('activityId is required');
  }

  if (!normalizedUid) {
    throw new Error('uid is required');
  }

  if (input.latitude !== undefined && (typeof input.latitude !== 'number' || Number.isNaN(input.latitude) || input.latitude < -90 || input.latitude > 90)) {
    throw new Error('latitude must be a number between -90 and 90');
  }

  if (input.longitude !== undefined && (typeof input.longitude !== 'number' || Number.isNaN(input.longitude) || input.longitude < -180 || input.longitude > 180)) {
    throw new Error('longitude must be a number between -180 and 180');
  }

  const checkedInAt = Date.now();
  const payload: Record<string, unknown> = { checkedInAt };
  if (input.latitude !== undefined) payload.latitude = input.latitude;
  if (input.longitude !== undefined) payload.longitude = input.longitude;

  await firestore
    .doc(activityAttendanceDocPath(normalizedActivityId, normalizedUid))
    .set(payload, { merge: true });

  return checkedInAt;
}

/** Reads the viewer's check-in row; missing doc means not checked in. */
export async function getCheckInStatus(
  activityId: string,
  uid: string,
): Promise<CheckInStatus> {
  const normalizedActivityId = activityId.trim();
  const normalizedUid = uid.trim();

  if (!normalizedActivityId) {
    throw new Error('activityId is required');
  }

  if (!normalizedUid) {
    throw new Error('uid is required');
  }

  const snap = await firestore
    .doc(activityAttendanceDocPath(normalizedActivityId, normalizedUid))
    .get();

  if (!snap.exists) {
    return { checkedIn: false, checkedInAt: null };
  }

  const data = snap.data();
  const checkedInAt =
    typeof data?.checkedInAt === 'number' ? (data.checkedInAt as number) : null;

  return { checkedIn: checkedInAt !== null, checkedInAt };
}

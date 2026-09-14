import { Timestamp } from 'firebase-admin/firestore';
import { firestore } from '../../database/firebase.js';
import type { ActivityStatus } from '../activities/activities.service.js';

export type AdminActivityView = {
    id: string;
    title: string;
    sportType: string;
    locationName: string;
    startTime: string | null;
    status: ActivityStatus;
    capacity: number;
    participantCount: number;
    hostId: string;
    hostDisplayName: string;
    createdAt: string | null;
};

/** Admin-triageable statuses. `removed` = hidden from every feed. */
const ADMIN_STATUSES: readonly ActivityStatus[] = [
    'open',
    'cancelled',
    'completed',
    'removed',
];

export function isAdminActivityStatus(value: unknown): value is ActivityStatus {
    return (
        typeof value === 'string' &&
        (ADMIN_STATUSES as readonly string[]).includes(value)
    );
}

export const ADMIN_ACTIVITIES_LIMIT_DEFAULT = 20;
export const ADMIN_ACTIVITIES_LIMIT_MAX = 100;

function toIso(value: unknown): string | null {
    if (
        value !== null &&
        typeof value === 'object' &&
        'toDate' in value &&
        typeof (value as { toDate: unknown }).toDate === 'function'
    ) {
        try {
            return (value as { toDate: () => Date }).toDate().toISOString();
        } catch {
            return null;
        }
    }
    return typeof value === 'string' ? value : null;
}

async function hostDisplayName(hostId: string): Promise<string> {
    try {
        const snap = await firestore.collection('users').doc(hostId).get();
        const name = snap.exists ? snap.data()?.displayName : undefined;
        return typeof name === 'string' && name.length > 0 ? name : '';
    } catch {
        return '';
    }
}

/** Newest-first admin table. Host names resolved best-effort. */
export async function listAdminActivities(
    limit: number,
): Promise<AdminActivityView[]> {
    const take = Math.trunc(limit);
    if (!Number.isFinite(take) || take < 1 || take > ADMIN_ACTIVITIES_LIMIT_MAX) {
        throw new Error(
            `limit must be between 1 and ${ADMIN_ACTIVITIES_LIMIT_MAX}`,
        );
    }
    const snap = await firestore.collection('activities').limit(take).get();
    const rows = snap.docs
        .map((doc) => ({ id: doc.id, data: doc.data() }))
        .filter((r) => typeof r.data.title === 'string')
        .sort((a, b) => {
            const at = toIso(a.data.createdAt) ?? '';
            const bt = toIso(b.data.createdAt) ?? '';
            return bt.localeCompare(at);
        });
    return Promise.all(
        rows.map(async (r) => ({
            id: r.id,
            title: r.data.title as string,
            sportType:
                typeof r.data.sportType === 'string' ? r.data.sportType : '',
            locationName:
                typeof r.data.locationName === 'string' ? r.data.locationName : '',
            startTime: toIso(r.data.startTime),
            status: (r.data.status ?? 'open') as ActivityStatus,
            capacity: typeof r.data.capacity === 'number' ? r.data.capacity : 0,
            participantCount:
                typeof r.data.participantCount === 'number'
                    ? r.data.participantCount
                    : 0,
            hostId: typeof r.data.hostId === 'string' ? r.data.hostId : '',
            hostDisplayName: await hostDisplayName(
                typeof r.data.hostId === 'string' ? r.data.hostId : '',
            ),
            createdAt: toIso(r.data.createdAt),
        })),
    );
}

/**
 * Admin status override — same write the host flow performs, without the
 * host-ownership check (the route is admin-gated instead).
 */
export async function setAdminActivityStatus(
    activityId: string,
    status: unknown,
): Promise<void> {
    const normalizedId = activityId.trim();
    if (!normalizedId) {
        throw new Error('activityId is required');
    }
    if (!isAdminActivityStatus(status)) {
        throw new Error('status must be open, cancelled, completed, or removed');
    }
    const ref = firestore.collection('activities').doc(normalizedId);
    const snap = await ref.get();
    if (!snap.exists) {
        throw new Error('Activity not found');
    }
    await ref.update({ status, updatedAt: Timestamp.now() });
}

/** Removes the activity doc. Participant/join-request subcollections are
 * left orphaned (Firestore has no cascade) and no longer resolve to a
 * parent, so they stay invisible to every feed. */
export async function deleteAdminActivity(activityId: string): Promise<void> {
    const normalizedId = activityId.trim();
    if (!normalizedId) {
        throw new Error('activityId is required');
    }
    const ref = firestore.collection('activities').doc(normalizedId);
    const snap = await ref.get();
    if (!snap.exists) {
        throw new Error('Activity not found');
    }
    await ref.delete();
}

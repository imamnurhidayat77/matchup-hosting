import { Timestamp } from 'firebase-admin/firestore';
import { auth, firestore } from '../../database/firebase.js';
import {
    countUserActivities,
    isUserStatus,
    type UserStatus,
} from '../users/users.service.js';

export type AdminMemberView = {
    uid: string;
    email: string;
    displayName?: string;
    photoUrl?: string;
    status: UserStatus;
    createdAt: string | null;
    activitiesCount?: number;
    hostedCount?: number;
};

export const ADMIN_MEMBERS_PAGE_LIMIT_DEFAULT = 20;
export const ADMIN_MEMBERS_PAGE_LIMIT_MAX = 100;

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

function mapMemberRow(
    id: string,
    data: FirebaseFirestore.DocumentData | undefined,
): AdminMemberView | null {
    if (!data || typeof data.email !== 'string') return null;
    return {
        uid: id,
        email: data.email,
        ...(typeof data.displayName === 'string' ? { displayName: data.displayName } : {}),
        ...(typeof data.photoUrl === 'string' ? { photoUrl: data.photoUrl } : {}),
        status: isUserStatus(data.status) ? data.status : 'active',
        createdAt: toIso(data.createdAt),
    };
}

/** Paginated user list for the admin Members table (no counts — list stays cheap). */
export async function listMembers(limit: number): Promise<AdminMemberView[]> {
    const take = Math.trunc(limit);
    if (!Number.isFinite(take) || take < 1 || take > ADMIN_MEMBERS_PAGE_LIMIT_MAX) {
        throw new Error(
            `limit must be between 1 and ${ADMIN_MEMBERS_PAGE_LIMIT_MAX}`,
        );
    }
    const snap = await firestore.collection('users').limit(take).get();
    const views: AdminMemberView[] = [];
    for (const doc of snap.docs) {
        const view = mapMemberRow(doc.id, doc.data());
        if (view) views.push(view);
    }
    return views;
}

/** Member detail with live participation counts (reuses the user module). */
export async function getMemberDetail(uid: string): Promise<AdminMemberView> {
    const normalizedUid = uid.trim();
    if (!normalizedUid) {
        throw new Error('uid is required');
    }
    const snap = await firestore.collection('users').doc(normalizedUid).get();
    if (!snap.exists) {
        throw new Error('User not found');
    }
    const view = mapMemberRow(snap.id, snap.data());
    if (!view) {
        throw new Error('User not found');
    }
    const counts = await countUserActivities(normalizedUid);
    return { ...view, ...counts };
}

/** Suspend/reactivate. Only the status enum is writable (mass-assignment safe). */
export async function setMemberStatus(
    uid: string,
    status: unknown,
): Promise<AdminMemberView> {
    const normalizedUid = uid.trim();
    if (!normalizedUid) {
        throw new Error('uid is required');
    }
    if (!isUserStatus(status)) {
        throw new Error('status must be active or suspended');
    }
    const ref = firestore.collection('users').doc(normalizedUid);
    const snap = await ref.get();
    if (!snap.exists) {
        throw new Error('User not found');
    }
    await ref.update({ status, updatedAt: Timestamp.now() });
    return getMemberDetail(normalizedUid);
}

/**
 * Full offboard: Auth account (best-effort when already gone) + user doc
 * + email index. Auth deletion runs first so a failure leaves nothing
 * half-deleted.
 */
export async function deleteMember(uid: string): Promise<void> {
    const normalizedUid = uid.trim();
    if (!normalizedUid) {
        throw new Error('uid is required');
    }
    const ref = firestore.collection('users').doc(normalizedUid);
    const snap = await ref.get();
    if (!snap.exists) {
        throw new Error('User not found');
    }
    const email = snap.data()?.email;
    try {
        await auth.deleteUser(normalizedUid);
    } catch (error) {
        const code = (error as { code?: unknown }).code;
        if (code !== 'auth/user-not-found') {
            throw new Error('Could not delete auth account');
        }
    }
    await ref.delete();
    if (typeof email === 'string' && email.length > 0) {
        await firestore
            .collection('userEmails')
            .doc(email.toLowerCase())
            .delete()
            .catch(() => undefined);
    }
}

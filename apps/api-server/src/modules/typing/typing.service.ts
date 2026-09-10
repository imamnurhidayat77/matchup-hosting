import { rtdb } from '../../database/firebase.js';
import { typingPath } from '../../database/paths.js';

export type TypingRecord = {
    isTyping: boolean;
};

/**
 * How long a `true` typing row stays valid without a refresh. The
 * mobile client re-announces typing every few seconds while the user
 * types and writes `false` on send/stop, but a killed app or a lost
 * `false` write used to leave `isTyping: true` stuck forever ("Sarah
 * is always typing"). Rows older than this are read back as `false`.
 */
export const TYPING_TTL_MS = 10_000;

function isTypingStale(updatedAt: unknown): boolean {
    return (
        typeof updatedAt !== 'number' ||
        Number.isNaN(updatedAt) ||
        Date.now() - updatedAt > TYPING_TTL_MS
    );
}

export async function setTyping(activityId: string, uid: string, isTyping: boolean): Promise<void>{
    const normalizedActivityId = activityId.trim();
    const normalizedUid = uid.trim();

    if(!normalizedActivityId) throw new Error('activityId is required');
    if(!normalizedUid) throw new Error('UID is required');

    await rtdb.ref(typingPath(normalizedActivityId, normalizedUid)).set({
        isTyping,
        updatedAt: Date.now(),
    });
}

export async function getTyping(activityId: string, uid: string): Promise<TypingRecord | null>{
    const normalizedActivityId = activityId.trim();
    const normalizedUid = uid.trim();

    if(!normalizedActivityId) throw new Error('activityId is required');
    if(!normalizedUid) throw new Error ('uid is required');

    const snapshot = await rtdb.ref(typingPath(normalizedActivityId, normalizedUid)).get();

    if(!snapshot.exists()) return null;

    const data = snapshot.val() as (Partial<TypingRecord> & { updatedAt?: unknown }) | null;

    if(!data) return null;

    if (typeof data.isTyping !== 'boolean') throw new Error ('Invalid typing record: isTyping must be a boolean');

    if (data.isTyping && isTypingStale(data.updatedAt)) {
        return {
            isTyping: false,
        };
    }

    return {
        isTyping: data.isTyping,
    };

}
import { rtdb } from '../../database/firebase.js';
import { typingPath } from '../../database/paths.js';

export type TypingRecord = {
    isTyping: boolean;
};

export async function setTyping(activityId: string, uid: string, isTyping: boolean): Promise<void>{
    const normalizedActivityId = activityId.trim();
    const normalizedUid = uid.trim();

    if(!normalizedActivityId) throw new Error('activityId is required');
    if(!normalizedUid) throw new Error('UID is required');

    await rtdb.ref(typingPath(normalizedActivityId, normalizedUid)).set({isTyping,});
}

export async function getTyping(activityId: string, uid: string): Promise<TypingRecord | null>{
    const normalizedActivityId = activityId.trim();
    const normalizedUid = uid.trim();

    if(!normalizedActivityId) throw new Error('activityId is required');
    if(!normalizedUid) throw new Error ('uid is required');

    const snapshot = await rtdb.ref(typingPath(normalizedActivityId, normalizedUid)).get();

    if(!snapshot.exists()) return null;

    const data = snapshot.val() as Partial<TypingRecord> | null;

    if(!data) return null;

    if (typeof data.isTyping !== 'boolean') throw new Error ('Invalid typing record: isTyping must be a boolean');

    return {
        isTyping: data.isTyping,
    };

}
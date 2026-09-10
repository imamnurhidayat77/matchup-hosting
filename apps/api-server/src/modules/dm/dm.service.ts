import { rtdb } from '../../database/firebase.js';
import { dmMessagesPath, dmThreadId } from '../../database/paths.js';
import { createNotification } from '../notifications/notifications.service.js';
import {
    getPublicUserProfile,
    getUserByAuthUid,
} from '../users/users.service.js';

export type DmMessageWithId = {
    messageId: string;
    senderId: string;
    text: string;
    timestamp: number;
};

function assertPeer(viewerUid: string, peerUid: string): { me: string; peer: string } {
    const me = viewerUid.trim();
    const peer = peerUid.trim();
    if (!me) throw new Error('viewerUid is required');
    if (!peer) throw new Error('peer uid is required');
    if (me === peer) throw new Error('cannot message yourself');
    return { me, peer };
}

async function assertPeerExists(peer: string): Promise<void> {
    const user = await getUserByAuthUid(peer);
    if (!user) throw new Error('User not found');
}

/**
 * Resolves (no write) the canonical 1-on-1 thread for the viewer +
 * peer pair. Both directions map to the same `conversationId`, so
 * clients can derive it locally for RTDB watches.
 */
export async function resolveThread(
    viewerUid: string,
    peerUid: string,
): Promise<{ conversationId: string }> {
    const { me, peer } = assertPeer(viewerUid, peerUid);
    await assertPeerExists(peer);
    return { conversationId: dmThreadId(me, peer) };
}

export async function listDmMessages(
    viewerUid: string,
    peerUid: string,
    limit = 50,
): Promise<DmMessageWithId[]> {
    const { me, peer } = assertPeer(viewerUid, peerUid);
    await assertPeerExists(peer);

    const snapshot = await rtdb.ref(dmMessagesPath(me, peer)).get();
    if (!snapshot.exists()) return [];

    const data = snapshot.val() as Record<string, Partial<DmMessageWithId>> | null;
    if (!data) return [];

    const messages: DmMessageWithId[] = [];
    for (const [messageId, value] of Object.entries(data)) {
        if (!value) continue;
        if (typeof value.senderId !== 'string') {
            throw new Error('Invalid DM: senderId must be a string');
        }
        if (typeof value.text !== 'string') {
            throw new Error('Invalid DM: text must be a string');
        }
        if (typeof value.timestamp !== 'number') {
            throw new Error('Invalid DM: timestamp must be a number');
        }
        messages.push({
            messageId,
            senderId: value.senderId,
            text: value.text,
            timestamp: value.timestamp,
        });
    }

    messages.sort((a, b) => a.timestamp - b.timestamp);
    return messages.slice(-Math.min(Math.max(limit, 1), 100));
}

export async function sendDmMessage(
    viewerUid: string,
    peerUid: string,
    text: string,
): Promise<{ messageId: string; conversationId: string }> {
    const { me, peer } = assertPeer(viewerUid, peerUid);
    const normalizedText = text.trim();
    if (!normalizedText) throw new Error('text is required');
    if (normalizedText.length > 2000) {
        throw new Error('text must be at most 2000 characters');
    }
    await assertPeerExists(peer);

    const conversationId = dmThreadId(me, peer);
    const messageRef = rtdb.ref(dmMessagesPath(me, peer));
    const newMessageRef = messageRef.push();
    await newMessageRef.set({
        senderId: me,
        text: normalizedText,
        timestamp: Date.now(),
    });

    // Nudge the peer (fire-and-forget inside createNotification's own
    // push bridge — failures never fail the send).
    let senderName = 'Someone';
    try {
        const profile = await getPublicUserProfile(me);
        if (profile?.displayName) senderName = profile.displayName;
    } catch {
        // Fall through to the generic name.
    }
    await createNotification({
        recipientUid: peer,
        type: 'dm_message',
        title: `New message from ${senderName}`,
        body:
            normalizedText.length > 100
                ? `${normalizedText.slice(0, 100)}…`
                : normalizedText,
        senderUid: me,
    }).catch(() => undefined);

    return { messageId: newMessageRef.key as string, conversationId };
}

import { beforeEach, describe, expect, it, vi } from 'vitest';

/**
 * Stateful in-memory RTDB fake: supports ref().get/set/update/push
 * over a plain Map so inbox entry lifecycles can be asserted.
 */
function makeRtdb() {
    const store = new Map<string, unknown>();
    const ref = (path: string) => ({
        push: () => ({
            key: `msg-${store.size + 1}`,
            set: async (v: unknown) => {
                store.set(`${path}/msg-${store.size + 1}`, v);
            },
        }),
        get: async () => {
            // Aggregate direct children like real RTDB parent reads.
            if (store.has(path)) {
                return { exists: () => true, val: () => store.get(path) };
            }
            const prefix = `${path}/`;
            const kids: Record<string, unknown> = {};
            let found = false;
            for (const [k, v] of store) {
                if (!k.startsWith(prefix)) continue;
                const rest = k.slice(prefix.length);
                if (rest.includes('/')) continue;
                kids[rest] = v;
                found = true;
            }
            return { exists: () => found, val: () => (found ? kids : null) };
        },
        set: async (v: unknown) => {
            store.set(path, v);
        },
        update: async (v: Record<string, unknown>) => {
            store.set(path, { ...((store.get(path) as object) ?? {}), ...v });
        },
    });
    return { store, ref };
}

const rtdbState = vi.hoisted(() => ({ current: null as null | ReturnType<typeof makeRtdb> }));

vi.mock('../../database/firebase.js', () => ({
    rtdb: { ref: (path: string) => rtdbState.current!.ref(path) },
    firestore: { collection: vi.fn(), doc: vi.fn() },
    auth: {},
    messaging: {},
}));

vi.mock('../users/users.service.js', () => ({
    getUserByAuthUid: vi.fn(async (uid: string) => ({ authUid: uid })),
    getPublicUserProfile: vi.fn(async (uid: string) => ({ displayName: `Name-${uid}` })),
}));

vi.mock('../notifications/notifications.service.js', () => ({
    createNotification: vi.fn(async () => ({ notificationId: 'n-1' })),
}));

import {
    listDmConversations,
    markDmThreadRead,
    sendDmMessage,
} from './dm.service.js';

beforeEach(() => {
    rtdbState.current = makeRtdb();
    vi.clearAllMocks();
});

describe('DM inbox metadata', () => {
    it('send bumps peer unread and keeps sender count', async () => {
        await sendDmMessage('me-1', 'peer-1', 'hello');
        await sendDmMessage('me-1', 'peer-1', 'again');

        const { store } = rtdbState.current!;
        const peerEntry = store.get('userDMs/peer-1/me-1') as Record<string, unknown>;
        const senderEntry = store.get('userDMs/me-1/peer-1') as Record<string, unknown>;

        expect(peerEntry.unreadCount).toBe(2);
        expect(peerEntry.lastText).toBe('again');
        expect(senderEntry.unreadCount).toBe(0);
        expect(senderEntry.lastSenderId).toBe('me-1');
    });

    it('a reply bumps the other side back', async () => {
        await sendDmMessage('me-1', 'peer-1', 'hi');
        await sendDmMessage('peer-1', 'me-1', 'yo');

        const { store } = rtdbState.current!;
        expect((store.get('userDMs/me-1/peer-1') as Record<string, unknown>).unreadCount).toBe(1);
        expect((store.get('userDMs/peer-1/me-1') as Record<string, unknown>).unreadCount).toBe(1);
    });

    it('listDmConversations returns newest-first enriched rows', async () => {
        await sendDmMessage('me-1', 'peer-1', 'first');
        // Distinct millis so the recency sort is deterministic.
        await new Promise((r) => setTimeout(r, 5));
        await sendDmMessage('me-1', 'peer-2', 'second');

        const rows = await listDmConversations('me-1');

        expect(rows.map((r) => r.peerUid)).toEqual(['peer-2', 'peer-1']);
        expect(rows[0]).toMatchObject({
            displayName: 'Name-peer-2',
            lastText: 'second',
            unreadCount: 0,
        });
    });

    it('markDmThreadRead clears the badge and is a no-op when absent', async () => {
        await sendDmMessage('peer-1', 'me-1', 'hey');
        let rows = await listDmConversations('me-1');
        expect(rows[0].unreadCount).toBe(1);

        await markDmThreadRead('me-1', 'peer-1');
        rows = await listDmConversations('me-1');
        expect(rows[0].unreadCount).toBe(0);

        await expect(markDmThreadRead('me-1', 'nobody')).resolves.toBeUndefined();
    });

    it('empty inbox returns empty list', async () => {
        await expect(listDmConversations('lonely')).resolves.toEqual([]);
    });
});

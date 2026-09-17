import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../../database/firebase.js', () => ({
    firestore: { collection: vi.fn(), collectionGroup: vi.fn(), doc: vi.fn() },
    auth: {},
    rtdb: {},
}));

vi.mock('./audit.service.js', () => ({
    logAdminAction: vi.fn(),
}));

import { firestore } from '../../database/firebase.js';
import { logAdminAction } from './audit.service.js';
import {
    deleteAdminActivity,
    listAdminActivities,
    setAdminActivityStatus,
} from './activities.service.js';

const activityRow = (overrides: Record<string, unknown> = {}) => ({
    title: 'Sunday Run',
    sportType: 'Running',
    locationName: 'Domain',
    startTime: '2026-09-10T08:00:00Z',
    status: 'open',
    capacity: 10,
    participantCount: 4,
    hostId: 'host-1',
    createdAt: { toDate: () => new Date('2026-09-01T10:00:00Z') },
    ...overrides,
});

function mockActivities(docs: { id: string; data: Record<string, unknown> }[]) {
    const store = new Map(docs.map((d) => [d.id, d.data]));
    vi.mocked(firestore.collection).mockImplementation(((name: string) => {
        if (name === 'activities') {
            return {
                limit: vi.fn().mockReturnValue({
                    get: async () => ({
                        docs: [...store.entries()].map(([id, data]) => ({
                            id,
                            data: () => data,
                        })),
                    }),
                }),
                doc: (id: string) => ({
                    get: async () => {
                        const data = store.get(id);
                        return data === undefined
                            ? { exists: false }
                            : { exists: true, id, data: () => data };
                    },
                    update: vi.fn().mockImplementation(async (patch: Record<string, unknown>) => {
                        store.set(id, { ...(store.get(id) ?? {}), ...patch });
                    }),
                    delete: vi.fn().mockImplementation(async () => {
                        store.delete(id);
                    }),
                }),
            };
        }
        // users (host lookup) — resolve empty.
        return {
            doc: () => ({ get: async () => ({ exists: false }) }),
        };
    }) as never);
    return store;
}

beforeEach(() => {
    vi.clearAllMocks();
});

describe('listAdminActivities', () => {
    it('returns newest-first rows with host fallback', async () => {
        mockActivities([
            { id: 'a-old', data: activityRow() },
            {
                id: 'a-new',
                data: activityRow({
                    title: 'Night Ride',
                    createdAt: { toDate: () => new Date('2026-09-05T10:00:00Z') },
                }),
            },
        ]);
        const rows = await listAdminActivities(20);
        expect(rows).toHaveLength(2);
        expect(rows[0]!.id).toBe('a-new');
        expect(rows[0]!.hostDisplayName).toBe('');
    });

    it('rejects out-of-range limit', async () => {
        mockActivities([]);
        await expect(listAdminActivities(0)).rejects.toThrow(
            'limit must be between 1 and 100',
        );
    });
});

describe('setAdminActivityStatus', () => {
    it('writes removed without host check', async () => {
        const store = mockActivities([{ id: 'a-1', data: activityRow() }]);
        await setAdminActivityStatus('a-1', 'removed', 'admin-1');
        expect(store.get('a-1')!.status).toBe('removed');
    });

    it('rejects non-allowlisted status', async () => {
        mockActivities([{ id: 'a-1', data: activityRow() }]);
        await expect(setAdminActivityStatus('a-1', 'hidden', 'admin-1')).rejects.toThrow(
            'status must be open, cancelled, completed, or removed',
        );
    });

    it('throws for missing activity', async () => {
        mockActivities([]);
        await expect(setAdminActivityStatus('ghost', 'removed', 'admin-1')).rejects.toThrow(
            'Activity not found',
        );
    });

    it('logs the status change with before/after state', async () => {
        mockActivities([{ id: 'a-1', data: activityRow({ status: 'open', title: 'Sunday Run' }) }]);
        await setAdminActivityStatus('a-1', 'removed', 'admin-1', 'admin@x.com');
        expect(logAdminAction).toHaveBeenCalledWith(
            expect.objectContaining({
                category: 'Activities',
                action: 'activity.status_change',
                adminUid: 'admin-1',
                adminEmail: 'admin@x.com',
                targetId: 'a-1',
                targetLabel: 'Sunday Run',
                before: { status: 'open' },
                after: { status: 'removed' },
            }),
        );
    });
});

describe('deleteAdminActivity', () => {
    it('deletes the doc', async () => {
        const store = mockActivities([{ id: 'a-1', data: activityRow() }]);
        await deleteAdminActivity('a-1', 'admin-1');
        expect(store.has('a-1')).toBe(false);
    });

    it('throws for missing activity', async () => {
        mockActivities([]);
        await expect(deleteAdminActivity('ghost', 'admin-1')).rejects.toThrow(
            'Activity not found',
        );
    });

    it('logs the deletion with a before snapshot', async () => {
        mockActivities([{ id: 'a-1', data: activityRow({ title: 'Sunday Run' }) }]);
        await deleteAdminActivity('a-1', 'admin-1', 'admin@x.com');
        expect(logAdminAction).toHaveBeenCalledWith(
            expect.objectContaining({
                category: 'Activities',
                action: 'activity.delete',
                adminUid: 'admin-1',
                adminEmail: 'admin@x.com',
                targetId: 'a-1',
                targetLabel: 'Sunday Run',
            }),
        );
    });
});

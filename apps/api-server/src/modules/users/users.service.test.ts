import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../../database/firebase.js', () => {
    return {
        auth: {},
        firestore: {
            collection: vi.fn(),
            collectionGroup: vi.fn(),
            doc: vi.fn(),
        },
    };
});

import { Timestamp } from 'firebase-admin/firestore';
import { firestore } from '../../database/firebase.js';
import { countUserActivities, getPublicUserProfile, getUserByAuthUid } from './users.service.js';

function mockUserDoc() {
    const userGet = vi.fn().mockResolvedValue({
        id: 'user-1',
        exists: true,
        data: () => ({ email: 'user@example.com', createdAt: Timestamp.now() }),
    });
    vi.mocked(firestore.collection).mockImplementation(
        ((name: string) => {
            if (name === 'users') return { doc: () => ({ get: userGet }) };
            throw new Error(`unexpected collection: ${name}`);
        }) as never,
    );
}

function mockCounts(joined: number, hosted: number) {
    const joinedGet = vi.fn().mockResolvedValue({ data: () => ({ count: joined }) });
    const hostedGet = vi.fn().mockResolvedValue({ data: () => ({ count: hosted }) });
    vi.mocked(firestore.collectionGroup).mockReturnValue({
        where: () => ({ count: () => ({ get: joinedGet }) }),
    } as never);
    vi.mocked(firestore.collection).mockImplementation(
        ((name: string) => {
            if (name === 'users') {
                return {
                    doc: () => ({
                        get: async () => ({
                            id: 'user-1',
                            exists: true,
                            data: () => ({ email: 'user@example.com', createdAt: Timestamp.now() }),
                        }),
                    }),
                };
            }
            if (name === 'activities') {
                return { where: () => ({ count: () => ({ get: hostedGet }) }) };
            }
            throw new Error(`unexpected collection: ${name}`);
        }) as never,
    );
    return { joinedGet, hostedGet };
}

describe('user activity counts', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it('getUserByAuthUid attaches joined and hosted counts', async () => {
        mockCounts(3, 2);

        const user = await getUserByAuthUid('user-1');

        expect(user?.activitiesCount).toBe(3);
        expect(user?.hostedCount).toBe(2);
        expect(firestore.collectionGroup).toHaveBeenCalledWith('participants');
    });

    it('countUserActivities falls back to zeros when aggregation fails', async () => {
        mockUserDoc();
        vi.mocked(firestore.collectionGroup).mockImplementation(() => {
            throw new Error('index missing');
        });

        await expect(countUserActivities('user-1')).resolves.toEqual({
            activitiesCount: 0,
            hostedCount: 0,
        });
    });

    it('getUserByAuthUid returns null without counting when the user is missing', async () => {
        vi.mocked(firestore.collection).mockReturnValue({
            doc: () => ({ get: async () => ({ exists: false }) }),
        } as never);

        await expect(getUserByAuthUid('missing')).resolves.toBeNull();
        expect(firestore.collectionGroup).not.toHaveBeenCalled();
    });

    it('getPublicUserProfile passes counts through', async () => {
        mockCounts(1, 0);

        const profile = await getPublicUserProfile('user-1');

        expect(profile?.activitiesCount).toBe(1);
        expect(profile?.hostedCount).toBe(0);
    });
});

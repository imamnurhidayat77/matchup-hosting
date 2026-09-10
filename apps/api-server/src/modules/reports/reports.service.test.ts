import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../../database/firebase.js', () => {
    return {
        firestore: {
            doc: vi.fn(),
            collection: vi.fn(),
        },
    };
});

import { firestore } from '../../database/firebase.js';
import { submitReport } from './reports.service.js';

function mockTargetExists(exists: boolean) {
    vi.mocked(firestore.doc).mockReturnValue({
        get: async () => ({ exists }),
    } as never);
}

function mockAdd(reportId = 'report-1') {
    const add = vi.fn().mockResolvedValue({ id: reportId });
    vi.mocked(firestore.collection).mockReturnValue({ add } as never);
    return add;
}

const baseInput = {
    reporterId: 'reporter-1',
    targetId: 'activity-1',
    targetType: 'activity' as const,
    reason: 'Spam / Fake activity',
};

describe('reports service', () => {
    beforeEach(() => {
        vi.clearAllMocks();
        mockTargetExists(true);
        mockAdd();
    });

    it('stores a pending report and returns its id', async () => {
        const add = mockAdd('report-9');

        const result = await submitReport({ ...baseInput, details: 'Copy-pasted' });

        expect(result).toEqual({ reportId: 'report-9' });
        expect(firestore.collection).toHaveBeenCalledWith('reports');
        expect(add).toHaveBeenCalledOnce();
        const record = vi.mocked(add).mock.calls[0][0] as Record<string, unknown>;
        expect(record).toMatchObject({
            reporterId: 'reporter-1',
            targetId: 'activity-1',
            targetType: 'activity',
            reason: 'Spam / Fake activity',
            details: 'Copy-pasted',
            status: 'pending',
        });
        expect(record.createdAt).toBeDefined();
    });

    it('omits details when blank', async () => {
        const add = mockAdd();

        await submitReport({ ...baseInput, details: '   ' });

        const record = vi.mocked(add).mock.calls[0][0] as Record<string, unknown>;
        expect(record).not.toHaveProperty('details');
    });

    it('checks the activity document for activity targets', async () => {
        mockTargetExists(true);

        await submitReport(baseInput);

        expect(firestore.doc).toHaveBeenCalledWith('activities/activity-1');
    });

    it('checks the user document for user targets', async () => {
        mockTargetExists(true);

        await submitReport({ ...baseInput, targetId: 'user-2', targetType: 'user' });

        expect(firestore.doc).toHaveBeenCalledWith('users/user-2');
    });

    it('throws Target not found when the target is missing', async () => {
        mockTargetExists(false);

        await expect(submitReport(baseInput)).rejects.toThrow('Target not found');
        expect(firestore.collection).not.toHaveBeenCalled();
    });

    it('rejects self-reports', async () => {
        await expect(
            submitReport({ ...baseInput, targetId: 'reporter-1', targetType: 'user' }),
        ).rejects.toThrow('cannot report yourself');
    });

    it.each([
        { name: 'blank targetId', input: { ...baseInput, targetId: '   ' } },
        { name: 'blank reason', input: { ...baseInput, reason: '   ' } },
        { name: 'blank reporterId', input: { ...baseInput, reporterId: '   ' } },
    ])('rejects $name', async ({ input }) => {
        await expect(submitReport(input)).rejects.toThrow('required');
    });

    it('rejects an invalid targetType', async () => {
        await expect(
            submitReport({ ...baseInput, targetType: 'group' as never }),
        ).rejects.toThrow('targetType must be user or activity');
    });

    it('rejects an overlong reason', async () => {
        await expect(
            submitReport({ ...baseInput, reason: 'x'.repeat(201) }),
        ).rejects.toThrow('at most 200 characters');
    });
});

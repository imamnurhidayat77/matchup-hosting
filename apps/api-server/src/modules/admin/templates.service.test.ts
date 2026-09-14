import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../../database/firebase.js', () => ({
    firestore: { collection: vi.fn(), collectionGroup: vi.fn(), doc: vi.fn() },
    auth: {},
    rtdb: {},
}));

import { firestore } from '../../database/firebase.js';
import { listTemplates, updateTemplate } from './templates.service.js';

function mockTemplates(seed: Record<string, Record<string, unknown>> = {}) {
    const store = new Map(Object.entries(seed));
    vi.mocked(firestore.collection).mockImplementation(() => ({
        get: async () => ({
            docs: [...store.entries()].map(([id, data]) => ({
                id,
                data: () => data,
            })),
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
        }),
    }) as never);
    return store;
}

const templateRow = () => ({
    trigger: 'activity.joined',
    category: 'Activity',
    name: 'Joined',
    description: 'Fires on join',
    title: 'Welcome!',
    body: 'You joined {{activity}}',
    variables: ['activity'],
    enabled: true,
});

beforeEach(() => {
    vi.clearAllMocks();
});

describe('listTemplates', () => {
    it('returns mapped rows sorted by trigger', async () => {
        mockTemplates({ 'activity.joined': templateRow() });
        const rows = await listTemplates();
        expect(rows).toHaveLength(1);
        expect(rows[0]).toMatchObject({
            id: 'activity.joined',
            title: 'Welcome!',
            enabled: true,
        });
    });
});

describe('updateTemplate', () => {
    it('patches copy fields and stamps edit time', async () => {
        mockTemplates({ 'activity.joined': templateRow() });
        const row = await updateTemplate('activity.joined', {
            title: 'Hi!',
            enabled: false,
        });
        expect(row).toMatchObject({ title: 'Hi!', enabled: false });
        expect(row.lastEditedAt).not.toBeNull();
    });

    it('rejects blank copy and wrong types', async () => {
        mockTemplates({ 'activity.joined': templateRow() });
        await expect(
            updateTemplate('activity.joined', { title: '  ' }),
        ).rejects.toThrow('title is required');
        await expect(
            updateTemplate('activity.joined', { enabled: 'yes' }),
        ).rejects.toThrow('enabled must be a boolean');
        await expect(updateTemplate('activity.joined', {})).rejects.toThrow(
            'No updatable template fields provided',
        );
    });

    it('throws for missing template', async () => {
        mockTemplates({});
        await expect(
            updateTemplate('ghost', { title: 'Hi' }),
        ).rejects.toThrow('Template not found');
    });
});

import { describe, expect, it, vi, beforeEach } from 'vitest';

const { apiFetchMock } = vi.hoisted(() => ({ apiFetchMock: vi.fn() }));
vi.mock('./api', () => ({ apiFetch: apiFetchMock }));

import { fetchAuditLog } from './auditLogService';

function entryView(overrides: Record<string, unknown> = {}) {
  return {
    id: 'e1',
    category: 'Members',
    action: 'member.status_change',
    adminUid: 'admin-1',
    adminEmail: 'admin@x.com',
    description: 'Set member status to suspended',
    targetId: 'u-1',
    targetLabel: 'alice@x.com',
    before: { status: 'active' },
    after: { status: 'suspended' },
    metadata: {},
    createdAt: '2026-09-01T10:00:00.000Z',
    ...overrides,
  };
}

describe('fetchAuditLog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('calls the audit-log endpoint with no query string when no params are given', async () => {
    apiFetchMock.mockResolvedValue({ ok: true, data: [] });
    await fetchAuditLog();
    expect(apiFetchMock).toHaveBeenCalledWith('/api/admin/audit-log');
  });

  it('builds a query string from category, adminUid, and limit', async () => {
    apiFetchMock.mockResolvedValue({ ok: true, data: [] });
    await fetchAuditLog({ category: 'Sports', adminUid: 'admin-1', limit: 10 });
    expect(apiFetchMock).toHaveBeenCalledWith(
      '/api/admin/audit-log?category=Sports&adminUid=admin-1&limit=10',
    );
  });

  it('maps wire entries to AuditLogEntry, defaulting missing metadata to {}', async () => {
    apiFetchMock.mockResolvedValue({ ok: true, data: [entryView({ metadata: undefined })] });
    const rows = await fetchAuditLog();
    expect(rows).toEqual([entryView({ metadata: {} })]);
  });

  it('throws with the backend error message on failure', async () => {
    apiFetchMock.mockResolvedValue({ ok: false, error: { code: 'INVALID_INPUT', message: 'bad category' } });
    await expect(fetchAuditLog({ category: 'Sports' })).rejects.toThrow('bad category');
  });
});

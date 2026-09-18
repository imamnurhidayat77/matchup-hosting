import { describe, expect, it, vi, beforeEach } from 'vitest';
import { act, renderHook, waitFor } from '@testing-library/react';

const { fetchMembersMock, updateMemberStatusMock, deleteMemberMock } = vi.hoisted(() => ({
  fetchMembersMock: vi.fn(),
  updateMemberStatusMock: vi.fn(),
  deleteMemberMock: vi.fn(),
}));
vi.mock('../services/membersService', () => ({
  fetchMembers: fetchMembersMock,
  updateMemberStatus: updateMemberStatusMock,
  deleteMember: deleteMemberMock,
}));

import { useMembers } from './useMembers';
import type { Member } from '../services/membersService';

function makeMember(overrides: Partial<Member> = {}): Member {
  return {
    id: 'mem1',
    name: 'Alice',
    username: 'alice',
    email: 'alice@example.com',
    role: 'Player',
    status: 'Active',
    sports: [],
    joinedDate: '2026-01-01',
    activitiesJoined: 3,
    activitiesHosted: 0,
    rating: 4.2,
    avatarSeed: 'mem1',
    ...overrides,
  };
}

describe('useMembers', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('loads members on mount', async () => {
    fetchMembersMock.mockResolvedValue([makeMember()]);
    const { result } = renderHook(() => useMembers());
    expect(result.current.loading).toBe(true);

    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.members).toHaveLength(1);
  });

  it('surfaces an error message when the initial load fails', async () => {
    fetchMembersMock.mockRejectedValue(new Error('offline'));
    const { result } = renderHook(() => useMembers());

    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.error).toBe('offline');
  });

  it('optimistically suspends a member and keeps it on API success', async () => {
    fetchMembersMock.mockResolvedValue([makeMember({ id: 'mem1', status: 'Active' })]);
    updateMemberStatusMock.mockResolvedValue(undefined);
    const { result } = renderHook(() => useMembers());
    await waitFor(() => expect(result.current.loading).toBe(false));

    await act(async () => {
      await result.current.handleStatusChange('mem1', 'Suspended');
    });

    expect(result.current.members[0].status).toBe('Suspended');
  });

  it('reverts the optimistic status change by reloading on API failure', async () => {
    fetchMembersMock
      .mockResolvedValueOnce([makeMember({ id: 'mem1', status: 'Active' })])
      .mockResolvedValueOnce([makeMember({ id: 'mem1', status: 'Active' })]);
    updateMemberStatusMock.mockRejectedValue(new Error('denied'));
    const { result } = renderHook(() => useMembers());
    await waitFor(() => expect(result.current.loading).toBe(false));

    await act(async () => {
      await result.current.handleStatusChange('mem1', 'Suspended');
    });

    await waitFor(() => expect(result.current.members[0].status).toBe('Active'));
  });

  it('reverts an optimistic delete by reloading on API failure', async () => {
    fetchMembersMock
      .mockResolvedValueOnce([makeMember({ id: 'mem1' })])
      .mockResolvedValueOnce([makeMember({ id: 'mem1' })]);
    deleteMemberMock.mockRejectedValue(new Error('denied'));
    const { result } = renderHook(() => useMembers());
    await waitFor(() => expect(result.current.loading).toBe(false));

    await act(async () => {
      await result.current.handleDelete('mem1');
    });

    await waitFor(() => expect(result.current.members).toHaveLength(1));
  });
});

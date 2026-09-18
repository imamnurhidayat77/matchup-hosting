import { describe, expect, it, vi, beforeEach } from 'vitest';
import { act, renderHook, waitFor } from '@testing-library/react';

const { fetchActivitiesMock, updateActivityStatusMock, deleteActivityMock } = vi.hoisted(() => ({
  fetchActivitiesMock: vi.fn(),
  updateActivityStatusMock: vi.fn(),
  deleteActivityMock: vi.fn(),
}));
vi.mock('../services/activitiesService', () => ({
  fetchActivities: fetchActivitiesMock,
  updateActivityStatus: updateActivityStatusMock,
  deleteActivity: deleteActivityMock,
}));

import { useActivities } from './useActivities';
import type { AdminActivity } from '../services/activitiesService';

function makeActivity(overrides: Partial<AdminActivity> = {}): AdminActivity {
  return {
    id: 'act1',
    name: 'Sunday Futsal',
    matchId: 'm1',
    sport: 'Futsal',
    skillLevel: 'Beginner',
    host: 'Alice',
    hostAvatarSeed: 'u1',
    hostRating: 4.5,
    hostGamesCount: 10,
    location: 'Auckland',
    scheduledDate: '2026-02-01',
    startTime: '10:00',
    endTime: '11:00',
    durationMinutes: 60,
    participants: 4,
    capacity: 10,
    status: 'Active',
    description: 'Casual game',
    isPaid: false,
    vibeTags: [],
    ...overrides,
  };
}

describe('useActivities', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('loads activities on mount', async () => {
    fetchActivitiesMock.mockResolvedValue([makeActivity()]);
    const { result } = renderHook(() => useActivities());
    expect(result.current.loading).toBe(true);

    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.activities).toHaveLength(1);
    expect(result.current.error).toBeNull();
  });

  it('surfaces an error message when the initial load fails', async () => {
    fetchActivitiesMock.mockRejectedValue(new Error('offline'));
    const { result } = renderHook(() => useActivities());

    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.error).toBe('offline');
    expect(result.current.activities).toEqual([]);
  });

  it('optimistically updates status and keeps it on API success', async () => {
    fetchActivitiesMock.mockResolvedValue([makeActivity({ id: 'act1', status: 'Active' })]);
    updateActivityStatusMock.mockResolvedValue(undefined);
    const { result } = renderHook(() => useActivities());
    await waitFor(() => expect(result.current.loading).toBe(false));

    await act(async () => {
      await result.current.handleStatusChange('act1', 'Cancelled');
    });

    expect(result.current.activities[0].status).toBe('Cancelled');
    expect(updateActivityStatusMock).toHaveBeenCalledWith('act1', 'Cancelled');
  });

  it('reverts the optimistic status change by reloading on API failure', async () => {
    fetchActivitiesMock
      .mockResolvedValueOnce([makeActivity({ id: 'act1', status: 'Active' })])
      .mockResolvedValueOnce([makeActivity({ id: 'act1', status: 'Active' })]);
    updateActivityStatusMock.mockRejectedValue(new Error('denied'));
    const { result } = renderHook(() => useActivities());
    await waitFor(() => expect(result.current.loading).toBe(false));

    await act(async () => {
      await result.current.handleStatusChange('act1', 'Cancelled');
    });

    await waitFor(() => expect(result.current.activities[0].status).toBe('Active'));
    expect(fetchActivitiesMock).toHaveBeenCalledTimes(2);
  });

  it('optimistically removes an activity on delete', async () => {
    fetchActivitiesMock.mockResolvedValue([makeActivity({ id: 'act1' }), makeActivity({ id: 'act2' })]);
    deleteActivityMock.mockResolvedValue(undefined);
    const { result } = renderHook(() => useActivities());
    await waitFor(() => expect(result.current.loading).toBe(false));

    await act(async () => {
      await result.current.handleDelete('act1');
    });

    expect(result.current.activities.map((a) => a.id)).toEqual(['act2']);
  });
});

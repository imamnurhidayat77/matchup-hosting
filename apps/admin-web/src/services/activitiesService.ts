/**
 * Activities service.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in .env.
 *
 * Expected endpoints:
 *   GET   /api/v1/admin/activities                  → AdminActivity[]
 *   PATCH /api/v1/admin/activities/:id/status       → AdminActivity  { status }
 *   DELETE /api/v1/admin/activities/:id             → void
 */
import { apiFetch } from './api';
import { DUMMY_ACTIVITIES } from '../data/activitiesDummy';
import type { AdminActivity, ActivityStatus } from '../data/activitiesDummy';

export type { AdminActivity, ActivityStatus };

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

export async function fetchActivities(): Promise<AdminActivity[]> {
  if (USE_MOCK) return delay(350, DUMMY_ACTIVITIES);
  const res = await apiFetch<AdminActivity[]>('/api/v1/admin/activities');
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

export async function updateActivityStatus(
  id: string,
  status: ActivityStatus,
): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(`/api/v1/admin/activities/${id}/status`, {
    method: 'PATCH',
    body: JSON.stringify({ status }),
  });
  if (!res.ok) throw new Error(res.error.message);
}

export async function deleteActivity(id: string): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(`/api/v1/admin/activities/${id}`, {
    method: 'DELETE',
  });
  if (!res.ok) throw new Error(res.error.message);
}

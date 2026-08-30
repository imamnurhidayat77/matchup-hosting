/**
 * Dashboard service — single source of truth for all dashboard data fetches.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in your .env file.
 *
 * API contract (expected endpoints when real backend is ready):
 *   GET  /api/v1/admin/dashboard                  → DashboardData
 *   GET  /api/v1/admin/moderation                 → ModerationItem[]
 *   POST /api/v1/admin/moderation/:id/resolve { note? } → void
 *   POST /api/v1/admin/moderation/:id/dismiss { note? } → void
 */
import { apiFetch } from './api';
import { DUMMY_DASHBOARD } from '../data/dashboardDummy';
import type { DashboardData, ModerationItem } from '../types/dashboard';

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';

function delay<T>(ms: number, value: T): Promise<T> {
  return new Promise((resolve) => setTimeout(() => resolve(value), ms));
}

export async function fetchDashboard(): Promise<DashboardData> {
  if (USE_MOCK) return delay(400, DUMMY_DASHBOARD);
  const res = await apiFetch<DashboardData>('/api/v1/admin/dashboard');
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

export async function fetchModerationQueue(): Promise<ModerationItem[]> {
  if (USE_MOCK) return delay(300, DUMMY_DASHBOARD.moderationQueue);
  const res = await apiFetch<ModerationItem[]>('/api/v1/admin/moderation');
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

export type ModAction = 'resolve' | 'dismiss';

export async function moderationAction(
  id: string,
  action: ModAction,
  note?: string,
): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(`/api/v1/admin/moderation/${id}/${action}`, {
    method: 'POST',
    body: JSON.stringify({ note }),
  });
  if (!res.ok) throw new Error(res.error.message);
}

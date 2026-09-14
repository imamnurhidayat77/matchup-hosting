/**
 * Sports service — master sports list (admin-managed config).
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in .env (plus an admin Firebase ID token
 *   under `admin_id_token` in localStorage — see reportsService header).
 *
 * Live endpoints (api-server, all admin-gated):
 *   GET   /api/admin/sports      → SportConfig[] (with live activityCount)
 *   PATCH /api/admin/sports/:id  → SportConfig  { enabled?, showInFilter?, showInOnboarding?, canHost? }
 *
 * In live mode the backend is the source of truth; localStorage is only a
 * mock-mode cache. `activityCount` is read-only (computed server-side).
 */
import { apiFetch } from './api';
import {
  DEFAULT_SPORTS,
  loadSports,
  saveSports,
} from '../data/sportsDummy';
import type { SportConfig } from '../data/sportsDummy';

export type { SportConfig };
export { DEFAULT_SPORTS };

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

export async function fetchSports(): Promise<SportConfig[]> {
  if (USE_MOCK) return delay(300, loadSports());
  const res = await apiFetch<SportConfig[]>('/api/admin/sports');
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

export interface SportFlagPatch {
  enabled?: boolean;
  showInFilter?: boolean;
  showInOnboarding?: boolean;
  canHost?: boolean;
}

export async function updateSport(
  id: string,
  patch: SportFlagPatch,
): Promise<SportConfig> {  if (USE_MOCK) {
    const sports = loadSports().map((s) =>
      s.id === id ? { ...s, ...patch } : s,
    );
    saveSports(sports);
    const updated = sports.find((s) => s.id === id);
    if (!updated) throw new Error('Sport not found');
    return delay(200, updated);
  }
  const res = await apiFetch<SportConfig>(
    `/api/admin/sports/${encodeURIComponent(id)}`,
    { method: 'PATCH', body: JSON.stringify(patch) },
  );
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

/**
 * Atomic publish of the whole list (the page's "Publish Changes" flow).
 * In mock mode this is the old localStorage write.
 */
export async function replaceSports(
  sports: SportConfig[],
): Promise<SportConfig[]> {
  if (USE_MOCK) {
    const sorted = [...sports]
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map((s, i) => ({ ...s, sortOrder: i + 1 }));
    saveSports(sorted);
    return delay(300, sorted);
  }
  const res = await apiFetch<SportConfig[]>('/api/admin/sports', {
    method: 'PUT',
    body: JSON.stringify({
      sports: sports.map((s) => ({
        id: s.id,
        name: s.name,
        emoji: s.emoji,
        enabled: s.enabled,
        showInFilter: s.showInFilter,
        showInOnboarding: s.showInOnboarding,
        canHost: s.canHost,
        sortOrder: s.sortOrder,
      })),
    }),
  });
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

/**
 * Reports / moderation service — single admin role, no escalation.
 *
 * HOW TO SWITCH TO REAL API:  Set VITE_USE_MOCK_API=false in .env.
 *
 * Expected endpoints:
 *   GET  /api/v1/admin/reports                      → Report[]
 *   POST /api/v1/admin/reports/:id/resolve  { note? } → void
 *   POST /api/v1/admin/reports/:id/dismiss  { note? } → void
 */
import { apiFetch } from './api';
import { DUMMY_REPORTS } from '../data/reportsDummy';
import type { Report, ReportStatus } from '../data/reportsDummy';

export type { Report, ReportStatus };
export type ReportAction = 'resolve' | 'dismiss';

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

export async function fetchReports(): Promise<Report[]> {
  if (USE_MOCK) return delay(300, DUMMY_REPORTS);
  const res = await apiFetch<Report[]>('/api/v1/admin/reports');
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

export async function reportAction(
  id: string,
  action: ReportAction,
  note?: string,
): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(`/api/v1/admin/reports/${id}/${action}`, {
    method: 'POST',
    body: JSON.stringify({ note }),
  });
  if (!res.ok) throw new Error(res.error.message);
}

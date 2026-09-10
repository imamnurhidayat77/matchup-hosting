/**
 * Reports / moderation service — single admin role, no escalation.
 *
 * HOW TO SWITCH TO REAL API:
 *   1. Set VITE_USE_MOCK_API=false in .env.
 *   2. Store a Firebase ID token of an admin uid (see api-server
 *      ADMIN_UIDS) in localStorage under `admin_id_token`, e.g. from
 *      the browser console after signing in with Firebase:
 *        localStorage.setItem('admin_id_token', '<id-token>')
 *   The token is sent as `Authorization: Bearer …` by apiFetch.
 *
 * Live endpoints (api-server):
 *   GET  /api/reports?status=&limit=             → Report[]
 *   POST /api/reports/:id/resolve  { note? }     → void
 *   POST /api/reports/:id/dismiss  { note? }     → void
 */
import { apiFetch } from './api';
import { DUMMY_REPORTS } from '../data/reportsDummy';
import type { Report, ReportStatus } from '../data/reportsDummy';

export type { Report, ReportStatus };
export type ReportAction = 'resolve' | 'dismiss';

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

export async function fetchReports(
  status?: 'pending' | 'resolved' | 'dismissed',
): Promise<Report[]> {
  if (USE_MOCK) return delay(300, DUMMY_REPORTS);
  const params = status != null ? `?status=${status}` : '';
  const res = await apiFetch<Report[]>(`/api/reports${params}`);
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

export async function reportAction(
  id: string,
  action: ReportAction,
  note?: string,
): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(`/api/reports/${id}/${action}`, {
    method: 'POST',
    body: JSON.stringify({ note }),
  });
  if (!res.ok) throw new Error(res.error.message);
}

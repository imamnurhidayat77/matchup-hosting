/**
 * Reports / moderation service — database-backed (Firestore `reports`).
 *
 * Live endpoints (api-server):
 *   GET  /api/reports?status=&limit=             → Report[]
 *   POST /api/reports/:id/resolve  { note? }     → void
 *   POST /api/reports/:id/dismiss  { note? }     → void
 */
import { apiFetch } from './api';
import type { Report, ReportStatus } from '../types/reports';

export type { Report, ReportStatus };
export type ReportAction = 'resolve' | 'dismiss';

export async function fetchReports(
  status?: 'pending' | 'resolved' | 'dismissed',
): Promise<Report[]> {
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
  const res = await apiFetch<void>(`/api/reports/${id}/${action}`, {
    method: 'POST',
    body: JSON.stringify({ note }),
  });
  if (!res.ok) throw new Error(res.error.message);
}

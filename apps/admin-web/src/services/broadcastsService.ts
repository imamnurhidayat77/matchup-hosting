/**
 * Broadcasts service.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in .env (plus an admin Firebase ID token
 *   under `admin_id_token` in localStorage — see reportsService header).
 *
 * Live endpoints (api-server, all admin-gated):
 *   GET  /api/admin/broadcasts        → BroadcastView[]
 *   POST /api/admin/broadcasts        → BroadcastView  (always draft/scheduled)
 *   PATCH /api/admin/broadcasts/:id   → BroadcastView
 *   DELETE /api/admin/broadcasts/:id  → void  (draft/scheduled only)
 *   POST /api/admin/broadcasts/:id/send → BroadcastView (one-way → sent)
 *
 * Send semantics: the backend creates drafts; sending is an explicit
 * second call. `createBroadcast` without `scheduledAt` therefore creates
 * AND sends (matching the UI's "send immediately" flow).
 */
import { apiFetch } from './api';
import { DUMMY_BROADCASTS } from '../data/broadcastsDummy';
import type {
  Broadcast,
  BroadcastAudience,
  BroadcastStatus,
} from '../data/broadcastsDummy';

export type { Broadcast, BroadcastAudience, BroadcastStatus };

export interface CreateBroadcastPayload {
  title: string;
  message: string;
  audience: BroadcastAudience;
  /** ISO string — when set, schedules for later; otherwise sends immediately. */
  scheduledAt?: string;
}

interface BroadcastView {
  id: string;
  title: string;
  message: string;
  audience: BroadcastAudience;
  status: 'draft' | 'scheduled' | 'sent';
  scheduledAt: string | null;
  sentAt: string | null;
  recipients: number;
  createdBy: string;
  createdAt: string | null;
}

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

function formatSentAt(iso: string | null): string | undefined {
  if (!iso) return undefined;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function toBroadcast(view: BroadcastView): Broadcast {
  const status: BroadcastStatus =
    view.status === 'sent'
      ? 'Sent'
      : view.status === 'scheduled'
        ? 'Scheduled'
        : 'Draft';
  return {
    id: view.id,
    title: view.title,
    message: view.message,
    audience: view.audience,
    status,
    sentAt: formatSentAt(view.sentAt),
    scheduledAt: view.scheduledAt ?? undefined,
    recipients: view.recipients,
  };
}

export async function fetchBroadcasts(): Promise<Broadcast[]> {
  if (USE_MOCK) return delay(300, DUMMY_BROADCASTS);
  const res = await apiFetch<BroadcastView[]>('/api/admin/broadcasts');
  if (!res.ok) throw new Error(res.error.message);
  return res.data.map(toBroadcast);
}

export async function createBroadcast(
  payload: CreateBroadcastPayload,
): Promise<Broadcast> {
  if (USE_MOCK) {
    const mock: Broadcast = {
      id: `b${Date.now()}`,
      title: payload.title,
      message: payload.message,
      audience: payload.audience,
      status: payload.scheduledAt ? 'Scheduled' : 'Sent',
      sentAt: payload.scheduledAt
        ? undefined
        : new Date().toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
          }),
      scheduledAt: payload.scheduledAt,
      recipients: payload.audience === 'All Users' ? 12483 : 2640,
    };
    return delay(400, mock);
  }
  const created = await apiFetch<BroadcastView>('/api/admin/broadcasts', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  if (!created.ok) throw new Error(created.error.message);
  if (payload.scheduledAt) return toBroadcast(created.data);
  // Send immediately: create-then-send keeps one backend code path.
  const sent = await apiFetch<BroadcastView>(
    `/api/admin/broadcasts/${encodeURIComponent(created.data.id)}/send`,
    { method: 'POST' },
  );
  if (!sent.ok) throw new Error(sent.error.message);
  return toBroadcast(sent.data);
}

export async function sendBroadcast(id: string): Promise<Broadcast> {
  if (USE_MOCK) {
    const found = DUMMY_BROADCASTS.find((b) => b.id === id);
    if (!found) throw new Error('Broadcast not found');
    return delay(400, {
      ...found,
      status: 'Sent' as BroadcastStatus,
      sentAt: new Date().toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
      }),
    });
  }
  const res = await apiFetch<BroadcastView>(
    `/api/admin/broadcasts/${encodeURIComponent(id)}/send`,
    { method: 'POST' },
  );
  if (!res.ok) throw new Error(res.error.message);
  return toBroadcast(res.data);
}

export async function deleteBroadcast(id: string): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(
    `/api/admin/broadcasts/${encodeURIComponent(id)}`,
    { method: 'DELETE' },
  );
  if (!res.ok) throw new Error(res.error.message);
}

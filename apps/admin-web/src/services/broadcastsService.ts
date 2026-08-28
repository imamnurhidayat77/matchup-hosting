/**
 * Broadcasts service.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in .env.
 *
 * Expected endpoints:
 *   GET    /api/v1/admin/broadcasts          → Broadcast[]
 *   POST   /api/v1/admin/broadcasts          → Broadcast   (create & send)
 *   PATCH  /api/v1/admin/broadcasts/:id      → Broadcast   (update draft)
 *   DELETE /api/v1/admin/broadcasts/:id      → void
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

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

export async function fetchBroadcasts(): Promise<Broadcast[]> {
  if (USE_MOCK) return delay(300, DUMMY_BROADCASTS);
  const res = await apiFetch<Broadcast[]>('/api/v1/admin/broadcasts');
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
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
  const res = await apiFetch<Broadcast>('/api/v1/admin/broadcasts', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

export async function deleteBroadcast(id: string): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(`/api/v1/admin/broadcasts/${id}`, {
    method: 'DELETE',
  });
  if (!res.ok) throw new Error(res.error.message);
}

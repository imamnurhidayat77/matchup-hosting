/**
 * Activities service — database-backed (Firestore `activities` via api-server).
 *
 * Live endpoints (api-server, all admin-gated):
 *   GET   /api/admin/activities            → AdminActivityView[]
 *   PATCH /api/admin/activities/:id/status → void  { status: 'open' | 'cancelled' | 'completed' | 'removed' }
 *   DELETE /api/admin/activities/:id       → void
 *
 * Status mapping (frontend ⇄ backend):
 *   Active ⇄ open · Cancelled ⇄ cancelled · Completed ⇄ completed
 *   Flagged ⇄ removed (hidden from every feed)
 *   Full is computed live (participants >= capacity), never written.
 */
import { apiFetch } from './api';
import type { AdminActivity, ActivityStatus } from '../types/activities';

export type { AdminActivity, ActivityStatus };

interface AdminActivityView {
  id: string;
  title: string;
  sportType: string;
  locationName: string;
  startTime: string | null;
  status: 'open' | 'full' | 'cancelled' | 'completed' | 'removed';
  capacity: number;
  participantCount: number;
  hostId: string;
  hostDisplayName: string;
  hostPhotoUrl?: string;
  createdAt: string | null;
}

function formatDateTime(iso: string | null): {
  scheduledDate: string;
  startTime: string;
} {
  if (!iso) return { scheduledDate: '', startTime: '' };
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return { scheduledDate: '', startTime: '' };
  return {
    scheduledDate: d.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    }),
    startTime: d.toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
    }),
  };
}

function toAdminActivity(view: AdminActivityView): AdminActivity {
  const { scheduledDate, startTime } = formatDateTime(view.startTime);
  const status: ActivityStatus =
    view.status === 'cancelled'
      ? 'Cancelled'
      : view.status === 'completed'
        ? 'Completed'
        : view.status === 'removed'
          ? 'Flagged'
          : view.participantCount >= view.capacity && view.capacity > 0
            ? 'Full'
            : 'Active';
  return {
    id: view.id,
    name: view.title,
    matchId: view.id.slice(0, 8).toUpperCase(),
    sport: view.sportType,
    skillLevel: 'All Levels',
    host: view.hostDisplayName || view.hostId.slice(0, 8),
    hostAvatarSeed: view.hostId,
    photoUrl: view.hostPhotoUrl,
    hostRating: 0,
    hostGamesCount: 0,
    location: view.locationName,
    scheduledDate,
    startTime,
    endTime: '',
    durationMinutes: 0,
    participants: view.participantCount,
    capacity: view.capacity,
    status,
    description: '',
    isPaid: false,
    vibeTags: [],
  };
}

function toBackendStatus(status: ActivityStatus): string {
  switch (status) {
    case 'Active':
    case 'Full':
      return 'open';
    case 'Cancelled':
      return 'cancelled';
    case 'Completed':
      return 'completed';
    case 'Flagged':
      return 'removed';
  }
}

export async function fetchActivities(): Promise<AdminActivity[]> {
  const res = await apiFetch<AdminActivityView[]>('/api/admin/activities');
  if (!res.ok) throw new Error(res.error.message);
  return res.data.map(toAdminActivity);
}

export async function updateActivityStatus(
  id: string,
  status: ActivityStatus,
): Promise<void> {
  const res = await apiFetch<void>(
    `/api/admin/activities/${encodeURIComponent(id)}/status`,
    {
      method: 'PATCH',
      body: JSON.stringify({ status: toBackendStatus(status) }),
    },
  );
  if (!res.ok) throw new Error(res.error.message);
}

export async function deleteActivity(id: string): Promise<void> {
  const res = await apiFetch<void>(
    `/api/admin/activities/${encodeURIComponent(id)}`,
    { method: 'DELETE' },
  );
  if (!res.ok) throw new Error(res.error.message);
}

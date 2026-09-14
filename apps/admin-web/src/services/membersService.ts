/**
 * Members service.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in .env (plus an admin Firebase ID token
 *   under `admin_id_token` in localStorage — see reportsService header).
 *
 * Live endpoints (api-server, all admin-gated):
 *   GET   /api/admin/members              → AdminMemberView[]
 *   GET   /api/admin/members/:uid         → AdminMemberView
 *   PATCH /api/admin/members/:uid/status  → AdminMemberView  { status: 'active' | 'suspended' }
 *   DELETE /api/admin/members/:uid        → void
 *
 * The backend only knows `active`/`suspended`; the extra display states
 * (`Inactive`, `Pending`) exist in mock data only and never occur live.
 */
import { apiFetch } from './api';
import { DUMMY_MEMBERS } from '../data/membersDummy';
import type { Member, MemberStatus } from '../data/membersDummy';

export type { Member, MemberStatus };

interface AdminMemberView {
  uid: string;
  email: string;
  displayName?: string;
  photoUrl?: string;
  status: 'active' | 'suspended';
  createdAt: string | null;
  activitiesCount?: number;
  hostedCount?: number;
}

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

function toMember(view: AdminMemberView): Member {
  const name =
    view.displayName && view.displayName.trim().length > 0
      ? view.displayName
      : view.email.split('@')[0] ?? view.uid;
  return {
    id: view.uid,
    name,
    username: `@${view.uid.slice(0, 8)}`,
    email: view.email,
    role: 'Player',
    status: view.status === 'suspended' ? 'Suspended' : 'Active',
    sports: [],
    joinedDate: view.createdAt ?? '',
    activitiesJoined: view.activitiesCount ?? 0,
    activitiesHosted: view.hostedCount ?? 0,
    rating: 0,
    avatarSeed: view.uid,
  };
}

export async function fetchMembers(): Promise<Member[]> {
  if (USE_MOCK) return delay(350, DUMMY_MEMBERS);
  const res = await apiFetch<AdminMemberView[]>('/api/admin/members');
  if (!res.ok) throw new Error(res.error.message);
  return res.data.map(toMember);
}

export async function fetchMember(id: string): Promise<Member> {
  if (USE_MOCK) {
    const found = DUMMY_MEMBERS.find((m) => m.id === id);
    if (!found) throw new Error('Member not found');
    return delay(300, found);
  }
  const res = await apiFetch<AdminMemberView>(
    `/api/admin/members/${encodeURIComponent(id)}`,
  );
  if (!res.ok) throw new Error(res.error.message);
  return toMember(res.data);
}

function toBackendStatus(status: MemberStatus): 'active' | 'suspended' {
  if (status === 'Suspended') return 'suspended';
  if (status === 'Active') return 'active';
  // Inactive/Pending are mock-only states with no backend equivalent.
  throw new Error(`Status "${status}" is not supported by the live API`);
}

export async function updateMemberStatus(
  id: string,
  status: MemberStatus,
): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(
    `/api/admin/members/${encodeURIComponent(id)}/status`,
    {
      method: 'PATCH',
      body: JSON.stringify({ status: toBackendStatus(status) }),
    },
  );
  if (!res.ok) throw new Error(res.error.message);
}

export async function deleteMember(id: string): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(
    `/api/admin/members/${encodeURIComponent(id)}`,
    { method: 'DELETE' },
  );
  if (!res.ok) throw new Error(res.error.message);
}

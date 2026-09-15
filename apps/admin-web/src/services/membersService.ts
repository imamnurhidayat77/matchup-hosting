/**
 * Members service — database-backed (Firestore `users` via api-server).
 *
 * Live endpoints (api-server, all admin-gated):
 *   GET   /api/admin/members              → AdminMemberView[]
 *   GET   /api/admin/members/:uid         → AdminMemberView
 *   PATCH /api/admin/members/:uid/status  → AdminMemberView  { status: 'active' | 'suspended' }
 *   DELETE /api/admin/members/:uid        → void
 */
import { apiFetch } from './api';
import type { Member, MemberStatus } from '../types/members';

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

function toMember(view: AdminMemberView): Member {
  const name =
    view.displayName && view.displayName.trim().length > 0
      ? view.displayName
      : (view.email.split('@')[0] ?? view.uid);
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
    photoUrl: view.photoUrl,
  };
}

export async function fetchMembers(): Promise<Member[]> {
  const res = await apiFetch<AdminMemberView[]>('/api/admin/members');
  if (!res.ok) throw new Error(res.error.message);
  return res.data.map(toMember);
}

export async function fetchMember(id: string): Promise<Member> {
  const res = await apiFetch<AdminMemberView>(
    `/api/admin/members/${encodeURIComponent(id)}`,
  );
  if (!res.ok) throw new Error(res.error.message);
  return toMember(res.data);
}

function toBackendStatus(status: MemberStatus): 'active' | 'suspended' {
  return status === 'Suspended' ? 'suspended' : 'active';
}

export async function updateMemberStatus(
  id: string,
  status: MemberStatus,
): Promise<void> {
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
  const res = await apiFetch<void>(
    `/api/admin/members/${encodeURIComponent(id)}`,
    { method: 'DELETE' },
  );
  if (!res.ok) throw new Error(res.error.message);
}

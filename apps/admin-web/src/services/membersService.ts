/**
 * Members service.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in .env — no other changes needed.
 *
 * Expected endpoints:
 *   GET  /api/v1/admin/members              → Member[]
 *   GET  /api/v1/admin/members/:id          → Member
 *   PATCH /api/v1/admin/members/:id/status  → Member  { status }
 *   DELETE /api/v1/admin/members/:id        → void
 */
import { apiFetch } from './api';
import { DUMMY_MEMBERS } from '../data/membersDummy';
import type { Member, MemberStatus } from '../data/membersDummy';

export type { Member, MemberStatus };

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

export async function fetchMembers(): Promise<Member[]> {
  if (USE_MOCK) return delay(350, DUMMY_MEMBERS);
  const res = await apiFetch<Member[]>('/api/v1/admin/members');
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

export async function updateMemberStatus(
  id: string,
  status: MemberStatus,
): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(`/api/v1/admin/members/${id}/status`, {
    method: 'PATCH',
    body: JSON.stringify({ status }),
  });
  if (!res.ok) throw new Error(res.error.message);
}

export async function deleteMember(id: string): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  const res = await apiFetch<void>(`/api/v1/admin/members/${id}`, {
    method: 'DELETE',
  });
  if (!res.ok) throw new Error(res.error.message);
}

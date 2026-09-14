/**
 * Appeals service — user recourse against moderation actions.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in .env (plus an admin Firebase ID token
 *   under `admin_id_token` in localStorage — see reportsService header).
 *
 * Live endpoints (api-server):
 *   GET  /api/admin/appeals?status=pending|approved|rejected → Appeal[]
 *   POST /api/admin/appeals/:id/approve { note? }            → Appeal
 *   POST /api/admin/appeals/:id/reject  { note? }            → Appeal
 *
 * Type mapping (frontend ⇄ backend):
 *   Suspension ⇄ suspension · Activity Removal ⇄ activity_removal
 *   Account Ban ⇄ account_ban · Content Removal ⇄ content_removal
 * Approving a Suspension/Account Ban appeal reactivates the account;
 * approving Activity Removal reopens the activity when still removed.
 */
import { apiFetch } from './api';
import { DUMMY_APPEALS } from '../data/appealsDummy';
import type {
  Appeal,
  AppealStatus,
  AppealType,
} from '../data/appealsDummy';

export type { Appeal, AppealStatus, AppealType };

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

const TO_BACKEND: Record<AppealType, string> = {
  Suspension: 'suspension',
  'Activity Removal': 'activity_removal',
  'Account Ban': 'account_ban',
  'Content Removal': 'content_removal',
};

const FROM_BACKEND: Record<string, AppealType> = {
  suspension: 'Suspension',
  activity_removal: 'Activity Removal',
  account_ban: 'Account Ban',
  content_removal: 'Content Removal',
};

const FROM_STATUS: Record<string, AppealStatus> = {
  pending: 'Pending',
  approved: 'Approved',
  rejected: 'Rejected',
};

interface AppealView {
  id: string;
  appellantUid: string;
  userName: string;
  userEmail: string;
  type: string;
  originalAction: string;
  statement: string;
  relatedId: string | null;
  status: string;
  adminNote: string | null;
  createdAt: string | null;
  decidedAt: string | null;
  decidedBy: string | null;
}

function toAppeal(view: AppealView): Appeal {
  return {
    id: view.id,
    userId: view.appellantUid,
    userName: view.userName,
    userAvatarSeed: view.appellantUid,
    userEmail: view.userEmail,
    type: FROM_BACKEND[view.type] ?? 'Suspension',
    originalAction: view.originalAction,
    statement: view.statement,
    status: FROM_STATUS[view.status] ?? 'Pending',
    createdAt: view.createdAt ?? '',
    resolvedAt: view.decidedAt ?? undefined,
    adminResponse: view.adminNote ?? undefined,
    relatedId: view.relatedId ?? undefined,
  };
}

export async function fetchAppeals(
  status: AppealStatus = 'Pending',
): Promise<Appeal[]> {
  if (USE_MOCK) {
    return delay(
      300,
      DUMMY_APPEALS.filter((a) => a.status === status),
    );
  }
  const backendStatus =
    status === 'Approved'
      ? 'approved'
      : status === 'Rejected'
        ? 'rejected'
        : 'pending';
  const res = await apiFetch<AppealView[]>(
    `/api/admin/appeals?status=${backendStatus}`,
  );
  if (!res.ok) throw new Error(res.error.message);
  return res.data.map(toAppeal);
}

export type AppealDecision = 'approve' | 'reject';

export async function decideAppeal(
  id: string,
  decision: AppealDecision,
  response: string,
): Promise<Appeal> {
  if (USE_MOCK) {
    const found = DUMMY_APPEALS.find((a) => a.id === id);
    if (!found) throw new Error('Appeal not found');
    return delay(300, {
      ...found,
      status: (decision === 'approve' ? 'Approved' : 'Rejected') as AppealStatus,
      adminResponse: response,
      resolvedAt: new Date().toISOString(),
    });
  }
  const action = decision === 'approve' ? 'approve' : 'reject';
  const res = await apiFetch<AppealView>(
    `/api/admin/appeals/${encodeURIComponent(id)}/${action}`,
    { method: 'POST', body: JSON.stringify({ note: response }) },
  );
  if (!res.ok) throw new Error(res.error.message);
  return toAppeal(res.data);
}

export { TO_BACKEND };

/**
 * Notification-templates service.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in .env (plus an admin Firebase ID token
 *   under `admin_id_token` in localStorage — see reportsService header).
 *
 * Live endpoints (api-server, all admin-gated):
 *   GET   /api/admin/templates      → NotifTemplate[]
 *   PATCH /api/admin/templates/:id  → NotifTemplate  { title?, body?, enabled? }
 *
 * NOTE: templates are data-only for now — senders still hardcode their
 * copy, so editing here changes no live behaviour yet.
 */
import { apiFetch } from './api';
import { DUMMY_NOTIF_TEMPLATES } from '../data/notifTemplatesDummy';
import type { NotifTemplate } from '../data/notifTemplatesDummy';

export type { NotifTemplate };

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

export async function fetchTemplates(): Promise<NotifTemplate[]> {
  if (USE_MOCK) return delay(300, DUMMY_NOTIF_TEMPLATES);
  const res = await apiFetch<NotifTemplate[]>('/api/admin/templates');
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

export interface TemplatePatch {
  title?: string;
  body?: string;
  enabled?: boolean;
}

export async function updateTemplate(
  id: string,
  patch: TemplatePatch,
): Promise<NotifTemplate> {
  if (USE_MOCK) {
    const found = DUMMY_NOTIF_TEMPLATES.find((t) => t.id === id);
    if (!found) throw new Error('Template not found');
    return delay(
      200,
      { ...found, ...patch, lastEditedAt: new Date().toISOString() },
    );
  }
  const res = await apiFetch<NotifTemplate>(
    `/api/admin/templates/${encodeURIComponent(id)}`,
    { method: 'PATCH', body: JSON.stringify(patch) },
  );
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

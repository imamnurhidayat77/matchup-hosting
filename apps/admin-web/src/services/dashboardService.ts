/**
 * Dashboard service — single source of truth for all dashboard data fetches.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in your .env file (and store an admin
 *   Firebase ID token under `admin_id_token` in localStorage — see
 *   reportsService header).
 *
 * API contract (all admin-gated):
 *   GET  /api/admin/dashboard                  → DashboardView (headline numbers)
 *   GET  /api/admin/analytics?range=7d         → trend series
 *   GET  /api/admin/activities                 → activities table (first 8)
 *   Moderation queue → live reports triage board (same as ReportsPage):
 *   GET  /api/reports?status=pending              → ModerationItem[]
 *   POST /api/reports/:id/resolve { note? }       → void
 *   POST /api/reports/:id/dismiss { note? }       → void
 */
import { fetchReports, reportAction } from './reportsService';
import { fetchAnalytics } from './analyticsService';
import { fetchActivities } from './activitiesService';
import { DUMMY_DASHBOARD } from '../data/dashboardDummy';
import type {
  ActivityRow,
  DashboardData,
  KpiData,
  ModerationItem,
} from '../types/dashboard';

interface DashboardView {
  totalUsers: number;
  activeActivities: number;
  pendingReports: number;
  newUsersWeek: number;
  topSports: { sport: string; activities: number; pct: number }[];
}

import { apiFetch } from './api';

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';

function delay<T>(ms: number, value: T): Promise<T> {
  return new Promise((resolve) => setTimeout(() => resolve(value), ms));
}

function kpi(
  title: string,
  rawValue: number,
  sparkColor: string,
): KpiData {
  return {
    title,
    value: rawValue.toLocaleString('en-US'),
    rawValue,
    change: '',
    dir: 'up',
    sparkBars: [rawValue],
    sparkColor,
  };
}

export async function fetchDashboard(): Promise<DashboardData> {
  if (USE_MOCK) return delay(400, DUMMY_DASHBOARD);
  const [stats, analytics, activities, moderationQueue] = await Promise.all([
    apiFetch<DashboardView>('/api/admin/dashboard').then((res) => {
      if (!res.ok) throw new Error(res.error.message);
      return res.data;
    }),
    fetchAnalytics('7d'),
    fetchActivities(),
    fetchModerationQueue(),
  ]);
  return {
    kpis: [
      kpi('Total Users', stats.totalUsers, '#0b1f8a'),
      kpi('Active Activities', stats.activeActivities, '#16a34a'),
      kpi('Pending Reports', stats.pendingReports, '#dc2626'),
      kpi('New Users (7d)', stats.newUsersWeek, '#7c3aed'),
    ],
    trend: analytics.weekly.map((w) => ({
      day: w.day,
      activities: w.activities,
      signups: w.signups,
    })),
    moderationQueue,
    activities: activities.slice(0, 8).map(
      (a): ActivityRow => ({
        id: a.id,
        name: a.name,
        matchId: a.matchId,
        sport: a.sport,
        host: a.host,
        hostAvatarSeed: a.hostAvatarSeed,
        participants: a.participants,
        capacity: a.capacity,
        // MatchStatus has no Cancelled — a cancelled activity no longer
        // circulates, so it surfaces as Flagged (needs-attention).
        status:
          a.status === 'Active' || a.status === 'Full' || a.status === 'Completed'
            ? a.status
            : 'Flagged',
        scheduledDate: a.scheduledDate,
      }),
    ),
  };
}

export async function fetchModerationQueue(): Promise<ModerationItem[]> {
  if (USE_MOCK) return delay(300, DUMMY_DASHBOARD.moderationQueue);
  // Live: the moderation queue is the pending-reports triage board.
  const pending = await fetchReports('pending');
  return pending.map((r) => ({
    id: r.id,
    reporter: r.reporter,
    target: r.target,
    targetType: r.targetType,
    reason: r.reason,
    activityTitle: r.activityTitle,
    sport: r.sport,
    createdAt: r.createdAt,
  }));
}

export type ModAction = 'resolve' | 'dismiss';

export async function moderationAction(
  id: string,
  action: ModAction,
  note?: string,
): Promise<void> {
  if (USE_MOCK) return delay(200, undefined);
  return reportAction(id, action, note);
}

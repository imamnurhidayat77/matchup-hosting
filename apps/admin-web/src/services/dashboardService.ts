/**
 * Dashboard service — database-backed (Firestore aggregates + reports + activities).
 *
 * API contract (all admin-gated):
 *   GET  /api/admin/dashboard                  → DashboardView (headline numbers)
 *   GET  /api/admin/analytics?range=7d         → trend series
 *   GET  /api/admin/activities                 → activities table (first 8)
 *   GET  /api/reports?status=pending           → moderation queue
 *   POST /api/reports/:id/resolve { note? }    → void
 *   POST /api/reports/:id/dismiss { note? }    → void
 */
import { fetchReports, reportAction } from './reportsService';
import { fetchAnalytics } from './analyticsService';
import { fetchActivities } from './activitiesService';
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
        photoUrl: a.photoUrl,
        participants: a.participants,
        capacity: a.capacity,
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
  return reportAction(id, action, note);
}

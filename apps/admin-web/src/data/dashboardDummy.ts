/**
 * Dummy data for the admin dashboard.
 *
 * This file is the ONLY place hardcoded values live. When the API is ready,
 * replace the service layer in `services/dashboardService.ts` — this file
 * stays for offline dev / tests.
 */
import type { DashboardData } from '../types/dashboard';

export const DUMMY_DASHBOARD: DashboardData = {
  // ── KPI cards ────────────────────────────────────────────────────────────
  kpis: [
    {
      title: 'Active Match Seekers',
      value: '12,483',
      rawValue: 12483,
      change: '↑ 18.2%',
      dir: 'up',
      sparkBars: [10, 15, 8, 20, 24, 28, 30, 26, 32, 40],
      sparkColor: '#3b9ec2',
    },
    {
      title: 'Total Sports Activities',
      value: '1,842',
      rawValue: 1842,
      change: '↑ 12.4%',
      dir: 'up',
      sparkBars: [8, 12, 16, 14, 20, 18, 22, 28, 30, 35],
      sparkColor: '#3b9ec2',
    },
    {
      title: 'Pending Reports',
      value: '14',
      rawValue: 14,
      change: '↓ 4.1%',
      dir: 'down',
      sparkBars: [32, 30, 28, 25, 22, 18, 16, 15, 14, 12],
      sparkColor: '#ef4444',
    },
    {
      title: 'Active Broadcasts',
      value: '8',
      rawValue: 8,
      change: '↑ 2.5%',
      dir: 'up',
      sparkBars: [4, 5, 3, 6, 8, 7, 9, 8, 10, 12],
      sparkColor: '#3b9ec2',
    },
  ],

  // ── Trend chart ──────────────────────────────────────────────────────────
  trend: [
    { day: 'Mon', activities: 30, signups: 45 },
    { day: 'Tue', activities: 35, signups: 80 },
    { day: 'Wed', activities: 80, signups: 95 },
    { day: 'Thu', activities: 85, signups: 130 },
    { day: 'Fri', activities: 145, signups: 150 },
    { day: 'Sat', activities: 125, signups: 175 },
    { day: 'Sun', activities: 155, signups: 200 },
  ],

  // ── Moderation queue ─────────────────────────────────────────────────────
  moderationQueue: [
    {
      id: 'mod-1',
      reporter: 'Kevin D.',
      target: 'Marcus L.',
      targetType: 'user' as const,
      reason: 'Discriminatory title & bio chat',
      activityTitle: 'Sunday Pick-Up Elite',
      sport: 'Basketball',
      createdAt: '2026-10-24T14:23:00Z',
    },
    {
      id: 'mod-2',
      reporter: 'Sarah P.',
      target: 'Coach Dave',
      targetType: 'user' as const,
      reason: 'Charged money offline (policy breach)',
      activityTitle: 'Indoor Badminton Rally',
      sport: 'Badminton',
      createdAt: '2026-10-24T11:05:00Z',
    },
    {
      id: 'mod-3',
      reporter: 'Ali M.',
      target: 'Jordan T.',
      targetType: 'user' as const,
      reason: 'No-show host — cancelled last minute',
      activityTitle: 'Morning Beach Volleyball',
      sport: 'Volleyball',
      createdAt: '2026-10-23T09:45:00Z',
    },
  ],

  // ── Activities table ─────────────────────────────────────────────────────
  activities: [
    {
      id: 'act-1',
      name: 'Wednesday Night Futsal Cup',
      matchId: 'MU-1082',
      sport: 'Futsal',
      host: 'Nolan Vance',
      hostAvatarSeed: 'nolan',
      participants: 10,
      capacity: 10,
      status: 'Full',
      scheduledDate: 'Oct 25, 2026',
    },
    {
      id: 'act-2',
      name: 'Saturdays 5v5 Half-Court Run',
      matchId: 'MU-1156',
      sport: 'Basketball',
      host: 'Marcus Brody',
      hostAvatarSeed: 'marcus',
      participants: 12,
      capacity: 15,
      status: 'Active',
      scheduledDate: 'Oct 28, 2026',
    },
    {
      id: 'act-3',
      name: 'Morning Cardio & Running Club',
      matchId: 'MU-1193',
      sport: 'Running',
      host: 'Julia Kent',
      hostAvatarSeed: 'julia',
      participants: 28,
      capacity: 50,
      status: 'Active',
      scheduledDate: 'Oct 29, 2026',
    },
    {
      id: 'act-4',
      name: 'Elite Smash Court Badminton',
      matchId: 'MU-1119',
      sport: 'Badminton',
      host: 'Hana Shiro',
      hostAvatarSeed: 'hana',
      participants: 8,
      capacity: 8,
      status: 'Completed',
      scheduledDate: 'Oct 22, 2026',
    },
    {
      id: 'act-5',
      name: 'Coastal Highway Group Ride',
      matchId: 'MU-1082',
      sport: 'Cycling',
      host: 'Gavin Reed',
      hostAvatarSeed: 'gavin',
      participants: 14,
      capacity: 20,
      status: 'Flagged',
      scheduledDate: 'Oct 31, 2026',
    },
  ],
};

/**
 * Analytics service.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in .env (plus an admin Firebase ID token
 *   under `admin_id_token` in localStorage — see reportsService header).
 *
 * Live endpoint (api-server, admin-gated):
 *   GET /api/admin/analytics?range=7d|30d|90d → AnalyticsData
 * Live series are daily buckets over the window; retention/health cards
 * have no backing events yet and arrive as empty series.
 */
import { apiFetch } from './api';

export interface WeeklyPoint {
  day: string;
  signups: number;
  activities: number;
  reports: number;
}

export interface SportStat {
  sport: string;
  activities: number;
  pct: number;
}

export interface RetentionPoint {
  label: string;
  value: number;
}

export interface HealthMetric {
  label: string;
  value: number;
  color: string;
}

export interface AnalyticsKpi {
  label: string;
  value: string;
  change: string;
}

export interface AnalyticsData {
  kpis: AnalyticsKpi[];
  weekly: WeeklyPoint[];
  topSports: SportStat[];
  retention: RetentionPoint[];
  health: HealthMetric[];
}

// ─── Dummy data (inline — analytics doesn't have its own dummy file) ──────────

const DUMMY: AnalyticsData = {
  kpis: [
    { label: 'Total Users',        value: '12,483', change: '+18.2%' },
    { label: 'Weekly Signups',     value: '454',    change: '+12.4%' },
    { label: 'Activities Created', value: '391',    change: '+9.7%'  },
    { label: 'Avg. Session Time',  value: '8m 32s', change: '+3.1%'  },
  ],
  weekly: [
    { day: 'Mon', signups: 38, activities: 22, reports: 3 },
    { day: 'Tue', signups: 52, activities: 35, reports: 5 },
    { day: 'Wed', signups: 47, activities: 41, reports: 2 },
    { day: 'Thu', signups: 61, activities: 55, reports: 7 },
    { day: 'Fri', signups: 73, activities: 68, reports: 4 },
    { day: 'Sat', signups: 88, activities: 80, reports: 6 },
    { day: 'Sun', signups: 95, activities: 90, reports: 3 },
  ],
  topSports: [
    { sport: 'Basketball', activities: 342, pct: 88 },
    { sport: 'Futsal',     activities: 278, pct: 72 },
    { sport: 'Badminton',  activities: 231, pct: 60 },
    { sport: 'Running',    activities: 197, pct: 51 },
    { sport: 'Cycling',    activities: 148, pct: 38 },
    { sport: 'Tennis',     activities: 112, pct: 29 },
    { sport: 'Volleyball', activities:  98, pct: 25 },
  ],
  retention: [
    { label: 'Week 1',  value: 100 },
    { label: 'Week 2',  value: 72  },
    { label: 'Week 3',  value: 58  },
    { label: 'Week 4',  value: 47  },
    { label: 'Month 2', value: 39  },
    { label: 'Month 3', value: 34  },
  ],
  health: [
    { label: 'Match Success Rate',  value: 84, color: '#0b1f8a' },
    { label: 'Host Satisfaction',   value: 91, color: '#22c55e' },
    { label: 'Report Resolution',   value: 77, color: '#f59e0b' },
    { label: 'User Retention (M1)', value: 72, color: '#ff6b00' },
  ],
};

export type AnalyticsRange = '7d' | '30d' | '90d';

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';
const delay = <T,>(ms: number, v: T): Promise<T> =>
  new Promise((r) => setTimeout(() => r(v), ms));

export async function fetchAnalytics(
  range: AnalyticsRange = '7d',
): Promise<AnalyticsData> {
  if (USE_MOCK) return delay(400, DUMMY);
  const res = await apiFetch<AnalyticsData>(
    `/api/admin/analytics?range=${range}`,
  );
  if (!res.ok) throw new Error(res.error.message);
  return res.data;
}

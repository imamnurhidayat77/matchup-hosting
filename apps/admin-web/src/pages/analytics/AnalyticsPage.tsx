import { useAnalytics } from '../../hooks/useAnalytics';
import { AnalyticsPageSkeleton, PageError } from '../../components/ui/PageStates';
import type { AnalyticsRange } from '../../services/analyticsService';

// ─── SVG line chart ───────────────────────────────────────────────────────────

function LineChart({ data, keys, colors }: { data: Array<Record<string, number | string>>; keys: string[]; colors: string[] }) {
  const H = 180;
  const pad = { top: 10, bottom: 24, left: 4, right: 4 };
  const W = 600;
  const chartH = H - pad.top - pad.bottom;
  const n = data.length;
  const xOf = (i: number) => pad.left + (i / (n - 1)) * (W - pad.left - pad.right);

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full" preserveAspectRatio="none" aria-label="Analytics chart">
      {[0, 0.25, 0.5, 0.75, 1].map((t) => {
        const y = pad.top + chartH * (1 - t);
        return <line key={t} x1={pad.left} y1={y} x2={W - pad.right} y2={y} stroke="#e2e8f0" strokeWidth="1" />;
      })}
      {keys.map((key, ki) => {
        const vals = data.map((d) => Number(d[key]));
        const max = Math.max(...vals);
        const yOf = (v: number) => pad.top + chartH - (v / max) * chartH;
        const pts = data.map((_, i) => `${xOf(i)},${yOf(vals[i])}`).join(' ');
        return (
          <g key={key}>
            <polyline points={pts} fill="none" stroke={colors[ki]} strokeWidth="2.5" strokeLinejoin="round" strokeLinecap="round" />
            {data.map((_, i) => (
              <circle key={i} cx={xOf(i)} cy={yOf(vals[i])} r="3.5" fill="#fff" stroke={colors[ki]} strokeWidth="2" />
            ))}
          </g>
        );
      })}
      {data.map((d, i) => (
        <text key={i} x={xOf(i)} y={H - 4} textAnchor="middle" fill="#94a3b8" fontSize="11" fontFamily="Figtree, sans-serif">
          {d.day as string}
        </text>
      ))}
    </svg>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export function AnalyticsPage() {
  const { loading, error, data, range, setRange, reload } = useAnalytics();

  if (loading) return <AnalyticsPageSkeleton />;
  if (error) return <PageError message={error} onRetry={reload} />;
  if (!data) return null;

  const RANGE_OPTIONS: { value: AnalyticsRange; label: string }[] = [
    { value: '7d',  label: 'Last 7 days' },
    { value: '30d', label: 'Last 30 days' },
    { value: '90d', label: 'Last 90 days' },
  ];

  return (
    <div className="page-container space-y-5">

      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-ink-900 sm:text-2xl">Analytics</h1>
          <p className="mt-1 text-xs text-ink-600 sm:text-sm">Platform performance metrics, growth trends, and user engagement</p>
        </div>
        <div className="flex gap-2">
          <select
            value={range}
            onChange={(e) => setRange(e.target.value as AnalyticsRange)}
            className="input w-auto rounded-lg py-1.5 text-sm"
          >
            {RANGE_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
          <button className="btn-outline rounded-lg px-3 py-1.5 text-sm">Export</button>
        </div>
      </div>

      {/* KPI row */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {data.kpis.map((k) => (
          <div key={k.label} className="card py-4">
            <p className="text-xs font-medium text-ink-500">{k.label}</p>
            <p className="mt-1.5 text-2xl font-bold text-ink-900">{k.value}</p>
            <span className="mt-1 text-xs font-semibold text-brand-400">{k.change}</span>
            <span className="text-xs text-ink-400"> vs last week</span>
          </div>
        ))}
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1fr_320px]">
        {/* Weekly line chart */}
        <div className="panel p-5">
          <div className="mb-4 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="text-base font-semibold text-ink-900">Weekly Engagement</h2>
              <p className="text-xs text-ink-600">Signups and activities by day</p>
            </div>
            <div className="flex flex-wrap gap-3">
              {[{ label: 'Signups', color: '#1e6b9a' }, { label: 'Activities', color: '#3b9ec2' }, { label: 'Reports', color: '#ef4444' }].map((l) => (
                <span key={l.label} className="flex items-center gap-1.5 text-xs text-ink-600">
                  <span className="inline-block h-2 w-2 rounded-full" style={{ backgroundColor: l.color }} />
                  {l.label}
                </span>
              ))}
            </div>
          </div>
          <LineChart data={data.weekly.map(p => ({ day: p.day, signups: p.signups, activities: p.activities, reports: p.reports }))} keys={['signups', 'activities', 'reports']} colors={['#1e6b9a', '#3b9ec2', '#ef4444']} />
        </div>

        {/* Top sports */}
        <div className="panel p-5">
          <h2 className="mb-4 text-base font-semibold text-ink-900">Top Sports</h2>
          <div className="space-y-3">
            {data.topSports.map((s, i) => (
              <div key={s.sport}>
                <div className="mb-1 flex items-center justify-between text-xs">
                  <span className="flex items-center gap-2">
                    <span className="w-4 text-ink-400">{i + 1}.</span>
                    <span className="font-semibold text-ink-800">{s.sport}</span>
                  </span>
                  <span className="text-ink-500">{s.activities} activities</span>
                </div>
                <div className="h-2 w-full overflow-hidden rounded-full bg-ink-100">
                  <div className="h-full rounded-full bg-brand-400" style={{ width: `${s.pct}%` }} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Bottom row */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        {/* Retention */}
        <div className="panel p-5">
          <h2 className="mb-1 text-base font-semibold text-ink-900">User Retention</h2>
          <p className="mb-4 text-xs text-ink-600">% of new users still active</p>
          <div className="flex items-end justify-between gap-1.5 h-28">
            {data.retention.map((r) => (
              <div key={r.label} className="flex flex-1 flex-col items-center gap-1">
                <span className="text-[10px] font-semibold text-ink-600">{r.value}%</span>
                <div className="w-full rounded-t-md bg-brand-400" style={{ height: `${r.value}%` }} />
                <span className="text-[9px] text-ink-400 text-center leading-tight">{r.label}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Platform health */}
        <div className="panel p-5">
          <h2 className="mb-4 text-base font-semibold text-ink-900">Platform Health</h2>
          <div className="space-y-3">
            {data.health.map((h) => (
              <div key={h.label}>
                <div className="mb-1 flex justify-between text-xs">
                  <span className="font-medium text-ink-700">{h.label}</span>
                  <span className="font-bold text-ink-900">{h.value}%</span>
                </div>
                <div className="h-2 w-full overflow-hidden rounded-full bg-ink-100">
                  <div className="h-full rounded-full" style={{ width: `${h.value}%`, backgroundColor: h.color }} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

import { useNavigate, useParams } from 'react-router-dom';
import { DUMMY_ACTIVITIES } from '../../data/activitiesDummy';
import type { ActivityStatus } from '../../data/activitiesDummy';

function StatusBadge({ status }: { status: ActivityStatus }) {
  const map: Record<ActivityStatus, string> = {
    Active:    'bg-brand-50  text-brand-700  border-brand-200',
    Full:      'bg-warning-100 text-warning-700 border-warning-200',
    Completed: 'bg-ink-100   text-ink-600    border-ink-200',
    Cancelled: 'bg-danger-50 text-danger-700 border-danger-200',
    Flagged:   'bg-danger-50 text-danger-700 border-danger-200',
  };
  return (
    <span className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold ${map[status]}`}>
      {status}
    </span>
  );
}

function MetaItem({ icon, primary, secondary }: {
  icon: React.ReactNode; primary: string; secondary?: string;
}) {
  return (
    <div className="flex items-start gap-2.5">
      <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-ink-100 text-ink-500">
        {icon}
      </div>
      <div>
        <p className="text-sm font-semibold text-ink-900 leading-tight">{primary}</p>
        {secondary && <p className="text-xs text-ink-400 mt-0.5">{secondary}</p>}
      </div>
    </div>
  );
}

export function ActivityDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const activity = DUMMY_ACTIVITIES.find((a) => a.id === id);

  if (!activity) {
    return (
      <div className="page-container flex flex-col items-center justify-center gap-3 py-24">
        <p className="text-sm text-ink-500">Activity not found.</p>
        <button onClick={() => navigate('/activities')} className="btn-outline rounded-lg px-4 py-2 text-sm">
          Back to Activities
        </button>
      </div>
    );
  }

  const pct = Math.min((activity.participants / activity.capacity) * 100, 100);
  const isFull = pct >= 100;

  return (
    <div className="page-container space-y-4">

      {/* Back */}
      <button onClick={() => navigate('/activities')} className="flex items-center gap-1.5 text-xs text-ink-400 hover:text-ink-700 transition-colors">
        <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M8.5 2.5L4 7l4.5 4.5" /></svg>
        Activities
      </button>

      {/* ── Main layout: hero left, details right ──────────────────── */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1fr_340px]">

        {/* LEFT column */}
        <div className="space-y-4">

          {/* Hero card */}
          <div className="overflow-hidden rounded-2xl border border-ink-200 bg-white shadow-card">
            {/* Cover */}
            <div className="h-[120px] bg-gradient-to-r from-brand-600 to-brand-400 flex items-end px-5 pb-4">
              <div className="flex flex-wrap gap-1.5">
                <span className="rounded-full bg-white/20 border border-white/30 px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide text-white">{activity.sport}</span>
                <span className="rounded-full bg-white/20 border border-white/30 px-2.5 py-0.5 text-[11px] font-bold text-white">⚡ {activity.skillLevel}</span>
              </div>
            </div>

            {/* Title row */}
            <div className="flex items-start justify-between gap-3 px-5 pt-4 pb-3">
              <div>
                <h1 className="text-xl font-bold text-ink-900 leading-tight">{activity.name}</h1>
                <p className="mt-0.5 text-xs font-mono text-ink-400">{activity.matchId}</p>
              </div>
              <StatusBadge status={activity.status} />
            </div>

            {/* Stats inline row */}
            <div className="grid grid-cols-4 divide-x divide-ink-100 border-t border-ink-100">
              {[
                { label: 'Participants', value: `${activity.participants}/${activity.capacity}` },
                { label: 'Duration',     value: activity.durationMinutes >= 60 ? `${activity.durationMinutes / 60}h` : `${activity.durationMinutes}m` },
                { label: 'Fee',          value: activity.isPaid ? `$${activity.fee}` : 'Free' },
                { label: 'Status',       value: activity.status },
              ].map((s) => (
                <div key={s.label} className="py-3 px-4 text-center">
                  <p className="text-base font-bold text-ink-900">{s.value}</p>
                  <p className="mt-0.5 text-[10px] font-medium uppercase tracking-wide text-ink-400">{s.label}</p>
                </div>
              ))}
            </div>
          </div>

          {/* About + Vibe in one card */}
          <div className="rounded-2xl border border-ink-200 bg-white shadow-card px-5 py-4 space-y-4">
            <div>
              <p className="text-[11px] font-bold uppercase tracking-wide text-ink-400 mb-2">About</p>
              <p className="text-sm leading-relaxed text-ink-700">{activity.description}</p>
            </div>
            {activity.vibeTags.length > 0 && (
              <div>
                <p className="text-[11px] font-bold uppercase tracking-wide text-ink-400 mb-2">Vibe</p>
                <div className="flex flex-wrap gap-1.5">
                  {activity.vibeTags.map((tag) => (
                    <span key={tag} className="rounded-full border border-ink-200 bg-ink-50 px-2.5 py-1 text-xs font-medium text-ink-600">{tag}</span>
                  ))}
                </div>
              </div>
            )}
          </div>

        </div>

        {/* RIGHT column */}
        <div className="space-y-4">

          {/* Host */}
          <div className="rounded-2xl border border-ink-200 bg-white shadow-card px-5 py-4">
            <p className="text-[11px] font-bold uppercase tracking-wide text-ink-400 mb-3">Host</p>
            <div className="flex items-center gap-3">
              <img src={`https://api.dicebear.com/8.x/thumbs/svg?seed=${activity.hostAvatarSeed}`} alt={activity.host} className="h-11 w-11 rounded-xl bg-ink-200" />
              <div className="flex-1 min-w-0">
                <p className="font-bold text-ink-900 text-sm leading-tight">{activity.host}</p>
                <p className="text-xs text-ink-400 mt-0.5">Host</p>
              </div>
              <div className="text-right shrink-0">
                <p className="text-sm font-bold text-success-600">★ {activity.hostRating.toFixed(1)}</p>
                <p className="text-xs text-ink-400">{activity.hostGamesCount} games</p>
              </div>
            </div>
          </div>

          {/* Details */}
          <div className="rounded-2xl border border-ink-200 bg-white shadow-card px-5 py-4 space-y-3">
            <p className="text-[11px] font-bold uppercase tracking-wide text-ink-400">Details</p>
            <MetaItem
              icon={<svg width="12" height="12" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"><rect x="1" y="3" width="16" height="14" rx="2" /><path d="M1 7h16M5 1v4M13 1v4" /></svg>}
              primary={activity.scheduledDate}
              secondary={`${activity.startTime} – ${activity.endTime}`}
            />
            <MetaItem
              icon={<svg width="12" height="12" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"><path d="M9 1C5.686 1 3 3.686 3 7c0 4.5 6 10 6 10s6-5.5 6-10c0-3.314-2.686-6-6-6z" /><circle cx="9" cy="7" r="2" /></svg>}
              primary={activity.location}
              secondary={activity.addressLine ?? (activity.distanceKm ? `${activity.distanceKm} km away` : undefined)}
            />
          </div>

          {/* Participants */}
          <div className="rounded-2xl border border-ink-200 bg-white shadow-card px-5 py-4">
            <p className="text-[11px] font-bold uppercase tracking-wide text-ink-400 mb-3">Participants</p>
            <div className="flex items-baseline justify-between mb-2">
              <span className="text-2xl font-bold text-ink-900">{activity.participants}</span>
              <span className="text-sm text-ink-400">/ {activity.capacity} spots</span>
            </div>
            <div className="h-2 w-full overflow-hidden rounded-full bg-ink-100">
              <div className="h-full rounded-full" style={{ width: `${pct}%`, backgroundColor: isFull ? '#f59e0b' : '#1e6b9a' }} />
            </div>
            <p className="mt-1.5 text-xs text-ink-400">
              {isFull ? 'Activity is full' : `${activity.capacity - activity.participants} spot${activity.capacity - activity.participants !== 1 ? 's' : ''} remaining`}
            </p>
          </div>

        </div>
      </div>
    </div>
  );
}

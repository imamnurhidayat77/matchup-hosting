import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useActivities } from '../../hooks/useActivities';
import { PageSkeleton, PageError } from '../../components/ui/PageStates';
import { downloadCsv } from '../../utils/csvExport';
import type { ActivityStatus } from '../../data/activitiesDummy';

function StatusBadge({ status }: { status: ActivityStatus }) {
  const map: Record<ActivityStatus, string> = {
    Active:    'badge-blue',
    Full:      'badge-yellow',
    Completed: 'badge-neutral',
    Cancelled: 'badge-red',
    Flagged:   'badge-red',
  };
  const dot: Record<ActivityStatus, string> = {
    Active:    'bg-brand-700',
    Full:      'bg-warning-700',
    Completed: 'bg-ink-500',
    Cancelled: 'bg-danger-700',
    Flagged:   'bg-danger-700',
  };
  return (
    <span className={map[status]}>
      <span className={`inline-block h-1.5 w-1.5 rounded-full ${dot[status]}`} />
      {status}
    </span>
  );
}

function ProgressBar({ value, max }: { value: number; max: number }) {
  const pct = Math.min((value / max) * 100, 100);
  return (
    <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-ink-200">
      <div className="h-full rounded-full" style={{ width: `${pct}%`, backgroundColor: pct >= 100 ? '#f59e0b' : '#1e6b9a' }} />
    </div>
  );
}

export function ActivitiesPage() {
  const { loading, error, activities, reload, handleStatusChange, handleDelete } = useActivities();
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [menuOpenId, setMenuOpenId] = useState<string | null>(null);

  if (loading) return <PageSkeleton />;
  if (error) return <PageError message={error} onRetry={reload} />;

  function handleExport() {
    downloadCsv(
      activities.map((a) => ({ Name: a.name, ID: a.matchId, Sport: a.sport, Host: a.host, Location: a.location, Participants: a.participants, Capacity: a.capacity, Status: a.status, Fee: a.isPaid ? `$${a.fee}` : 'Free', Date: a.scheduledDate })),
      'matchup-activities.csv',
    );
  }

  const filtered = activities.filter((a) => {
    const matchSearch =
      a.name.toLowerCase().includes(search.toLowerCase()) ||
      a.sport.toLowerCase().includes(search.toLowerCase()) ||
      a.host.toLowerCase().includes(search.toLowerCase());
    const matchStatus = statusFilter === 'All' || a.status === statusFilter;
    return matchSearch && matchStatus;
  });

  const STATUS_TABS = ['All', 'Active', 'Full', 'Completed', 'Cancelled', 'Flagged'];

  const stats = [
    { label: 'Total Activities', value: activities.length },
    { label: 'Active',  value: activities.filter(a => a.status === 'Active').length },
    { label: 'Flagged', value: activities.filter(a => a.status === 'Flagged').length },
    { label: 'Full',    value: activities.filter(a => a.status === 'Full').length },
  ];

  return (
    <div className="page-container space-y-5" onClick={() => setMenuOpenId(null)}>

      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-ink-900 sm:text-2xl">Activities Management</h1>
          <p className="mt-1 text-xs text-ink-600 sm:text-sm">Review, moderate, and manage all sports activities on the platform</p>
        </div>
        <div className="flex shrink-0 gap-2">
          <button onClick={handleExport} className="btn-outline rounded-lg px-3 py-1.5 text-sm">Export CSV</button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {stats.map((s) => (
          <div key={s.label} className="card py-4 text-center">
            <p className="text-2xl font-bold text-ink-900">{s.value}</p>
            <p className="mt-1 text-xs text-ink-500">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Table panel */}
      <div className="panel overflow-hidden">
        {/* Top bar */}
        <div className="flex flex-col gap-3 border-b border-ink-200 px-4 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <div className="flex flex-wrap gap-1">
            {STATUS_TABS.map((tab) => (
              <button
                key={tab}
                onClick={() => setStatusFilter(tab)}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                  statusFilter === tab ? 'bg-brand-500 text-white' : 'bg-ink-100 text-ink-600 hover:bg-ink-200'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2 rounded-full bg-ink-50 px-3 py-1.5 w-full sm:w-auto">
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><circle cx="6" cy="6" r="4" /><path d="M11 11l-2.5-2.5" /></svg>
            <input type="text" placeholder="Search activities..." value={search} onChange={(e) => setSearch(e.target.value)} className="flex-1 bg-transparent text-[13px] text-ink-700 placeholder:text-ink-400 focus:outline-none sm:w-44" />
          </div>
        </div>

        {/* Desktop table */}
        <div className="hidden overflow-x-auto md:block">
          <table className="w-full">
            <thead>
              <tr className="border-b border-ink-200 bg-ink-50">
                <th className="tbl-th">Activity</th>
                <th className="tbl-th">Sport</th>
                <th className="tbl-th">Host</th>
                <th className="tbl-th">Location</th>
                <th className="tbl-th">Capacity</th>
                <th className="tbl-th">Fee</th>
                <th className="tbl-th">Status</th>
                <th className="tbl-th">Date</th>
                <th className="tbl-th"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-ink-200">
              {filtered.map((a, i) => (
                <tr key={a.id} className={i % 2 === 0 ? 'bg-white' : 'bg-ink-50'}>
                  <td className="tbl-td">
                    <Link to={`/activities/${a.id}`} className="group block">
                      <p className="font-semibold text-brand-500 group-hover:underline leading-snug">{a.name}</p>
                      <p className="text-xs text-ink-400">ID: {a.matchId}</p>
                    </Link>
                  </td>
                  <td className="tbl-td">
                    <span className="rounded-md bg-ink-100 px-2 py-1 text-xs font-semibold text-ink-600">{a.sport}</span>
                  </td>
                  <td className="tbl-td">
                    <div className="flex items-center gap-2">
                      <img src={`https://api.dicebear.com/8.x/thumbs/svg?seed=${a.hostAvatarSeed}`} alt={a.host} className="h-6 w-6 rounded-full bg-ink-200" />
                      <span className="text-[13px] font-medium text-ink-700">{a.host}</span>
                    </div>
                  </td>
                  <td className="tbl-td text-[13px] text-ink-600">{a.location}</td>
                  <td className="tbl-td">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-semibold text-ink-700">{a.participants}/{a.capacity}</span>
                      <span className="text-ink-400">{a.participants >= a.capacity ? 'Full' : 'Open'}</span>
                    </div>
                    <ProgressBar value={a.participants} max={a.capacity} />
                  </td>
                  <td className="tbl-td text-[13px]">
                    {a.isPaid ? <span className="font-semibold text-ink-700">${a.fee}</span> : <span className="text-ink-400">Free</span>}
                  </td>
                  <td className="tbl-td"><StatusBadge status={a.status} /></td>
                  <td className="tbl-td text-[13px] text-ink-600">{a.scheduledDate}</td>
                  <td className="tbl-td">
                    <div className="relative">
                      <button
                        onClick={(e) => { e.stopPropagation(); setMenuOpenId(menuOpenId === a.id ? null : a.id); }}
                        className="rounded-lg px-2 py-1 text-xs font-semibold text-ink-500 hover:bg-ink-100"
                      >
                        •••
                      </button>
                      {menuOpenId === a.id && (
                        <div className="absolute right-0 z-10 mt-1 w-44 rounded-xl border border-ink-200 bg-white py-1 shadow-panel">
                          {a.status !== 'Flagged'   && <button className="w-full px-4 py-2 text-left text-sm text-warning-600 hover:bg-ink-50" onClick={() => { handleStatusChange(a.id, 'Flagged');   setMenuOpenId(null); }}>Flag</button>}
                          {a.status !== 'Cancelled' && <button className="w-full px-4 py-2 text-left text-sm text-danger-500 hover:bg-ink-50"  onClick={() => { handleStatusChange(a.id, 'Cancelled'); setMenuOpenId(null); }}>Cancel Activity</button>}
                          <button className="w-full px-4 py-2 text-left text-sm text-danger-700 hover:bg-ink-50" onClick={() => { handleDelete(a.id); setMenuOpenId(null); }}>Remove</button>
                        </div>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Mobile cards */}
        <div className="divide-y divide-ink-200 md:hidden">
          {filtered.map((a) => (
            <div key={a.id} className="px-4 py-3 space-y-2">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <p className="text-sm font-semibold text-ink-900">{a.name}</p>
                  <p className="text-xs text-ink-400">{a.matchId} · {a.sport}</p>
                </div>
                <StatusBadge status={a.status} />
              </div>
              <div className="flex items-center justify-between text-xs text-ink-600">
                <span className="flex items-center gap-1.5">
                  <img src={`https://api.dicebear.com/8.x/thumbs/svg?seed=${a.hostAvatarSeed}`} alt={a.host} className="h-5 w-5 rounded-full" />
                  {a.host}
                </span>
                <span>{a.scheduledDate}</span>
              </div>
              <div className="flex items-center justify-between text-xs">
                <span className="font-medium text-ink-700">{a.participants}/{a.capacity}</span>
                <ProgressBar value={a.participants} max={a.capacity} />
              </div>
            </div>
          ))}
        </div>

        {filtered.length === 0 && <p className="py-12 text-center text-sm text-ink-400">No activities match your search.</p>}
      </div>
    </div>
  );
}

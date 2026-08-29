import { useState, useEffect, useRef } from 'react';
import { Link } from 'react-router-dom';
import { useActivities } from '../../hooks/useActivities';
import { ActivitiesPageSkeleton, PageError, EmptyState, EmptyIcons } from '../../components/ui/PageStates';
import { downloadCsv } from '../../utils/csvExport';
import { useToast } from '../../context/ToastContext';
import type { ActivityStatus } from '../../data/activitiesDummy';

const PAGE_SIZE = 10;

// ─── Date range helper ────────────────────────────────────────────────────────

type DateRange = 'All' | 'Today' | 'This Week' | 'This Month';

function matchesDateRange(dateStr: string, range: DateRange): boolean {
  if (range === 'All') return true;
  const d = new Date(dateStr);
  const now = new Date();
  if (range === 'Today') {
    return d.toDateString() === now.toDateString();
  }
  if (range === 'This Week') {
    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - now.getDay());
    weekStart.setHours(0, 0, 0, 0);
    return d >= weekStart;
  }
  if (range === 'This Month') {
    return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
  }
  return true;
}

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
  const { push: toast } = useToast();
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [sportFilter, setSportFilter] = useState('All');
  const [dateRange, setDateRange] = useState<DateRange>('All');
  const [menuOpenId, setMenuOpenId] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === '/' && document.activeElement?.tagName !== 'INPUT' && document.activeElement?.tagName !== 'TEXTAREA') {
        e.preventDefault();
        searchRef.current?.focus();
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  if (loading) return <ActivitiesPageSkeleton />;
  if (error) return <PageError message={error} onRetry={reload} />;

  // Derive unique sports from data
  const allSports = ['All', ...Array.from(new Set(activities.map(a => a.sport))).sort()];

  function handleExport() {
    downloadCsv(
      activities.map((a) => ({ Name: a.name, ID: a.matchId, Sport: a.sport, Host: a.host, Location: a.location, Participants: a.participants, Capacity: a.capacity, Status: a.status, Fee: a.isPaid ? `$${a.fee}` : 'Free', Date: a.scheduledDate })),
      'matchup-activities.csv',
    );
    toast('Activities exported as CSV.', 'info');
  }

  const filtered = activities.filter((a) => {
    const matchSearch =
      a.name.toLowerCase().includes(search.toLowerCase()) ||
      a.sport.toLowerCase().includes(search.toLowerCase()) ||
      a.host.toLowerCase().includes(search.toLowerCase());
    const matchStatus = statusFilter === 'All' || a.status === statusFilter;
    const matchSport  = sportFilter === 'All' || a.sport === sportFilter;
    const matchDate   = matchesDateRange(a.scheduledDate, dateRange);
    return matchSearch && matchStatus && matchSport && matchDate;
  });

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const paginated = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  function applyFilter(f: string) { setStatusFilter(f); setPage(1); }
  function applySearch(s: string) { setSearch(s); setPage(1); }
  function applySport(s: string)  { setSportFilter(s); setPage(1); }
  function applyDate(d: DateRange) { setDateRange(d); setPage(1); }

  const STATUS_TABS = ['All', 'Active', 'Full', 'Completed', 'Cancelled', 'Flagged'];
  const DATE_OPTIONS: DateRange[] = ['All', 'Today', 'This Week', 'This Month'];

  const activeFilterCount = [statusFilter !== 'All', sportFilter !== 'All', dateRange !== 'All'].filter(Boolean).length;

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
        {/* Status tab bar */}
        <div className="flex flex-col gap-3 border-b border-ink-200 px-4 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <div className="flex flex-wrap gap-1">
            {STATUS_TABS.map((tab) => (
              <button
                key={tab}
                onClick={() => applyFilter(tab)}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                  statusFilter === tab ? 'bg-brand-500 text-white' : 'bg-ink-100 text-ink-600 hover:bg-ink-200 dark:bg-ink-700 dark:text-ink-300 dark:hover:bg-ink-600'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2 rounded-full bg-ink-50 dark:bg-ink-700/50 px-3 py-1.5 w-full sm:w-auto">
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><circle cx="6" cy="6" r="4" /><path d="M11 11l-2.5-2.5" /></svg>
            <input ref={searchRef} type="text" placeholder="Search activities… (/)" value={search} onChange={(e) => applySearch(e.target.value)} className="flex-1 bg-transparent text-[13px] text-ink-700 dark:text-ink-300 placeholder:text-ink-400 focus:outline-none sm:w-44" />
          </div>
        </div>

        {/* Advanced filters row */}
        <div className="flex flex-wrap items-center gap-2 border-b border-ink-100 dark:border-ink-700 bg-ink-50 dark:bg-ink-900/20 px-4 sm:px-6 py-2.5">
          {/* Sport filter */}
          <div className="flex items-center gap-1.5">
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><circle cx="6" cy="6" r="5" /><path d="M1 6h10M6 1a8 8 0 000 10M6 1a8 8 0 010 10" /></svg>
            <select
              value={sportFilter}
              onChange={(e) => applySport(e.target.value)}
              className="rounded-lg border border-ink-200 dark:border-ink-600 bg-white dark:bg-ink-800 px-2 py-1 text-xs text-ink-700 dark:text-ink-300 focus:outline-none focus:ring-1 focus:ring-brand-400"
            >
              {allSports.map(s => <option key={s} value={s}>{s}</option>)}
            </select>
          </div>

          {/* Date range filter */}
          <div className="flex items-center gap-1.5">
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><rect x="1" y="2" width="10" height="9" rx="1.5" /><path d="M1 5h10M4 1v2M8 1v2" /></svg>
            <div className="flex gap-0.5">
              {DATE_OPTIONS.map((d) => (
                <button
                  key={d}
                  onClick={() => applyDate(d)}
                  className={`rounded-md px-2 py-1 text-[11px] font-semibold transition-colors ${
                    dateRange === d ? 'bg-brand-500 text-white' : 'text-ink-500 dark:text-ink-400 hover:bg-ink-200 dark:hover:bg-ink-700'
                  }`}
                >
                  {d}
                </button>
              ))}
            </div>
          </div>

          {/* Clear filters */}
          {activeFilterCount > 0 && (
            <button
              onClick={() => { applyFilter('All'); applySport('All'); applyDate('All'); }}
              className="ml-auto flex items-center gap-1 text-xs font-semibold text-danger-500 hover:underline"
            >
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M1 1l8 8M9 1L1 9" /></svg>
              Clear ({activeFilterCount})
            </button>
          )}
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
            <tbody className="divide-y divide-ink-200 dark:divide-ink-700">
              {paginated.map((a, i) => (
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
                        className="rounded-lg px-2 py-1 text-xs font-semibold text-ink-500 hover:bg-ink-100 dark:hover:bg-ink-700"
                      >
                        •••
                      </button>
                      {menuOpenId === a.id && (
                        <div className="absolute right-0 z-10 mt-1 w-44 rounded-xl border border-ink-200 dark:border-ink-700 bg-white dark:bg-ink-800 py-1 shadow-panel">
                          {a.status !== 'Flagged'   && <button className="w-full px-4 py-2 text-left text-sm text-warning-600 hover:bg-ink-50 dark:hover:bg-ink-700" onClick={() => { handleStatusChange(a.id, 'Flagged');   toast('Activity flagged.', 'warning'); setMenuOpenId(null); }}>Flag</button>}
                          {a.status !== 'Cancelled' && <button className="w-full px-4 py-2 text-left text-sm text-danger-500 hover:bg-ink-50 dark:hover:bg-ink-700"  onClick={() => { handleStatusChange(a.id, 'Cancelled'); toast('Activity cancelled.', 'info'); setMenuOpenId(null); }}>Cancel Activity</button>}
                          <button className="w-full px-4 py-2 text-left text-sm text-danger-700 hover:bg-ink-50 dark:hover:bg-ink-700" onClick={() => { handleDelete(a.id); toast('Activity removed.', 'info'); setMenuOpenId(null); }}>Remove</button>
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

        {paginated.length === 0 && (
          <EmptyState
            icon={EmptyIcons[search ? 'search' : 'activities']}
            title={search ? 'No activities match your search.' : `No ${statusFilter !== 'All' ? statusFilter.toLowerCase() + ' ' : ''}activities.`}
            description={search ? 'Try a different name, sport, or host.' : undefined}
          />
        )}
        {totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-ink-100 dark:border-ink-700 px-6 py-3">
            <p className="text-xs text-ink-400">Showing {(page - 1) * PAGE_SIZE + 1}–{Math.min(page * PAGE_SIZE, filtered.length)} of {filtered.length}</p>
            <div className="flex gap-1">
              <button disabled={page === 1} onClick={() => setPage(p => p - 1)} className="rounded-lg px-2.5 py-1.5 text-xs font-semibold text-ink-500 hover:bg-ink-100 dark:hover:bg-ink-700 disabled:opacity-30">Prev</button>
              {[...Array(totalPages)].map((_, i) => (
                <button key={i} onClick={() => setPage(i + 1)} className={`rounded-lg px-2.5 py-1.5 text-xs font-semibold transition-colors ${page === i + 1 ? 'bg-brand-500 text-white' : 'text-ink-500 hover:bg-ink-100 dark:hover:bg-ink-700'}`}>{i + 1}</button>
              ))}
              <button disabled={page === totalPages} onClick={() => setPage(p => p + 1)} className="rounded-lg px-2.5 py-1.5 text-xs font-semibold text-ink-500 hover:bg-ink-100 dark:hover:bg-ink-700 disabled:opacity-30">Next</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

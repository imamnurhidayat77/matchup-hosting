import { useState } from 'react';
import { useAuditLog } from '../../hooks/useAuditLog';
import { useTheme } from '../../context/ThemeContext';
import { downloadCsv } from '../../utils/csvExport';
import { useToast } from '../../context/ToastContext';
import { PageSkeleton, PageError, EmptyState, EmptyIcons } from '../../components/ui/PageStates';
import type { AuditEntry, AuditCategory } from '../../data/auditLogDummy';

// ─── Category badge ───────────────────────────────────────────────────────────

// Light/dark colors defined explicitly — Tailwind dark: variants on arbitrary
// colors are not reliably generated, so we use inline style for dark mode.
const CATEGORY_META: Record<AuditCategory, {
  lightBg: string; lightText: string;
  darkBg: string;  darkText: string;
  dot: string;
}> = {
  Reports:    { lightBg: '#fee2e2', lightText: '#991b1b', darkBg: 'rgba(220,38,38,0.2)',   darkText: '#fca5a5', dot: '#ef4444' },
  Members:    { lightBg: '#dbeafe', lightText: '#0f1a52', darkBg: 'rgba(11,31,138,0.25)', darkText: '#8fadf6', dot: '#0b1f8a' },
  Activities: { lightBg: '#fef3c7', lightText: '#92400e', darkBg: 'rgba(217,119,6,0.25)',  darkText: '#fcd34d', dot: '#f59e0b' },
  Appeals:    { lightBg: '#f3e8ff', lightText: '#6b21a8', darkBg: 'rgba(168,85,247,0.2)',  darkText: '#d8b4fe', dot: '#a855f7' },
  Broadcasts: { lightBg: '#ffe5d0', lightText: '#b84c00', darkBg: 'rgba(255,107,0,0.2)',  darkText: '#ffab66', dot: '#ff6b00' },
  Sports:     { lightBg: '#dcfce7', lightText: '#15803d', darkBg: 'rgba(34,197,94,0.2)',   darkText: '#86efac', dot: '#22c55e' },
  Settings:   { lightBg: '#f1f5f9', lightText: '#475569', darkBg: 'rgba(71,85,105,0.3)',   darkText: '#cbd5e1', dot: '#94a3b8' },
};

function CategoryBadge({ category, isDark }: { category: AuditCategory; isDark: boolean }) {
  const m = CATEGORY_META[category];
  return (
    <span
      className="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-semibold"
      style={{
        backgroundColor: isDark ? m.darkBg : m.lightBg,
        color: isDark ? m.darkText : m.lightText,
      }}
    >
      <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: m.dot }} />
      {category}
    </span>
  );
}

// ─── Action verb chip ─────────────────────────────────────────────────────────

function actionVerb(action: string): string {
  const map: Record<string, string> = {
    'report.resolve':   'Resolved',
    'report.dismiss':   'Dismissed',
    'member.suspend':   'Suspended',
    'member.activate':  'Activated',
    'member.remove':    'Removed',
    'activity.cancel':  'Cancelled',
    'activity.flag':    'Flagged',
    'activity.remove':  'Removed',
    'appeal.approve':   'Approved',
    'appeal.reject':    'Rejected',
    'broadcast.send':   'Sent',
    'broadcast.delete': 'Deleted',
    'sport.add':        'Added',
    'sport.disable':    'Disabled',
    'sport.publish':    'Published',
    'settings.update':  'Updated',
  };
  return map[action] ?? action;
}

// ─── Log row ──────────────────────────────────────────────────────────────────

function LogRow({ entry, index, isDark }: { entry: AuditEntry; index: number; isDark: boolean }) {
  const [expanded, setExpanded] = useState(false);
  const hasMetadata = entry.metadata && Object.keys(entry.metadata).length > 0;
  const m = CATEGORY_META[entry.category];

  // Action verb colors — distinct per action type
  const verbColor: Record<string, string> = {
    'report.resolve':  isDark ? '#4ade80' : '#15803d',
    'report.dismiss':  isDark ? '#94a3b8' : '#475569',
    'member.suspend':  isDark ? '#fca5a5' : '#991b1b',
    'member.activate': isDark ? '#4ade80' : '#15803d',
    'member.remove':   isDark ? '#f87171' : '#dc2626',
    'activity.cancel': isDark ? '#fcd34d' : '#92400e',
    'activity.flag':   isDark ? '#fcd34d' : '#92400e',
    'activity.remove': isDark ? '#f87171' : '#dc2626',
    'appeal.approve':  isDark ? '#4ade80' : '#15803d',
    'appeal.reject':   isDark ? '#fca5a5' : '#991b1b',
    'broadcast.send':  isDark ? '#7dd3fc' : '#0369a1',
    'broadcast.delete':isDark ? '#94a3b8' : '#475569',
    'sport.add':       isDark ? '#86efac' : '#15803d',
    'sport.disable':   isDark ? '#94a3b8' : '#475569',
    'sport.publish':   isDark ? '#8fadf6' : '#0f1a52',
    'settings.update': isDark ? '#cbd5e1' : '#334155',
  };

  return (
    <div
      className={`group cursor-pointer px-4 sm:px-6 py-3.5 transition-colors hover:bg-ink-50 ${
        index % 2 !== 0 ? 'bg-ink-50/40' : ''
      }`}
      style={index % 2 !== 0 && isDark ? { backgroundColor: 'rgba(25,33,48,0.5)' } : undefined}
      onClick={() => hasMetadata && setExpanded((v) => !v)}
    >
      <div className="flex items-start gap-3">
        {/* Timeline dot */}
        <div className="mt-2 shrink-0">
          <div className="h-2 w-2 rounded-full" style={{ backgroundColor: m.dot }} />
        </div>

        {/* Main content */}
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-start justify-between gap-2">
            <div className="flex flex-wrap items-center gap-2 min-w-0">
              {/* Action verb — colored by action type */}
              <span
                className="text-[11px] font-bold uppercase tracking-wider"
                style={{ color: verbColor[entry.action] ?? (isDark ? '#94a3b8' : '#475569') }}
              >
                {actionVerb(entry.action)}
              </span>
              <CategoryBadge category={entry.category} isDark={isDark} />
              {/* Description — primary text, must be clearly readable */}
              <p className="text-sm font-semibold text-ink-900 truncate max-w-[280px] sm:max-w-none">
                {entry.description}
              </p>
            </div>
            {/* Timestamp — use ink-500 level, not ink-400 */}
            <time className="shrink-0 text-xs font-medium text-ink-500">
              {new Date(entry.createdAt).toLocaleString('en-US', {
                month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
              })}
            </time>
          </div>

          {/* Sub-row: admin name + target */}
          <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-ink-600">
            <span className="flex items-center gap-1">
              <svg width="10" height="10" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
                <circle cx="6" cy="4" r="2.5" /><path d="M1 11c0-2.76 2.24-4 5-4s5 1.24 5 4" />
              </svg>
              {entry.adminName}
            </span>
            <span className="text-ink-400">·</span>
            <span className="font-mono text-[11px] text-ink-500">{entry.targetLabel}</span>
            {hasMetadata && (
              <span className="text-ink-500 group-hover:text-brand-400 transition-colors ml-1">
                {expanded ? '▲ less' : '▾ details'}
              </span>
            )}
          </div>

          {/* Expanded metadata */}
          {expanded && hasMetadata && (
            <div
              className="mt-2 rounded-lg border px-3 py-2"
              style={{
                backgroundColor: isDark ? 'rgba(51,65,85,0.4)' : '#f8fafc',
                borderColor: isDark ? '#334155' : '#e2e8f0',
              }}
            >
              <div className="flex flex-wrap gap-x-6 gap-y-1">
                {Object.entries(entry.metadata!).map(([k, v]) => (
                  <span key={k} className="text-xs">
                    <span className="font-semibold text-ink-600">{k}:</span>{' '}
                    <span className="text-ink-800">{v}</span>
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

const ALL_CATEGORIES: AuditCategory[] = ['Reports', 'Members', 'Activities', 'Appeals', 'Broadcasts', 'Sports', 'Settings'];
const PAGE_SIZE = 10;

export function AuditLogPage() {
  const { loading, error, entries } = useAuditLog();
  const { push: toast } = useToast();
  const { theme } = useTheme();
  const isDark = theme === 'dark';
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState<AuditCategory | 'All'>('All');
  const [page, setPage] = useState(1);

  if (loading) return <PageSkeleton rows={5} />;
  if (error) return <PageError message={error} onRetry={() => {}} />;

  function handleExport() {
    downloadCsv(
      entries.map((e) => ({
        ID: e.id, Action: e.action, Category: e.category,
        Description: e.description, Target: e.targetLabel,
        Admin: e.adminName, Date: e.createdAt,
      })),
      'matchup-audit-log.csv',
    );
    toast('Audit log exported as CSV.', 'info');
  }

  const filtered = entries.filter((e) => {
    const matchCat    = categoryFilter === 'All' || e.category === categoryFilter;
    const matchSearch =
      e.description.toLowerCase().includes(search.toLowerCase()) ||
      e.targetLabel.toLowerCase().includes(search.toLowerCase()) ||
      e.action.toLowerCase().includes(search.toLowerCase());
    return matchCat && matchSearch;
  });

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const paginated  = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  function applyCategory(c: AuditCategory | 'All') { setCategoryFilter(c); setPage(1); }
  function applySearch(s: string) { setSearch(s); setPage(1); }

  // Category breakdown for sidebar
  const breakdown = ALL_CATEGORIES.map((c) => ({
    category: c,
    count: entries.filter((e) => e.category === c).length,
  })).sort((a, b) => b.count - a.count);

  return (
    <div className="page-container space-y-5">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-ink-900 sm:text-2xl">Audit Log</h1>
          <p className="mt-1 text-xs text-ink-600 sm:text-sm">
            Complete record of all admin actions for accountability and debugging
          </p>
        </div>
        <button onClick={handleExport} className="btn-outline rounded-lg px-3 py-1.5 text-sm self-start sm:self-auto">
          Export CSV
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {[
          { label: 'Total Actions', value: entries.length },
          { label: 'Today',  value: entries.filter(e => new Date(e.createdAt).toDateString() === new Date().toDateString()).length },
          { label: 'This Week', value: entries.filter(e => {
            const d = new Date(e.createdAt);
            const now = new Date();
            const weekStart = new Date(now); weekStart.setDate(now.getDate() - now.getDay());
            return d >= weekStart;
          }).length },
          { label: 'Admins Active', value: new Set(entries.map(e => e.adminEmail)).size },
        ].map((s) => (
          <div key={s.label} className="card py-4 text-center">
            <p className="text-2xl font-bold text-ink-900">{s.value}</p>
            <p className="mt-1 text-xs text-ink-500">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1fr_260px]">

        {/* Main log panel */}
        <div className="panel overflow-hidden">
          {/* Toolbar */}
          <div className="flex flex-col gap-3 border-b border-ink-200 px-4 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
            <div className="flex flex-wrap gap-1">
              <button
                onClick={() => applyCategory('All')}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                  categoryFilter === 'All' ? 'bg-brand-500 text-white' : 'bg-ink-100 text-ink-600 hover:bg-ink-200 dark:bg-ink-700 dark:text-ink-300 dark:hover:bg-ink-600'
                }`}
              >
                All
              </button>
              {ALL_CATEGORIES.map((cat) => (
                <button
                  key={cat}
                  onClick={() => applyCategory(cat)}
                  className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                    categoryFilter === cat ? 'bg-brand-500 text-white' : 'bg-ink-100 text-ink-600 hover:bg-ink-200 dark:bg-ink-700 dark:text-ink-300 dark:hover:bg-ink-600'
                  }`}
                >
                  {cat}
                </button>
              ))}
            </div>
            <div className="flex items-center gap-2 rounded-full bg-ink-50 dark:bg-ink-700/50 px-3 py-1.5 w-full sm:w-auto">
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
                <circle cx="6" cy="6" r="4" /><path d="M11 11l-2.5-2.5" />
              </svg>
              <input
                type="text"
                placeholder="Search actions…"
                value={search}
                onChange={(e) => applySearch(e.target.value)}
                className="flex-1 bg-transparent text-[13px] text-ink-700 dark:text-ink-300 placeholder:text-ink-400 focus:outline-none sm:w-44"
              />
            </div>
          </div>

          {/* Entries */}
          {paginated.length === 0 ? (
            <EmptyState
              icon={EmptyIcons.search}
              title="No log entries found."
              description="Try adjusting your category or search."
            />
          ) : (
            <div className="divide-y divide-ink-100 dark:divide-ink-700">
              {paginated.map((e, i) => <LogRow key={e.id} entry={e} index={i} isDark={isDark} />)}
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-between border-t border-ink-100 dark:border-ink-700 px-6 py-3">
              <p className="text-xs text-ink-400">
                Showing {(page - 1) * PAGE_SIZE + 1}–{Math.min(page * PAGE_SIZE, filtered.length)} of {filtered.length}
              </p>
              <div className="flex gap-1">
                <button
                  disabled={page === 1}
                  onClick={() => setPage(p => p - 1)}
                  className="rounded-lg px-2.5 py-1.5 text-xs font-semibold text-ink-500 hover:bg-ink-100 dark:hover:bg-ink-700 disabled:opacity-30"
                >
                  Prev
                </button>
                {[...Array(totalPages)].map((_, i) => (
                  <button
                    key={i}
                    onClick={() => setPage(i + 1)}
                    className={`rounded-lg px-2.5 py-1.5 text-xs font-semibold transition-colors ${
                      page === i + 1 ? 'bg-brand-500 text-white' : 'text-ink-500 hover:bg-ink-100 dark:hover:bg-ink-700'
                    }`}
                  >
                    {i + 1}
                  </button>
                ))}
                <button
                  disabled={page === totalPages}
                  onClick={() => setPage(p => p + 1)}
                  className="rounded-lg px-2.5 py-1.5 text-xs font-semibold text-ink-500 hover:bg-ink-100 dark:hover:bg-ink-700 disabled:opacity-30"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Sidebar: breakdown */}
        <div className="space-y-4">
          <div className="panel p-5">
            <h2 className="mb-4 text-sm font-semibold text-ink-900">Actions by Category</h2>
            <div className="space-y-3">
              {breakdown.map(({ category, count }) => {
                const pct = entries.length ? Math.round((count / entries.length) * 100) : 0;
                const m = CATEGORY_META[category];
                return (
                  <button
                    key={category}
                    onClick={() => applyCategory(categoryFilter === category ? 'All' : category)}
                    className="w-full text-left"
                  >
                    <div className="flex items-center justify-between text-xs mb-1">
                      <span className="flex items-center gap-1.5 font-medium text-ink-700">
                        <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: m.dot }} />
                        {category}
                      </span>
                      <span className="text-ink-500">{count}</span>
                    </div>
                    <div className="h-1.5 w-full overflow-hidden rounded-full bg-ink-100 dark:bg-ink-700">
                      <div className="h-full rounded-full" style={{ width: `${pct}%`, backgroundColor: m.dot }} />
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Recent activity summary */}
          <div className="panel p-5">
            <h2 className="mb-3 text-sm font-semibold text-ink-900">Recent Activity</h2>
            <div className="space-y-2">
              {entries.slice(0, 5).map((e) => (
                <div key={e.id} className="flex items-start gap-2">
                  <div className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full" style={{ backgroundColor: CATEGORY_META[e.category].dot }} />
                  <div className="min-w-0">
                    <p className="text-xs text-ink-700 truncate">{e.description}</p>
                    <p className="text-[10px] text-ink-500">
                      {new Date(e.createdAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

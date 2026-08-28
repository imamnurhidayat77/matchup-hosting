import { useState, useRef } from 'react';
import { loadSports, saveSports, DEFAULT_SPORTS } from '../../data/sportsDummy';
import { downloadCsv } from '../../utils/csvExport';
import type { SportConfig } from '../../data/sportsDummy';

// ─── Sports emoji palette ─────────────────────────────────────────────────────

const SPORT_EMOJIS = [
  '⚽','🏀','🏈','⚾','🥎','🏐','🏉','🎾','🥏','🎱','🏓','🏸',
  '🥅','🏒','🏑','🏏','🥍','🏹','🥊','🥋','🛹','🛼','🛷','⛸️',
  '🏋️','🤼','🤸','⛹️','🤺','🏇','🧘','🏄','🚣','🧗','🚴','🏊',
  '🤽','🚵','🏌️','🏂','🛿','⛷️','🤾','🎿','🎣','🏇','🧜','🤿',
  '🎯','🎳','🏆','🥇','🎽','👟','🥿','⛳','🎖️','🏅',
];

function EmojiPicker({ selected, onSelect }: { selected: string; onSelect: (e: string) => void }) {
  return (
    <div className="mt-1 max-h-40 overflow-y-auto rounded-xl border border-ink-200 bg-white p-2">
      <div className="grid grid-cols-8 gap-1">
        {SPORT_EMOJIS.map((e) => (
          <button
            key={e}
            type="button"
            onClick={() => onSelect(e)}
            className={`flex h-9 w-full items-center justify-center rounded-lg text-lg transition-colors hover:bg-ink-100 ${
              selected === e ? 'bg-brand-100 ring-2 ring-brand-400' : ''
            }`}
          >
            {e}
          </button>
        ))}
      </div>
    </div>
  );
}

// ─── Add sport modal ──────────────────────────────────────────────────────────

function AddSportModal({
  onClose,
  onAdd,
}: {
  onClose: () => void;
  onAdd: (sport: SportConfig) => void;
}) {
  const [name, setName] = useState('');
  const [emoji, setEmoji] = useState('🏅');
  const [error, setError] = useState('');

  function handleAdd() {
    const trimmed = name.trim();
    if (!trimmed) { setError('Name is required.'); return; }
    onAdd({
      id: trimmed.toLowerCase().replace(/\s+/g, '_'),
      name: trimmed,
      emoji,
      enabled: true,
      showInFilter: true,
      showInOnboarding: true,
      canHost: true,
      sortOrder: 999,
      activityCount: 0,
    });
    onClose();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink-900/50 px-4">
      <div className="w-full max-w-[420px] rounded-2xl bg-white p-6 shadow-panel">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-base font-semibold text-ink-900">Add Sport</h2>
          <button onClick={onClose} className="text-ink-400 hover:text-ink-700 text-xl leading-none">×</button>
        </div>
        <div className="space-y-4">
          <div>
            <label className="mb-1.5 block text-xs font-semibold text-ink-600">Sport Name</label>
            <input
              className="input"
              placeholder="e.g. Handball"
              value={name}
              onChange={(e) => { setName(e.target.value); setError(''); }}
              autoFocus
            />
          </div>
          <div>
            <label className="mb-1.5 block text-xs font-semibold text-ink-600">
              Icon <span className="ml-1 text-xl">{emoji}</span>
            </label>
            <EmojiPicker selected={emoji} onSelect={setEmoji} />
          </div>
          {error && <p className="text-xs text-danger-500">{error}</p>}
          <div className="flex gap-2 pt-1">
            <button onClick={handleAdd} className="btn-primary flex-1 rounded-xl py-2.5 text-sm">Add Sport</button>
            <button onClick={onClose} className="btn-outline flex-1 rounded-xl py-2.5 text-sm">Cancel</button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Toggle switch ────────────────────────────────────────────────────────────

function Toggle({ checked, onChange, size = 'sm' }: { checked: boolean; onChange: (v: boolean) => void; size?: 'sm' | 'md' }) {
  const w = size === 'md' ? 'w-11 h-6' : 'w-8 h-4';
  const t = size === 'md' ? 'h-4 w-4' : 'h-3 w-3';
  const on = size === 'md' ? 'translate-x-6' : 'translate-x-4';
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={(e) => { e.stopPropagation(); onChange(!checked); }}
      className={`relative inline-flex ${w} shrink-0 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-brand-400 focus:ring-offset-1 ${checked ? 'bg-brand-500' : 'bg-ink-300'}`}
    >
      <span className={`inline-block ${t} transform rounded-full bg-white shadow transition-transform ${checked ? on : 'translate-x-1'}`} />
    </button>
  );
}

// ─── Surface chip ─────────────────────────────────────────────────────────────

function SurfaceChip({ label, active, tooltip }: { label: string; active: boolean; tooltip: string }) {
  return (
    <span title={tooltip} className={`inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold ${active ? 'bg-brand-100 text-brand-700' : 'bg-ink-100 text-ink-400'}`}>
      {label}
    </span>
  );
}

// ─── Sport row ────────────────────────────────────────────────────────────────

function SportRow({
  sport,
  onUpdate,
  onDelete,
  onDragStart,
  onDragOver,
  onDrop,
}: {
  sport: SportConfig;
  onUpdate: (id: string, patch: Partial<SportConfig>) => void;
  onDelete: (id: string) => void;
  onDragStart: (id: string) => void;
  onDragOver: (e: React.DragEvent) => void;
  onDrop: (id: string) => void;
}) {
  const [expanded, setExpanded] = useState(false);

  return (
    <>
      <tr
        className="cursor-pointer hover:bg-ink-50 transition-colors"
        draggable
        onDragStart={(e) => { e.stopPropagation(); onDragStart(sport.id); }}
        onDragOver={onDragOver}
        onDrop={() => onDrop(sport.id)}
        onClick={() => setExpanded((v) => !v)}
      >
        {/* Drag handle */}
        <td className="tbl-td w-8 cursor-grab text-ink-300 active:cursor-grabbing select-none" onClick={(e) => e.stopPropagation()}>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
            <circle cx="4" cy="3" r="1.2" /><circle cx="10" cy="3" r="1.2" />
            <circle cx="4" cy="7" r="1.2" /><circle cx="10" cy="7" r="1.2" />
            <circle cx="4" cy="11" r="1.2" /><circle cx="10" cy="11" r="1.2" />
          </svg>
        </td>

        {/* Emoji + Name */}
        <td className="tbl-td">
          <div className="flex items-center gap-3">
            <span className="text-xl">{sport.emoji}</span>
            <div>
              <p className={`font-semibold ${sport.enabled ? 'text-ink-900' : 'text-ink-400 line-through'}`}>{sport.name}</p>
              {/* Surface chips — compact summary */}
              <div className="mt-0.5 flex gap-1">
                <SurfaceChip label="Filter"      active={sport.enabled && sport.showInFilter}      tooltip="Discovery filter" />
                <SurfaceChip label="Onboarding"  active={sport.enabled && sport.showInOnboarding}  tooltip="Sport picker in onboarding" />
                <SurfaceChip label="Host"        active={sport.enabled && sport.canHost}            tooltip="Users can create activities" />
              </div>
            </div>
          </div>
        </td>

        {/* Activity count */}
        <td className="tbl-td text-[13px] text-ink-600">{sport.activityCount.toLocaleString()}</td>

        {/* Single enabled toggle */}
        <td className="tbl-td" onClick={(e) => e.stopPropagation()}>
          <Toggle checked={sport.enabled} onChange={(v) => onUpdate(sport.id, { enabled: v })} size="md" />
        </td>

        {/* Expand chevron + delete */}
        <td className="tbl-td">
          <div className="flex items-center justify-end gap-2">
            {sport.activityCount === 0 ? (
              <button
                onClick={(e) => { e.stopPropagation(); onDelete(sport.id); }}
                className="rounded-lg p-1.5 text-danger-400 hover:bg-danger-50 hover:text-danger-600 transition-colors"
                title="Remove"
              >
                <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
                  <path d="M2 3.5h10M5 3.5V2.5a1 1 0 011-1h2a1 1 0 011 1v1M6 6.5v3M8 6.5v3M3 3.5l.7 7.5a1 1 0 001 .9h4.6a1 1 0 001-.9l.7-7.5" />
                </svg>
              </button>
            ) : (
              <span className="w-[30px]" />
            )}
            <svg
              width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round"
              className={`text-ink-400 transition-transform ${expanded ? 'rotate-180' : ''}`}
            >
              <path d="M3 5l4 4 4-4" />
            </svg>
          </div>
        </td>
      </tr>

      {/* Expanded detail row */}
      {expanded && (
        <tr className="bg-ink-50">
          <td colSpan={5} className="px-6 py-3">
            <div className="flex flex-wrap items-center gap-6">
              <p className="text-xs font-semibold text-ink-500 uppercase tracking-wide">Where to show:</p>
              <label className="flex cursor-pointer items-center gap-2 text-sm text-ink-700 select-none">
                <Toggle
                  checked={sport.showInFilter && sport.enabled}
                  onChange={(v) => onUpdate(sport.id, { showInFilter: v })}
                />
                Discovery filter
              </label>
              <label className="flex cursor-pointer items-center gap-2 text-sm text-ink-700 select-none">
                <Toggle
                  checked={sport.showInOnboarding && sport.enabled}
                  onChange={(v) => onUpdate(sport.id, { showInOnboarding: v })}
                />
                Onboarding picker
              </label>
              <label className="flex cursor-pointer items-center gap-2 text-sm text-ink-700 select-none">
                <Toggle
                  checked={sport.canHost && sport.enabled}
                  onChange={(v) => onUpdate(sport.id, { canHost: v })}
                />
                Users can host
              </label>
            </div>
          </td>
        </tr>
      )}
    </>
  );
}

// ─── Summary cards ─────────────────────────────────────────────────────────────

function SummaryCard({ label, value, sub, color = 'text-ink-900' }: { label: string; value: number | string; sub?: string; color?: string }) {
  return (
    <div className="card py-4">
      <p className="text-xs font-medium text-ink-500">{label}</p>
      <p className={`mt-1.5 text-2xl font-bold ${color}`}>{value}</p>
      {sub && <p className="mt-0.5 text-xs text-ink-400">{sub}</p>}
    </div>
  );
}

// ─── Mobile preview ───────────────────────────────────────────────────────────

function MobilePreview({ sports }: { sports: SportConfig[] }) {
  const onboarding = sports.filter((s) => s.enabled && s.showInOnboarding);
  const filter = sports.filter((s) => s.enabled && s.showInFilter);

  return (
    <div className="panel p-5 space-y-5">
      <h2 className="text-base font-semibold text-ink-900">Mobile Preview</h2>

      <div>
        <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-ink-500">
          Onboarding sport picker ({onboarding.length})
        </p>
        <div className="flex flex-wrap gap-2">
          {onboarding.map((s) => (
            <span key={s.id} className="flex items-center gap-1.5 rounded-full border border-ink-200 bg-ink-50 px-3 py-1.5 text-xs font-medium text-ink-700">
              <span>{s.emoji}</span>{s.name}
            </span>
          ))}
          {onboarding.length === 0 && <span className="text-xs text-ink-400">No sports enabled</span>}
        </div>
      </div>

      <div>
        <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-ink-500">
          Discovery filter ({filter.length})
        </p>
        <div className="flex flex-wrap gap-2">
          {filter.map((s) => (
            <span key={s.id} className="flex items-center gap-1.5 rounded-full border border-brand-200 bg-brand-50 px-3 py-1.5 text-xs font-medium text-brand-700">
              <span>{s.emoji}</span>{s.name}
            </span>
          ))}
          {filter.length === 0 && <span className="text-xs text-ink-400">No sports in filter</span>}
        </div>
      </div>

      <p className="rounded-xl border border-warning-200 bg-warning-100 px-4 py-3 text-xs text-warning-700">
        <span className="font-semibold">Note:</span> Changes take effect on the mobile app after the next app config sync. Sports with existing activities cannot be removed.
      </p>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export function SportsPage() {
  const [sports, setSports] = useState<SportConfig[]>(loadSports);
  const [saved, setSaved] = useState(false);
  const [showAdd, setShowAdd] = useState(false);
  const [search, setSearch] = useState('');
  const dragId = useRef<string | null>(null);

  function update(id: string, patch: Partial<SportConfig>) {
    setSports((prev) => prev.map((s) => (s.id === id ? { ...s, ...patch } : s)));
  }

  function handleDelete(id: string) {
    setSports((prev) => prev.filter((s) => s.id !== id));
  }

  function handleAdd(sport: SportConfig) {
    setSports((prev) => {
      const maxOrder = Math.max(...prev.map((s) => s.sortOrder), 0);
      return [...prev, { ...sport, sortOrder: maxOrder + 1 }];
    });
  }

  function handleSave() {
    // Normalise sort orders to 1-based sequential
    const sorted = [...sports].sort((a, b) => a.sortOrder - b.sortOrder).map((s, i) => ({ ...s, sortOrder: i + 1 }));
    saveSports(sorted);
    setSports(sorted);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  }

  function handleReset() {
    if (confirm('Reset all sports to default configuration?')) {
      setSports(DEFAULT_SPORTS);
    }
  }

  function handleExport() {
    downloadCsv(
      sports.map((s) => ({ ID: s.id, Name: s.name, Enabled: s.enabled, Filter: s.showInFilter, Onboarding: s.showInOnboarding, CanHost: s.canHost, Activities: s.activityCount })),
      'matchup-sports.csv',
    );
  }

  // Drag reorder
  function onDragStart(id: string) { dragId.current = id; }
  function onDragOver(e: React.DragEvent) { e.preventDefault(); }
  function onDrop(targetId: string) {
    if (!dragId.current || dragId.current === targetId) return;
    setSports((prev) => {
      const from = prev.findIndex((s) => s.id === dragId.current);
      const to   = prev.findIndex((s) => s.id === targetId);
      const arr = [...prev];
      const [item] = arr.splice(from, 1);
      arr.splice(to, 0, item);
      return arr.map((s, i) => ({ ...s, sortOrder: i + 1 }));
    });
    dragId.current = null;
  }

  const filtered = sports.filter((s) =>
    s.name.toLowerCase().includes(search.toLowerCase()) ||
    s.id.includes(search.toLowerCase()),
  );

  const enabledCount   = sports.filter((s) => s.enabled).length;
  const filterCount    = sports.filter((s) => s.enabled && s.showInFilter).length;
  const onboardingCount = sports.filter((s) => s.enabled && s.showInOnboarding).length;

  return (
    <div className="page-container space-y-5">
      {showAdd && <AddSportModal onClose={() => setShowAdd(false)} onAdd={handleAdd} />}

      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-ink-900 sm:text-2xl">Sports Management</h1>
          <p className="mt-1 text-xs text-ink-600 sm:text-sm">
            Configure which sports appear in onboarding, discovery filter, and activity creation on the mobile app
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button onClick={handleExport} className="btn-outline rounded-lg px-3 py-1.5 text-sm">Export CSV</button>
          <button onClick={handleReset}  className="btn-outline rounded-lg px-3 py-1.5 text-sm text-danger-600 border-danger-200 hover:bg-danger-50">Reset</button>
          <button onClick={() => setShowAdd(true)} className="btn-outline rounded-lg px-3 py-1.5 text-sm">+ Add Sport</button>
          <button
            onClick={handleSave}
            className={`btn-primary rounded-lg px-4 py-1.5 text-sm transition-all ${saved ? '!bg-success-500' : ''}`}
          >
            {saved ? '✓ Published' : 'Publish Changes'}
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <SummaryCard label="Total Sports"   value={sports.length} />
        <SummaryCard label="Enabled"        value={enabledCount}       color="text-brand-500" />
        <SummaryCard label="In Filter"      value={filterCount}        color="text-brand-400" sub="Discovery screen" />
        <SummaryCard label="In Onboarding"  value={onboardingCount}    color="text-brand-400" sub="Setup flow" />
      </div>

      {/* Main grid */}
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1fr_320px]">

        {/* Table */}
        <div className="panel overflow-hidden">
          <div className="flex items-center justify-between border-b border-ink-200 px-4 py-3.5 sm:px-6">
            <p className="text-sm font-semibold text-ink-900">Sport Catalogue <span className="ml-1.5 text-xs font-normal text-ink-400">drag rows to reorder</span></p>
            <div className="flex items-center gap-2 rounded-full bg-ink-50 px-3 py-1.5">
              <svg width="13" height="13" viewBox="0 0 13 13" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><circle cx="5.5" cy="5.5" r="3.8" /><path d="M10 10l-2-2" /></svg>
              <input type="text" placeholder="Search sports..." value={search} onChange={(e) => setSearch(e.target.value)} className="w-32 bg-transparent text-xs text-ink-700 placeholder:text-ink-400 focus:outline-none" />
            </div>
          </div>

          {/* Desktop table */}
          <div className="hidden overflow-x-auto md:block">
            <table className="w-full">
              <thead>
                <tr className="border-b border-ink-200 bg-ink-50">
                  <th className="tbl-th w-8"></th>
                  <th className="tbl-th">Sport</th>
                  <th className="tbl-th">Activities</th>
                  <th className="tbl-th">Enabled</th>
                  <th className="tbl-th w-16"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-ink-200">
                {filtered.map((s) => (
                  <SportRow
                    key={s.id}
                    sport={s}
                    onUpdate={update}
                    onDelete={handleDelete}
                    onDragStart={onDragStart}
                    onDragOver={onDragOver}
                    onDrop={onDrop}
                  />
                ))}
              </tbody>
            </table>
          </div>

          {/* Mobile cards */}
          <div className="divide-y divide-ink-200 md:hidden">
            {filtered.map((s) => (
              <div key={s.id} className="px-4 py-3 space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="text-xl">{s.emoji}</span>
                    <div>
                      <p className={`text-sm font-semibold ${s.enabled ? 'text-ink-900' : 'text-ink-400 line-through'}`}>{s.name}</p>
                      <p className="text-xs text-ink-400">{s.activityCount} activities</p>
                    </div>
                  </div>
                  <Toggle checked={s.enabled} onChange={(v) => update(s.id, { enabled: v })} size="md" />
                </div>
                <div className="flex gap-1">
                  <SurfaceChip label="Filter"     active={s.enabled && s.showInFilter}     tooltip="Discovery filter" />
                  <SurfaceChip label="Onboarding" active={s.enabled && s.showInOnboarding} tooltip="Onboarding picker" />
                  <SurfaceChip label="Host"       active={s.enabled && s.canHost}           tooltip="Can host activities" />
                </div>
              </div>
            ))}
          </div>

          {filtered.length === 0 && <p className="py-10 text-center text-sm text-ink-400">No sports match your search.</p>}
        </div>

        {/* Mobile preview sidebar */}
        <MobilePreview sports={sports} />
      </div>
    </div>
  );
}

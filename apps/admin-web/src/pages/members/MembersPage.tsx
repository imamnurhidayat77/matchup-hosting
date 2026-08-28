import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useMembers } from '../../hooks/useMembers';
import { PageSkeleton, PageError } from '../../components/ui/PageStates';
import { downloadCsv } from '../../utils/csvExport';
import type { MemberStatus } from '../../data/membersDummy';

const STATUS_TABS = ['All', 'Active', 'Inactive', 'Suspended', 'Pending'];

function StatusBadge({ status }: { status: MemberStatus }) {
  const cls: Record<MemberStatus, string> = { Active: 'badge-blue', Inactive: 'badge-neutral', Suspended: 'badge-red', Pending: 'badge-yellow' };
  const dot: Record<MemberStatus, string> = { Active: 'bg-brand-700', Inactive: 'bg-ink-500', Suspended: 'bg-danger-700', Pending: 'bg-warning-700' };
  return <span className={cls[status]}><span className={`inline-block h-1.5 w-1.5 rounded-full ${dot[status]}`} />{status}</span>;
}

function StarRating({ value }: { value: number }) {
  const color = value >= 4.5 ? 'text-warning-500' : value >= 3.5 ? 'text-warning-600' : 'text-ink-400';
  return <span className={`text-sm font-semibold ${color}`}>★ {value.toFixed(1)}</span>;
}

export function MembersPage() {
  const { loading, error, members, reload, handleStatusChange, handleDelete } = useMembers();
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [menuOpenId, setMenuOpenId] = useState<string | null>(null);

  // Close row dropdown when clicking outside any menu
  function closeMenu() { setMenuOpenId(null); }

  if (loading) return <PageSkeleton />;
  if (error) return <PageError message={error} onRetry={reload} />;

  const filtered = members.filter((m) => {
    const matchSearch =
      m.name.toLowerCase().includes(search.toLowerCase()) ||
      m.email.toLowerCase().includes(search.toLowerCase()) ||
      m.sports.some(s => s.sport.toLowerCase().includes(search.toLowerCase()));
    return matchSearch && (statusFilter === 'All' || m.status === statusFilter);
  });

  function toggleSelect(id: string) {
    setSelectedIds((prev) => { const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n; });
  }
  function toggleAll() {
    setSelectedIds(selectedIds.size === filtered.length ? new Set() : new Set(filtered.map((m) => m.id)));
  }
  function handleBulkSuspend() {
    selectedIds.forEach((id) => handleStatusChange(id, 'Suspended'));
    setSelectedIds(new Set());
  }
  function handleExport() {
    downloadCsv(
      members.map((m) => ({ Name: m.name, Email: m.email, Role: m.role, Sports: m.sports.map(s => s.sport).join(', '), Status: m.status, Rating: m.rating, Joined: m.joinedDate })),
      'matchup-members.csv',
    );
  }

  const stats = [
    { label: 'Total Members', value: members.length, color: 'text-ink-900' },
    { label: 'Active',    value: members.filter((m) => m.status === 'Active').length,    color: 'text-brand-500' },
    { label: 'Suspended', value: members.filter((m) => m.status === 'Suspended').length, color: 'text-danger-500' },
    { label: 'Pending',   value: members.filter((m) => m.status === 'Pending').length,   color: 'text-warning-600' },
  ];

  return (
    <div className="page-container space-y-5" onClick={closeMenu}>

      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-ink-900 sm:text-2xl">Members Management</h1>
          <p className="mt-1 text-xs text-ink-600 sm:text-sm">Manage platform users, roles, and account status</p>
        </div>
        <div className="flex shrink-0 gap-2">
          <button onClick={handleExport} className="btn-outline rounded-lg px-3 py-1.5 text-sm">Export CSV</button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {stats.map((s) => (
          <div key={s.label} className="card py-4 text-center">
            <p className={`text-2xl font-bold ${s.color}`}>{s.value}</p>
            <p className="mt-1 text-xs text-ink-500">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Table panel */}
      <div className="panel overflow-hidden">
        <div className="flex flex-col gap-3 border-b border-ink-200 px-4 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <div className="flex flex-wrap gap-1">
            {STATUS_TABS.map((tab) => (
              <button key={tab} onClick={() => setStatusFilter(tab)} className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${statusFilter === tab ? 'bg-brand-500 text-white' : 'bg-ink-100 text-ink-600 hover:bg-ink-200'}`}>
                {tab}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2 rounded-full bg-ink-50 px-3 py-1.5 w-full sm:w-auto">
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><circle cx="6" cy="6" r="4" /><path d="M11 11l-2.5-2.5" /></svg>
            <input type="text" placeholder="Search members..." value={search} onChange={(e) => setSearch(e.target.value)} className="flex-1 bg-transparent text-[13px] text-ink-700 placeholder:text-ink-400 focus:outline-none sm:w-44" />
          </div>
        </div>

        {selectedIds.size > 0 && (
          <div className="flex items-center gap-3 border-b border-ink-200 bg-brand-50 px-6 py-2.5">
            <span className="text-xs font-semibold text-brand-700">{selectedIds.size} selected</span>
            <button onClick={handleBulkSuspend} className="text-xs font-semibold text-danger-500 hover:underline">Suspend selected</button>
            <button onClick={() => setSelectedIds(new Set())} className="text-xs font-semibold text-ink-500 hover:underline">Clear</button>
          </div>
        )}

        {/* Desktop table */}
        <div className="hidden overflow-x-auto md:block">
          <table className="w-full">
            <thead>
              <tr className="border-b border-ink-200 bg-ink-50">
                <th className="tbl-th w-8"><input type="checkbox" checked={selectedIds.size === filtered.length && filtered.length > 0} onChange={toggleAll} className="rounded" /></th>
                <th className="tbl-th">Member</th>
                <th className="tbl-th">Sport</th>
                <th className="tbl-th">Role</th>
                <th className="tbl-th">Activities</th>
                <th className="tbl-th">Rating</th>
                <th className="tbl-th">Joined</th>
                <th className="tbl-th">Status</th>
                <th className="tbl-th"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-ink-200">
              {filtered.map((m, i) => (
                <tr key={m.id} className={i % 2 === 0 ? 'bg-white' : 'bg-ink-50'}>
                  <td className="tbl-td"><input type="checkbox" checked={selectedIds.has(m.id)} onChange={() => toggleSelect(m.id)} className="rounded" /></td>
                  <td className="tbl-td">
                    <div className="flex items-center gap-3">
                      <img src={`https://api.dicebear.com/8.x/thumbs/svg?seed=${m.avatarSeed}`} alt={m.name} className="h-8 w-8 rounded-full bg-ink-200" />
                      <div>
                        <Link to={`/members/${m.id}`} className="font-semibold text-brand-500 hover:underline">
                          {m.name}
                        </Link>
                        <p className="text-xs text-ink-400">{m.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="tbl-td"><span className="rounded-md bg-ink-100 px-2 py-1 text-xs font-semibold text-ink-600">{m.sports[0]?.sport ?? '—'}</span></td>
                  <td className="tbl-td text-[13px] text-ink-700">{m.role}</td>
                  <td className="tbl-td">
                    <div className="text-[13px]">
                      <span className="font-medium text-ink-700">{m.activitiesJoined}</span>
                      <span className="text-ink-400"> joined</span>
                      {m.activitiesHosted > 0 && <><span className="text-ink-300 mx-1">·</span><span className="font-medium text-ink-700">{m.activitiesHosted}</span><span className="text-ink-400"> hosted</span></>}
                    </div>
                  </td>
                  <td className="tbl-td"><StarRating value={m.rating} /></td>
                  <td className="tbl-td text-[13px] text-ink-600">{m.joinedDate}</td>
                  <td className="tbl-td"><StatusBadge status={m.status} /></td>
                  <td className="tbl-td">
                    <div className="relative">
                      <button
                        onClick={() => setMenuOpenId(menuOpenId === m.id ? null : m.id)}
                        className="rounded-lg px-2 py-1 text-xs font-semibold text-ink-500 hover:bg-ink-100"
                      >
                        •••
                      </button>
                      {menuOpenId === m.id && (
                        <div className="absolute right-0 z-10 mt-1 w-40 rounded-xl border border-ink-200 bg-white py-1 shadow-panel">
                          {m.status !== 'Active'    && <button className="w-full px-4 py-2 text-left text-sm text-ink-700 hover:bg-ink-50" onClick={() => { handleStatusChange(m.id, 'Active');    setMenuOpenId(null); }}>Activate</button>}
                          {m.status !== 'Suspended' && <button className="w-full px-4 py-2 text-left text-sm text-warning-600 hover:bg-ink-50" onClick={() => { handleStatusChange(m.id, 'Suspended'); setMenuOpenId(null); }}>Suspend</button>}
                          <button className="w-full px-4 py-2 text-left text-sm text-danger-500 hover:bg-ink-50" onClick={() => { handleDelete(m.id); setMenuOpenId(null); }}>Remove</button>
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
          {filtered.map((m) => (
            <div key={m.id} className="px-4 py-3 space-y-2">
              <div className="flex items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <img src={`https://api.dicebear.com/8.x/thumbs/svg?seed=${m.avatarSeed}`} alt={m.name} className="h-8 w-8 rounded-full bg-ink-200" />
                  <div>
                    <p className="text-sm font-semibold text-ink-900">{m.name}</p>
                    <p className="text-xs text-ink-400">{m.email}</p>
                  </div>
                </div>
                <StatusBadge status={m.status} />
              </div>
              <div className="flex items-center justify-between text-xs text-ink-600">
                <span>{m.role} · {m.sports[0]?.sport ?? '—'}</span>
                <StarRating value={m.rating} />
              </div>
            </div>
          ))}
        </div>

        {filtered.length === 0 && <p className="py-12 text-center text-sm text-ink-400">No members match your search.</p>}
      </div>
    </div>
  );
}

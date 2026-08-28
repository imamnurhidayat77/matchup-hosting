import { useState } from 'react';
import { useBroadcasts } from '../../hooks/useBroadcasts';
import { PageSkeleton, PageError } from '../../components/ui/PageStates';
import type { BroadcastStatus, BroadcastAudience } from '../../data/broadcastsDummy';

function StatusBadge({ status }: { status: BroadcastStatus }) {
  const map: Record<BroadcastStatus, string> = {
    Sent:      'badge-green',
    Scheduled: 'badge-blue',
    Draft:     'badge-neutral',
  };
  return <span className={map[status]}>{status}</span>;
}

const AUDIENCE_OPTIONS: BroadcastAudience[] = ['All Users', 'Hosts Only', 'Players Only', 'Inactive Users'];

export function BroadcastsPage() {
  const { loading, error, broadcasts, reload, handleCreate, handleDelete } = useBroadcasts();
  const [showCompose, setShowCompose] = useState(false);
  const [form, setForm] = useState({ title: '', message: '', audience: 'All Users' as BroadcastAudience });
  const [activeTab, setActiveTab] = useState<BroadcastStatus | 'All'>('All');
  const [sending, setSending] = useState(false);

  if (loading) return <PageSkeleton rows={3} />;
  if (error) return <PageError message={error} onRetry={reload} />;

  const filtered = broadcasts.filter((b) => activeTab === 'All' || b.status === activeTab);

  async function handleSend() {
    if (!form.title.trim() || !form.message.trim()) return;
    setSending(true);
    try {
      await handleCreate({ title: form.title, message: form.message, audience: form.audience });
      setForm({ title: '', message: '', audience: 'All Users' });
      setShowCompose(false);
    } finally {
      setSending(false);
    }
  }

  async function handleSendDraft(id: string) {
    // Optimistically remove draft from list; real API will re-create as Sent.
    await handleDelete(id);
  }

  const TABS: Array<BroadcastStatus | 'All'> = ['All', 'Sent', 'Draft'];

  return (
    <div className="page-container space-y-5">

      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-ink-900 sm:text-2xl">Broadcasts</h1>
          <p className="mt-1 text-xs text-ink-600 sm:text-sm">Send announcements and targeted messages to platform users</p>
        </div>
        <button onClick={() => setShowCompose(true)} className="btn-primary rounded-lg px-4 py-2 text-sm self-start sm:self-auto">
          + New Broadcast
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-3">
        {[
          { label: 'Total Sent',   value: broadcasts.filter(b => b.status === 'Sent').length },
          { label: 'Scheduled',    value: broadcasts.filter(b => b.status === 'Scheduled').length },
        ].map((s) => (
          <div key={s.label} className="card py-4 text-center">
            <p className="text-2xl font-bold text-ink-900">{s.value}</p>
            <p className="mt-1 text-xs text-ink-500">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Compose panel (inline, shown on demand) */}
      {showCompose && (
        <div className="panel p-6 border-brand-200 border-2">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-base font-semibold text-ink-900">Compose Broadcast</h2>
            <button onClick={() => setShowCompose(false)} className="text-ink-400 hover:text-ink-700 text-lg leading-none">×</button>
          </div>
          <div className="space-y-4">
            <div>
              <label className="mb-1.5 block text-sm font-semibold text-ink-600">Title</label>
              <input className="input" placeholder="e.g. New Feature Announcement" value={form.title} onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))} />
            </div>
            <div>
              <label className="mb-1.5 block text-sm font-semibold text-ink-600">Message</label>
              <textarea className="input min-h-[100px] resize-none" placeholder="Write your broadcast message..." value={form.message} onChange={(e) => setForm((f) => ({ ...f, message: e.target.value }))} />
            </div>
            <div>
              <label className="mb-1.5 block text-sm font-semibold text-ink-600">Audience</label>
              <div className="flex flex-wrap gap-2">
                {AUDIENCE_OPTIONS.map((aud) => (
                  <button
                    key={aud}
                    onClick={() => setForm((f) => ({ ...f, audience: aud }))}
                    className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors border ${
                      form.audience === aud ? 'bg-brand-500 text-white border-brand-500' : 'bg-white text-ink-600 border-ink-200 hover:bg-ink-50'
                    }`}
                  >
                    {aud}
                  </button>
                ))}
              </div>
            </div>
            <div className="flex gap-2 pt-1">
              <button onClick={handleSend} disabled={sending} className="btn-primary rounded-xl px-5 py-2 text-sm disabled:opacity-50">{sending ? 'Sending…' : 'Send Now'}</button>
              <button onClick={() => setShowCompose(false)} className="btn-outline rounded-xl px-5 py-2 text-sm">Cancel</button>
            </div>
          </div>
        </div>
      )}

      {/* History panel */}
      <div className="panel overflow-hidden">
        <div className="flex items-center justify-between border-b border-ink-200 px-4 py-4 sm:px-6">
          <h2 className="text-base font-semibold text-ink-900">Broadcast History</h2>
          <div className="flex flex-wrap gap-1">
            {TABS.map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                  activeTab === tab ? 'bg-brand-500 text-white' : 'bg-ink-100 text-ink-600 hover:bg-ink-200'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>

        <div className="divide-y divide-ink-200">
          {filtered.map((b) => (
            <div key={b.id} className="px-4 py-4 sm:px-6">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-semibold text-ink-900">{b.title}</p>
                    <StatusBadge status={b.status} />
                    <span className="rounded-full bg-ink-100 px-2 py-0.5 text-[11px] font-medium text-ink-500">{b.audience}</span>
                  </div>
                  <p className="mt-1 text-sm text-ink-600 line-clamp-2">{b.message}</p>
                  <div className="mt-2 flex flex-wrap items-center gap-4 text-xs text-ink-400">
                    {b.sentAt && <span>Sent: {b.sentAt}</span>}
                    {b.scheduledAt && <span>Scheduled: {b.scheduledAt}</span>}
                    {b.recipients > 0 && <span>{b.recipients.toLocaleString()} recipients</span>}
                    {b.openRate && (
                      <span className="font-semibold text-brand-500">{b.openRate}% open rate</span>
                    )}
                  </div>
                </div>
                {b.status === 'Draft' && (
                  <div className="flex shrink-0 gap-1">
                    <button onClick={() => handleSendDraft(b.id)} className="btn-primary btn-sm">Send</button>
                  </div>
                )}
              </div>
            </div>
          ))}
          {filtered.length === 0 && <p className="py-12 text-center text-sm text-ink-400">No broadcasts found.</p>}
        </div>
      </div>
    </div>
  );
}

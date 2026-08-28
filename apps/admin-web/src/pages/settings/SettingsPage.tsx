import { useState } from 'react';

// ─── Types + persistence ──────────────────────────────────────────────────────

interface SettingsData {
  platformName: string;
  supportEmail: string;
  language: string;
  maintenanceMode: boolean;
  newRegistrations: boolean;
  autoFlagThreshold: number;
  autoSuspendThreshold: number;
  requireHostVerification: boolean;
  allowPaidActivities: boolean;
  maxFee: number;
  profanityFilter: boolean;
  alertNewReport: boolean;
  alertUrgentReport: boolean;
  dailySummaryEmail: boolean;
  alertNewHost: boolean;
  notifEmail: string;
}

const DEFAULTS: SettingsData = {
  platformName: 'MatchUp',
  supportEmail: 'support@matchup.app',
  language: 'English (US)',
  maintenanceMode: false,
  newRegistrations: true,
  autoFlagThreshold: 3,
  autoSuspendThreshold: 10,
  requireHostVerification: false,
  allowPaidActivities: true,
  maxFee: 50,
  profanityFilter: true,
  alertNewReport: true,
  alertUrgentReport: true,
  dailySummaryEmail: false,
  alertNewHost: true,
  notifEmail: 'admin@matchup.app',
};

const STORAGE_KEY = 'matchup_admin_settings';

function loadSettings(): SettingsData {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return { ...DEFAULTS, ...(JSON.parse(raw) as Partial<SettingsData>) };
  } catch {}
  return DEFAULTS;
}

function saveSettingsToStorage(s: SettingsData): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
}

// ─── Page ─────────────────────────────────────────────────────────────────────

type Tab = 'General' | 'Moderation' | 'Notifications' | 'API';
const TABS: Tab[] = ['General', 'Moderation', 'Notifications', 'API'];

export function SettingsPage() {
  const [activeTab, setActiveTab] = useState<Tab>('General');
  const [settings, setSettings] = useState<SettingsData>(loadSettings);
  const [saved, setSaved] = useState(false);

  function update<K extends keyof SettingsData>(key: K, value: SettingsData[K]) {
    setSettings((prev) => ({ ...prev, [key]: value }));
  }

  function handleSave() {
    saveSettingsToStorage(settings);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  }

  return (
    <div className="page-container space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-ink-900 sm:text-2xl">Settings</h1>
          <p className="mt-1 text-xs text-ink-600 sm:text-sm">Platform configuration, moderation rules, and API access</p>
        </div>
        <button
          onClick={handleSave}
          className={`btn-primary rounded-lg px-4 py-2 text-sm self-start sm:self-auto transition-all ${saved ? '!bg-success-500' : ''}`}
        >
          {saved ? '✓ Saved' : 'Save Changes'}
        </button>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[200px_1fr]">
        {/* Tab nav */}
        <nav className="panel flex lg:flex-col divide-x divide-ink-200 lg:divide-x-0 lg:divide-y overflow-x-auto lg:overflow-visible">
          {TABS.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex-1 lg:flex-none px-4 py-3 text-sm font-medium text-left whitespace-nowrap transition-colors ${
                activeTab === tab ? 'bg-brand-50 font-semibold text-brand-700 lg:border-l-2 lg:border-brand-500' : 'text-ink-600 hover:bg-ink-50'
              }`}
            >
              {tab}
            </button>
          ))}
        </nav>

        {/* Content */}
        <div className="panel p-6">
          {activeTab === 'General' && (
            <div className="space-y-6">
              <h2 className="text-base font-semibold text-ink-900">General Configuration</h2>
              <SettingRow label="Platform Name" sub="Public name shown to all users">
                <input className="input max-w-sm" value={settings.platformName} onChange={(e) => update('platformName', e.target.value)} />
              </SettingRow>
              <SettingRow label="Support Email" sub="Contact address for user queries">
                <input className="input max-w-sm" type="email" value={settings.supportEmail} onChange={(e) => update('supportEmail', e.target.value)} />
              </SettingRow>
              <SettingRow label="Default Language" sub="Platform-wide default locale">
                <select className="input max-w-xs" value={settings.language} onChange={(e) => update('language', e.target.value)}>
                  <option>English (US)</option>
                  <option>Bahasa Indonesia</option>
                  <option>Spanish</option>
                </select>
              </SettingRow>
              <SettingRow label="Maintenance Mode" sub="Take the platform offline for all users">
                <Toggle checked={settings.maintenanceMode} onChange={(v) => update('maintenanceMode', v)} />
              </SettingRow>
              <SettingRow label="New Registrations" sub="Allow new users to sign up">
                <Toggle checked={settings.newRegistrations} onChange={(v) => update('newRegistrations', v)} />
              </SettingRow>
            </div>
          )}

          {activeTab === 'Moderation' && (
            <div className="space-y-6">
              <h2 className="text-base font-semibold text-ink-900">Moderation Rules</h2>
              <SettingRow label="Auto-flag Threshold" sub="Number of reports before auto-flagging content">
                <input className="input max-w-[120px]" type="number" value={settings.autoFlagThreshold} min={1} onChange={(e) => update('autoFlagThreshold', Number(e.target.value))} />
              </SettingRow>
              <SettingRow label="Auto-suspend Threshold" sub="Reports needed to auto-suspend a user">
                <input className="input max-w-[120px]" type="number" value={settings.autoSuspendThreshold} min={1} onChange={(e) => update('autoSuspendThreshold', Number(e.target.value))} />
              </SettingRow>
              <SettingRow label="Require Host Verification" sub="Hosts must verify identity before creating activities">
                <Toggle checked={settings.requireHostVerification} onChange={(v) => update('requireHostVerification', v)} />
              </SettingRow>
              <SettingRow label="Allow Paid Activities" sub="Hosts can charge participants a fee">
                <Toggle checked={settings.allowPaidActivities} onChange={(v) => update('allowPaidActivities', v)} />
              </SettingRow>
              <SettingRow label="Max Fee per Activity (USD)" sub="Cap on how much hosts can charge">
                <input className="input max-w-[120px]" type="number" value={settings.maxFee} min={0} onChange={(e) => update('maxFee', Number(e.target.value))} />
              </SettingRow>
              <SettingRow label="Profanity Filter" sub="Auto-detect and block inappropriate content">
                <Toggle checked={settings.profanityFilter} onChange={(v) => update('profanityFilter', v)} />
              </SettingRow>
            </div>
          )}

          {activeTab === 'Notifications' && (
            <div className="space-y-6">
              <h2 className="text-base font-semibold text-ink-900">Admin Notifications</h2>
              <SettingRow label="New Report Alert" sub="Email when a new report is filed">
                <Toggle checked={settings.alertNewReport} onChange={(v) => update('alertNewReport', v)} />
              </SettingRow>
              <SettingRow label="Urgent Report Alert" sub="Instant notification for urgent reports">
                <Toggle checked={settings.alertUrgentReport} onChange={(v) => update('alertUrgentReport', v)} />
              </SettingRow>
              <SettingRow label="Daily Summary Email" sub="Receive a daily digest of platform activity">
                <Toggle checked={settings.dailySummaryEmail} onChange={(v) => update('dailySummaryEmail', v)} />
              </SettingRow>
              <SettingRow label="New Host Registration" sub="Notify when a host applies for verification">
                <Toggle checked={settings.alertNewHost} onChange={(v) => update('alertNewHost', v)} />
              </SettingRow>
              <SettingRow label="Notification Email" sub="Where admin alerts are sent">
                <input className="input max-w-sm" type="email" value={settings.notifEmail} onChange={(e) => update('notifEmail', e.target.value)} />
              </SettingRow>
            </div>
          )}

          {activeTab === 'API' && <ApiSettings />}
        </div>
      </div>
    </div>
  );
}

// ─── API settings (read-only display) ─────────────────────────────────────────

function ApiSettings() {
  const [revealed, setRevealed] = useState(false);
  return (
    <div className="space-y-6">
      <h2 className="text-base font-semibold text-ink-900">API Access</h2>
      <SettingRow label="API Base URL" sub="Current backend endpoint">
        <div className="rounded-xl border border-ink-200 bg-ink-50 px-4 py-2.5 text-sm font-mono text-ink-700 max-w-sm">
          {import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:4000'}
        </div>
      </SettingRow>
      <SettingRow label="Admin API Key" sub="Use in Authorization header for API calls">
        <div className="flex items-center gap-2 max-w-sm">
          <div className="flex-1 rounded-xl border border-ink-200 bg-ink-50 px-4 py-2.5 text-sm font-mono text-ink-700 overflow-hidden">
            {revealed ? 'sk_admin_x7Kp3mN8vQzL2wRt' : '••••••••••••••••••••'}
          </div>
          <button onClick={() => setRevealed((v) => !v)} className="btn-outline rounded-xl px-3 py-2.5 text-xs shrink-0">
            {revealed ? 'Hide' : 'Show'}
          </button>
        </div>
      </SettingRow>
      <div className="rounded-xl border border-brand-200 bg-brand-50 p-4 text-sm text-brand-700">
        <p className="font-semibold">Switch to real API</p>
        <p className="mt-1 text-xs text-brand-600">Set <code className="rounded bg-brand-100 px-1">VITE_USE_MOCK_API=false</code> in your <code className="rounded bg-brand-100 px-1">.env</code> file and restart the dev server.</p>
        <p className="mt-2 text-xs text-brand-600">Current mode: <span className="font-semibold">{(import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true' ? 'Mock data' : 'Live API'}</span></p>
      </div>
    </div>
  );
}

// ─── Shared primitives ────────────────────────────────────────────────────────

function SettingRow({ label, sub, children }: { label: string; sub: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-b border-ink-100 pb-5 last:border-b-0 last:pb-0">
      <div>
        <p className="text-sm font-semibold text-ink-900">{label}</p>
        <p className="text-xs text-ink-500">{sub}</p>
      </div>
      <div className="shrink-0">{children}</div>
    </div>
  );
}

function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-brand-400 focus:ring-offset-2 ${checked ? 'bg-brand-500' : 'bg-ink-300'}`}
    >
      <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${checked ? 'translate-x-6' : 'translate-x-1'}`} />
    </button>
  );
}

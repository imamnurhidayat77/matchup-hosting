import { useState } from 'react';
import type { ReactNode } from 'react';
import { Sidebar, MobileDrawer } from './Sidebar';

export function DashboardShell({ children }: { children: ReactNode }) {
  const [drawerOpen, setDrawerOpen] = useState(false);

  return (
    // h-screen + overflow-hidden pin everything to viewport — sidebar and
    // main content column both fill the full height with no blank gap below.
    <div className="flex h-screen w-full overflow-hidden">
      {/* Desktop sidebar — sticky, full height */}
      <Sidebar />

      {/* Mobile drawer */}
      <MobileDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} />

      {/* Main column: topbar (mobile) + scrollable content */}
      <div className="flex min-w-0 flex-1 flex-col overflow-hidden">
        {/* Mobile topbar */}
        <header className="flex h-14 shrink-0 items-center gap-3 border-b border-ink-200 bg-white px-4 md:hidden">
          <button
            onClick={() => setDrawerOpen(true)}
            className="rounded-md p-1.5 text-ink-600 hover:bg-ink-100"
            aria-label="Open menu"
          >
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round">
              <path d="M3 5h14M3 10h14M3 15h14" />
            </svg>
          </button>
          <div className="flex items-center gap-2">
            <div className="flex h-6 w-6 shrink-0 overflow-hidden rounded">
              <img src="/logo-badge.png" alt="MatchUp logo" className="h-full w-full object-cover" />
            </div>
            <span className="text-sm font-bold text-ink-900">MatchUp Admin</span>
          </div>
        </header>

        {/* Scrollable page content */}
        <main className="flex-1 overflow-y-auto bg-ink-50">{children}</main>
      </div>
    </div>
  );
}

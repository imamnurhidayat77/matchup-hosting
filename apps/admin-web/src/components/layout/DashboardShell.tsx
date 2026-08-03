import type { ReactNode } from 'react';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';

export function DashboardShell({ children }: { children: ReactNode }) {
  return (
    <div className="flex h-full w-full">
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Topbar />
        <div className="flex-1 overflow-auto">{children}</div>
      </div>
    </div>
  );
}
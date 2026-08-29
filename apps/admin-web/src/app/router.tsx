import { createBrowserRouter, RouterProvider } from 'react-router-dom';
import { DashboardShell } from '../components/layout/DashboardShell';
import { RequireAuth } from '../components/auth/RequireAuth';
import { DashboardPage } from '../pages/dashboard/DashboardPage';
import { LoginPage } from '../pages/login/LoginPage';
import { MembersPage } from '../pages/members/MembersPage';
import { MemberDetailPage } from '../pages/members/MemberDetailPage';
import { ActivitiesPage } from '../pages/activities/ActivitiesPage';
import { ActivityDetailPage } from '../pages/activities/ActivityDetailPage';
import { ReportsPage } from '../pages/reports/ReportsPage';
import { BroadcastsPage } from '../pages/broadcasts/BroadcastsPage';
import { AnalyticsPage } from '../pages/analytics/AnalyticsPage';
import { SettingsPage } from '../pages/settings/SettingsPage';
import { SportsPage } from '../pages/sports/SportsPage';
import { NotFoundPage } from '../pages/NotFoundPage';

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <RequireAuth>
      <DashboardShell>{children}</DashboardShell>
    </RequireAuth>
  );
}

const router = createBrowserRouter([
  { path: '/login',            element: <LoginPage /> },
  { path: '/',                 element: <Shell><DashboardPage /></Shell> },
  { path: '/members',          element: <Shell><MembersPage /></Shell> },
  { path: '/members/:id',      element: <Shell><MemberDetailPage /></Shell> },
  { path: '/activities',       element: <Shell><ActivitiesPage /></Shell> },
  { path: '/activities/:id',   element: <Shell><ActivityDetailPage /></Shell> },
  { path: '/reports',          element: <Shell><ReportsPage /></Shell> },
  { path: '/broadcasts',       element: <Shell><BroadcastsPage /></Shell> },
  { path: '/sports',           element: <Shell><SportsPage /></Shell> },
  { path: '/analytics',        element: <Shell><AnalyticsPage /></Shell> },
  { path: '/settings',         element: <Shell><SettingsPage /></Shell> },
  { path: '*',                 element: <Shell><NotFoundPage /></Shell> },
]);

export function AppRouter() {
  return <RouterProvider router={router} />;
}

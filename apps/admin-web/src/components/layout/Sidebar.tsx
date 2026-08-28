import { NavLink, useNavigate } from 'react-router-dom';
import { cn } from '../../utils/cn';
import { useAuth } from '../../context/AuthContext';

// ─── Icons ────────────────────────────────────────────────────────────────────

function IconDashboard() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <rect x="1" y="1" width="7" height="7" rx="1.5" />
      <rect x="10" y="1" width="7" height="7" rx="1.5" />
      <rect x="1" y="10" width="7" height="7" rx="1.5" />
      <rect x="10" y="10" width="7" height="7" rx="1.5" />
    </svg>
  );
}
function IconUsers() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="7" cy="5.5" r="3" /><path d="M1 16c0-3.314 2.686-5 6-5s6 1.686 6 5" />
      <path d="M12 3a3 3 0 010 5" /><path d="M17 16c0-2.5-1.5-4-3-4.5" />
    </svg>
  );
}
function IconCalendar() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <rect x="1" y="3" width="16" height="14" rx="2" /><path d="M1 7h16" />
      <path d="M5 1v4M13 1v4" />
    </svg>
  );
}
function IconBell() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 1a5 5 0 015 5c0 5 2 6 2 6H2s2-1 2-6a5 5 0 015-5z" />
      <path d="M7.27 15.5a2 2 0 003.46 0" />
    </svg>
  );
}
function IconAirplay() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 14H2a1 1 0 01-1-1V3a1 1 0 011-1h14a1 1 0 011 1v10a1 1 0 01-1 1h-3" />
      <path d="M9 10l-4 7h8l-4-7z" />
    </svg>
  );
}
function IconChart() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="1,13 6,8 10,11 17,4" /><path d="M13 4h4v4" />
    </svg>
  );
}
function IconSettings() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="9" cy="9" r="2.5" />
      <path d="M9 1v2M9 15v2M1 9h2M15 9h2M3.22 3.22l1.42 1.42M13.36 13.36l1.42 1.42M3.22 14.78l1.42-1.42M13.36 4.64l1.42-1.42" />
    </svg>
  );
}

// ─── Nav config ───────────────────────────────────────────────────────────────

function IconSports() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="9" cy="9" r="7.5" />
      <path d="M9 1.5a7.5 7.5 0 010 15M1.5 9h15" />
      <path d="M3.5 4.5C5.5 5.5 7 7 7 9s-1.5 3.5-3.5 4.5M14.5 4.5C12.5 5.5 11 7 11 9s1.5 3.5 3.5 4.5" />
    </svg>
  );
}

const NAV_ITEMS = [
  { to: '/',           label: 'Dashboard',  icon: <IconDashboard />, end: true  },
  { to: '/members',    label: 'Members',    icon: <IconUsers />                  },
  { to: '/activities', label: 'Activities', icon: <IconCalendar />               },
  { to: '/reports',    label: 'Reports',    icon: <IconBell />,   badge: '14'    },
  { to: '/broadcasts', label: 'Broadcasts', icon: <IconAirplay />                },
  { to: '/sports',     label: 'Sports',     icon: <IconSports />                 },
  { to: '/analytics',  label: 'Analytics',  icon: <IconChart />                  },
  { to: '/settings',   label: 'Settings',   icon: <IconSettings />               },
] as const;

// ─── Inner sidebar content ────────────────────────────────────────────────────

function SidebarContent({ onNavigate }: { onNavigate?: () => void }) {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();

  async function handleSignOut() {
    await signOut();
    navigate('/login', { replace: true });
  }
  return (
    <div className="flex h-full flex-col">
      {/* Logo */}
      <div className="flex h-[85px] shrink-0 items-center gap-3 px-6">
        <div className="flex h-8 w-8 shrink-0 overflow-hidden rounded-lg">
          <img src="/logo-badge.png" alt="MatchUp logo" className="h-full w-full object-cover" />
        </div>
        <div>
          <p className="text-[18px] font-bold leading-none text-ink-900">MatchUp</p>
          <p className="mt-0.5 text-[11px] font-semibold leading-none tracking-wide text-brand-400">
            ADMIN CONSOLE
          </p>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 space-y-0.5 overflow-y-auto px-4 py-2">
        {NAV_ITEMS.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={'end' in item ? item.end : undefined}
            onClick={onNavigate}
            className={({ isActive }) =>
              cn(
                'flex h-10 w-full items-center gap-3 rounded-[10px] px-3 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-[#eff6ff] font-semibold text-brand-700'
                  : 'text-ink-600 hover:bg-ink-50 hover:text-ink-900',
              )
            }
          >
            {({ isActive }) => (
              <>
                <span className={isActive ? 'text-brand-700' : 'text-ink-400'}>
                  {item.icon}
                </span>
                <span className="flex-1">{item.label}</span>
                {'badge' in item && item.badge && (
                  <span className="flex h-[17px] min-w-[28px] items-center justify-center rounded-full bg-danger-500 px-1.5 text-[11px] font-semibold text-white">
                    {item.badge}
                  </span>
                )}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Admin footer */}
      <div className="flex shrink-0 items-center gap-3 border-t border-ink-200 px-4 py-4">
        <div className="h-9 w-9 shrink-0 overflow-hidden rounded-full bg-ink-200">
          <img
            src={`https://api.dicebear.com/8.x/thumbs/svg?seed=${user && typeof user === 'object' ? user.avatarSeed : 'Devon'}`}
            alt="Avatar"
            className="h-full w-full object-cover"
          />
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-ink-900">
            {user && typeof user === 'object' ? user.name : '—'}
          </p>
          <p className="truncate text-xs text-ink-400">
            {user && typeof user === 'object' ? user.role : ''}
          </p>
        </div>
        <button
          onClick={handleSignOut}
          className="shrink-0 rounded-md p-1.5 text-ink-400 hover:bg-ink-100 hover:text-danger-500 transition-colors"
          aria-label="Sign out"
          title="Sign out"
        >
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
            <path d="M6 2H3a1 1 0 00-1 1v10a1 1 0 001 1h3" />
            <path d="M11 11l3-3-3-3M14 8H6" />
          </svg>
        </button>
      </div>
    </div>
  );
}

// ─── Desktop sidebar ──────────────────────────────────────────────────────────

export function Sidebar() {
  return (
    <aside className="hidden h-full w-[260px] shrink-0 border-r border-ink-200 bg-white md:flex md:flex-col">
      <SidebarContent />
    </aside>
  );
}

// ─── Mobile drawer overlay ────────────────────────────────────────────────────

export function MobileDrawer({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  return (
    <>
      {/* Scrim */}
      <div
        className={cn(
          'fixed inset-0 z-40 bg-ink-900/50 transition-opacity md:hidden',
          open ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none',
        )}
        onClick={onClose}
        aria-hidden
      />
      {/* Drawer panel */}
      <aside
        className={cn(
          'fixed inset-y-0 left-0 z-50 flex w-[260px] flex-col border-r border-ink-200 bg-white transition-transform duration-300 md:hidden',
          open ? 'translate-x-0' : '-translate-x-full',
        )}
        aria-label="Navigation"
      >
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute right-3 top-3 rounded-md p-1.5 text-ink-400 hover:bg-ink-100 hover:text-ink-700"
          aria-label="Close menu"
        >
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
            <path d="M4 4l10 10M14 4L4 14" />
          </svg>
        </button>
        <SidebarContent onNavigate={onClose} />
      </aside>
    </>
  );
}

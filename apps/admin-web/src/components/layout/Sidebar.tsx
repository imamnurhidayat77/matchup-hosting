import { NavLink } from 'react-router-dom';
import { cn } from '../../utils/cn';

const NAV_ITEMS = [
  { to: '/', label: 'Dashboard' },
  { to: '/members', label: 'Members' },
  { to: '/activities', label: 'Activities' },
  { to: '/reports', label: 'Reports' },
  { to: '/broadcasts', label: 'Broadcasts' },
] as const;

export function Sidebar() {
  return (
    <aside className="hidden w-sidebar shrink-0 border-r border-ink-200 bg-white md:block">
      <div className="flex h-topbar items-center border-b border-ink-200 px-6">
        <span className="text-lg font-semibold text-brand-600">MatchUp</span>
      </div>
      <nav className="px-2 py-4">
        {NAV_ITEMS.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            className={({ isActive }) =>
              cn(
                'block rounded-md px-3 py-2 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-brand-50 text-brand-700'
                  : 'text-ink-700 hover:bg-ink-100',
              )
            }
          >
            {item.label}
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}
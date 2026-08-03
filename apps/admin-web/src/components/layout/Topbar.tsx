import { Link } from 'react-router-dom';

export function Topbar() {
  return (
    <header className="flex h-topbar items-center justify-between border-b border-ink-200 bg-white px-6">
      <div className="text-sm text-ink-500">MatchUp Admin</div>
      <div className="flex items-center gap-3">
        <Link to="/login" className="text-sm font-medium text-ink-700 hover:text-brand-600">
          Sign in
        </Link>
      </div>
    </header>
  );
}
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import type { ReactNode } from 'react';
import {
  loadSession,
  refreshStoredToken,
  signIn as authSignIn,
  signOut as authSignOut,
  subscribeSessionRefresh,
} from '../services/authService';
import type { AdminUser } from '../services/authService';
import { onUnauthorized } from '../services/api';

// ─── Types ────────────────────────────────────────────────────────────────────

interface AuthState {
  /** null while checking session; AdminUser when signed in; false when signed out. */
  user: AdminUser | null | false;
  loading: boolean;
  /** True when the last sign-out was an automatic logout (expired token). */
  sessionExpired: boolean;
}

interface AuthContextValue extends AuthState {
  signIn: (email: string, password: string, remember: boolean) => Promise<void>;
  signOut: () => Promise<void>;
  isAuthenticated: boolean;
}

// ─── Context ──────────────────────────────────────────────────────────────────

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null | false>(null); // null = checking
  const [loading, setLoading] = useState(false);
  const [sessionExpired, setSessionExpired] = useState(false);
  // Prevents concurrent 401s from interleaving duplicate sign-outs.
  const autoLogoutInFlight = useRef(false);
  // Suppresses auto-logout while a sign-in attempt is in flight, so a
  // rejected /me check during sign-in surfaces its own error instead of
  // flipping the "session expired" banner.
  const signingIn = useRef(false);

  // Restore session from storage on mount.
  useEffect(() => {
    const session = loadSession();
    setUser(session ? session.user : false);
  }, []);

  // H2 fix: keep the stored Firebase ID token fresh. The subscription
  // persists hourly SDK refreshes; the one-shot rehydrates the token
  // after a reload (SDK session survives in browser persistence while
  // our stored copy may be hours old). Runs once — independent of the
  // user state above so a refreshed token lands before first use.
  useEffect(() => {
    const unsubscribe = subscribeSessionRefresh();
    void refreshStoredToken();
    return unsubscribe;
  }, []);

  const signIn = useCallback(
    async (email: string, password: string, remember: boolean) => {
      signingIn.current = true;
      setLoading(true);
      try {
        const session = await authSignIn(email, password, remember);
        setSessionExpired(false);
        setUser(session.user);
      } finally {
        signingIn.current = false;
        setLoading(false);
      }
    },
    [],
  );

  const signOut = useCallback(async () => {
    await authSignOut();
    setSessionExpired(false);
    setUser(false);
  }, []);

  // Unconditional auto logout — marks the session as expired so the
  // login page can explain why the user was signed out. Idempotent:
  // concurrent triggers collapse into a single sign-out.
  const performAutoLogout = useCallback(async () => {
    if (autoLogoutInFlight.current) return;
    autoLogoutInFlight.current = true;
    try {
      await authSignOut();
      setSessionExpired(true);
      setUser(false);
    } finally {
      autoLogoutInFlight.current = false;
    }
  }, []);

  // Guarded variant for external triggers (401 responses, storage
  // events). No-ops when there is no active session (e.g. already
  // signed out) or while a sign-in attempt is in flight, so a rejected
  // /me check during sign-in surfaces its own error instead of
  // flipping the "session expired" banner.
  const autoLogoutIfSession = useCallback(async () => {
    if (signingIn.current) return;
    if (!loadSession()) return;
    await performAutoLogout();
  }, [performAutoLogout]);

  // Any 401/UNAUTHORIZED from apiFetch → auto logout.
  useEffect(
    () => onUnauthorized(() => void autoLogoutIfSession()),
    [autoLogoutIfSession],
  );

  // Local session TTL (8h / 30d remember) → auto logout even with no
  // API traffic (e.g. tab left open overnight).
  useEffect(() => {
    if (!user) return;
    const session = loadSession();
    // Session file already expired/removed (another tab signed out).
    if (!session) {
      void performAutoLogout();
      return;
    }
    const delay = session.expiresAt - Date.now();
    if (delay <= 0) {
      void performAutoLogout();
      return;
    }
    const timer = setTimeout(() => void performAutoLogout(), delay);
    return () => clearTimeout(timer);
  }, [user, performAutoLogout]);

  // Another tab signed out / cleared storage → follow along.
  useEffect(() => {
    const onStorage = (e: StorageEvent) => {
      if (e.key === null || e.key === 'matchup_admin_session') {
        void autoLogoutIfSession();
      }
    };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, [autoLogoutIfSession]);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      loading,
      sessionExpired,
      signIn,
      signOut,
      isAuthenticated: !!user,
    }),
    [user, loading, sessionExpired, signIn, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// ─── Hook ─────────────────────────────────────────────────────────────────────

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
}

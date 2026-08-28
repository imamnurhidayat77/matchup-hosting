import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import type { ReactNode } from 'react';
import {
  loadSession,
  signIn as authSignIn,
  signOut as authSignOut,
} from '../services/authService';
import type { AdminUser } from '../services/authService';

// ─── Types ────────────────────────────────────────────────────────────────────

interface AuthState {
  /** null while checking session; AdminUser when signed in; false when signed out. */
  user: AdminUser | null | false;
  loading: boolean;
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

  // Restore session from storage on mount.
  useEffect(() => {
    const session = loadSession();
    setUser(session ? session.user : false);
  }, []);

  const signIn = useCallback(
    async (email: string, password: string, remember: boolean) => {
      setLoading(true);
      try {
        const session = await authSignIn(email, password, remember);
        setUser(session.user);
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  const signOut = useCallback(async () => {
    await authSignOut();
    setUser(false);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      loading,
      signIn,
      signOut,
      isAuthenticated: !!user,
    }),
    [user, loading, signIn, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// ─── Hook ─────────────────────────────────────────────────────────────────────

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
}

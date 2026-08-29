/**
 * Auth service.
 *
 * HOW TO SWITCH TO REAL API:
 *   Set VITE_USE_MOCK_API=false in .env.
 *
 * Expected endpoints:
 *   POST /api/v1/auth/admin/sign-in   { email, password } → { token, user }
 *   POST /api/v1/auth/admin/sign-out  → void
 *   GET  /api/v1/auth/admin/me        → AdminUser
 */
import { apiFetch } from './api';

export interface AdminUser {
  id: string;
  name: string;
  email: string;
  role: string;
  avatarSeed: string;
}

export interface AuthSession {
  token: string;
  user: AdminUser;
  /** Unix ms timestamp when the session expires. */
  expiresAt: number;
}

// ─── Session storage ──────────────────────────────────────────────────────────

const SESSION_KEY = 'matchup_admin_session';
// Default: 8h session; "remember me" extends to 30 days.
const SESSION_TTL_DEFAULT = 8 * 60 * 60 * 1000;
const SESSION_TTL_REMEMBER = 30 * 24 * 60 * 60 * 1000;

export function saveSession(session: AuthSession, remember: boolean): void {
  const store = remember ? localStorage : sessionStorage;
  // Always clear the other store to avoid stale sessions.
  localStorage.removeItem(SESSION_KEY);
  sessionStorage.removeItem(SESSION_KEY);
  store.setItem(SESSION_KEY, JSON.stringify(session));
}

export function loadSession(): AuthSession | null {
  const raw =
    localStorage.getItem(SESSION_KEY) ??
    sessionStorage.getItem(SESSION_KEY);
  if (!raw) return null;
  try {
    const session = JSON.parse(raw) as AuthSession;
    if (Date.now() > session.expiresAt) {
      clearSession();
      return null;
    }
    return session;
  } catch {
    return null;
  }
}

export function clearSession(): void {
  localStorage.removeItem(SESSION_KEY);
  sessionStorage.removeItem(SESSION_KEY);
}

// ─── Dummy credentials ────────────────────────────────────────────────────────

/**
 * Demo admin accounts — credentials are intentionally visible in the UI
 * so reviewers/testers can sign in without asking for credentials.
 * Remove this file from production deployments when real auth is wired.
 */
export const DEMO_CREDENTIALS = [
  {
    email: 'admin@matchup.app',
    password: 'Admin@2026',
    user: {
      id: 'admin-1',
      name: 'Devon Lane',
      email: 'admin@matchup.app',
      role: 'Super Admin',
      avatarSeed: 'Devon',
    } satisfies AdminUser,
  },
] as const;

// ─── Sign in ──────────────────────────────────────────────────────────────────

const USE_MOCK = (import.meta.env.VITE_USE_MOCK_API ?? 'true') === 'true';

export interface SignInResult {
  session: AuthSession;
}

export class AuthError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AuthError';
  }
}

export async function signIn(
  email: string,
  password: string,
  remember: boolean,
): Promise<AuthSession> {
  if (USE_MOCK) {
    await new Promise((r) => setTimeout(r, 600)); // simulate latency

    const found = DEMO_CREDENTIALS.find(
      (c) => c.email.toLowerCase() === email.toLowerCase() && c.password === password,
    );
    if (!found) {
      throw new AuthError('Invalid email or password. Check the demo credentials below.');
    }

    const ttl = remember ? SESSION_TTL_REMEMBER : SESSION_TTL_DEFAULT;
    const session: AuthSession = {
      token: `mock_token_${found.user.id}_${Date.now()}`,
      user: found.user,
      expiresAt: Date.now() + ttl,
    };
    saveSession(session, remember);
    return session;
  }

  // ── Real API path ──────────────────────────────────────────────────────────
  const res = await apiFetch<{ token: string; user: AdminUser }>(
    '/api/v1/auth/admin/sign-in',
    { method: 'POST', body: JSON.stringify({ email, password }) },
  );
  if (!res.ok) throw new AuthError(res.error.message);

  const ttl = remember ? SESSION_TTL_REMEMBER : SESSION_TTL_DEFAULT;
  const session: AuthSession = {
    token: res.data.token,
    user: res.data.user,
    expiresAt: Date.now() + ttl,
  };
  saveSession(session, remember);
  return session;
}

export async function signOut(): Promise<void> {
  const session = loadSession();
  clearSession();
  if (!USE_MOCK && session) {
    // Fire-and-forget — don't block UI on sign-out API call.
    apiFetch('/api/v1/auth/admin/sign-out', { method: 'POST' }).catch(() => {});
  }
}

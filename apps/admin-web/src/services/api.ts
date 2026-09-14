/**
 * API client skeleton.
 *
 * Real implementation (auth header injection, refresh tokens, error
 * normalisation) will be added during the MVP phase. For now, this
 * module exposes a tiny `apiFetch` helper that points at the configured
 * base URL and returns JSON.
 */

const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:4000';

export interface ApiSuccess<T> {
  ok: true;
  data: T;
}
export interface ApiFailure {
  ok: false;
  error: { code: string; message: string; details?: unknown };
}
export type ApiResponse<T> = ApiSuccess<T> | ApiFailure;

/**
 * Firebase ID token for admin-only routes, stored by the auth service
 * after Firebase sign-in. Attached as a Bearer token when present;
 * mock mode never needs it.
 */
const ADMIN_TOKEN_KEY = 'admin_id_token';

function adminIdToken(): string | null {
  try {
    return localStorage.getItem(ADMIN_TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setAdminIdToken(token: string): void {
  try {
    localStorage.setItem(ADMIN_TOKEN_KEY, token);
  } catch {
    // Storage unavailable — requests simply go unauthenticated.
  }
}

export function clearAdminIdToken(): void {
  try {
    localStorage.removeItem(ADMIN_TOKEN_KEY);
  } catch {
    // Ignore.
  }
}

export async function apiFetch<T>(
  path: string,
  init: RequestInit = {},
): Promise<ApiResponse<T>> {
  const url = `${BASE_URL}${path.startsWith('/') ? path : `/${path}`}`;
  const token = adminIdToken();
  try {
    const response = await fetch(url, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...(token != null && token !== '' ? { Authorization: `Bearer ${token}` } : {}),
        ...(init.headers ?? {}),
      },
    });
    const body = (await response.json()) as ApiResponse<T>;
    return body;
  } catch (err) {
    return {
      ok: false,
      error: {
        code: 'NETWORK_ERROR',
        message: err instanceof Error ? err.message : 'Network error',
      },
    };
  }
}

export { BASE_URL };
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
 * Firebase ID token for admin-only routes, stored by hand (see
 * reportsService header comment). Attached as a Bearer token when
 * present; mock mode never needs it.
 */
function adminIdToken(): string | null {
  try {
    return localStorage.getItem('admin_id_token');
  } catch {
    return null;
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
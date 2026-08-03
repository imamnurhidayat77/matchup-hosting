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

export async function apiFetch<T>(
  path: string,
  init: RequestInit = {},
): Promise<ApiResponse<T>> {
  const url = `${BASE_URL}${path.startsWith('/') ? path : `/${path}`}`;
  try {
    const response = await fetch(url, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
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
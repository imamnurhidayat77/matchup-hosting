import { useEffect, useState } from 'react';
import { apiFetch, type ApiResponse } from '../services/api';

/** Minimal useApi hook — fetches data on mount and exposes loading/error. */
export function useApi<T>(path: string): {
  data: T | null;
  loading: boolean;
  error: string | null;
} {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    apiFetch<T>(path)
      .then((result: ApiResponse<T>) => {
        if (cancelled) return;
        if (result.ok) {
          setData(result.data);
          setError(null);
        } else {
          setError(result.error.message);
        }
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : 'Unknown error');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [path]);

  return { data, loading, error };
}
import { useCallback, useEffect, useReducer, useState } from 'react';
import { fetchAnalytics } from '../services/analyticsService';
import type { AnalyticsData, AnalyticsRange } from '../services/analyticsService';

type State =
  | { status: 'idle' | 'loading' }
  | { status: 'error'; message: string }
  | { status: 'success'; data: AnalyticsData };

type Action =
  | { type: 'FETCH_START' }
  | { type: 'FETCH_SUCCESS'; data: AnalyticsData }
  | { type: 'FETCH_ERROR'; message: string };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'FETCH_START':   return { status: 'loading' };
    case 'FETCH_SUCCESS': return { status: 'success', data: action.data };
    case 'FETCH_ERROR':   return { status: 'error', message: action.message };
    default: return state;
  }
}

export function useAnalytics() {
  const [range, setRange] = useState<AnalyticsRange>('7d');
  const [state, dispatch] = useReducer(reducer, { status: 'idle' });

  const load = useCallback(async (r: AnalyticsRange) => {
    dispatch({ type: 'FETCH_START' });
    try {
      const data = await fetchAnalytics(r);
      dispatch({ type: 'FETCH_SUCCESS', data });
    } catch (err) {
      dispatch({ type: 'FETCH_ERROR', message: err instanceof Error ? err.message : 'Failed to load analytics' });
    }
  }, []);

  useEffect(() => { load(range); }, [load, range]);

  return {
    loading: state.status === 'idle' || state.status === 'loading',
    error: state.status === 'error' ? state.message : null,
    data: state.status === 'success' ? state.data : null,
    range,
    setRange: (r: AnalyticsRange) => { setRange(r); },
    reload: () => load(range),
  };
}

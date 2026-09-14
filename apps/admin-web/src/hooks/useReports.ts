import { useCallback, useEffect, useReducer } from 'react';
import { fetchReports, reportAction } from '../services/reportsService';
import type { Report, ReportStatus, ReportAction } from '../services/reportsService';

const STATUS_MAP: Record<ReportAction, ReportStatus> = {
  resolve: 'Resolved',
  dismiss: 'Dismissed',
};

type State =
  | { status: 'idle' | 'loading' }
  | { status: 'error'; message: string }
  | { status: 'success'; reports: Report[] };

type Action =
  | { type: 'FETCH_START' }
  | { type: 'FETCH_SUCCESS'; reports: Report[] }
  | { type: 'FETCH_ERROR'; message: string }
  | { type: 'UPDATE_STATUS'; id: string; reportStatus: ReportStatus; note?: string };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'FETCH_START':   return { status: 'loading' };
    case 'FETCH_SUCCESS': return { status: 'success', reports: action.reports };
    case 'FETCH_ERROR':   return { status: 'error', message: action.message };
    case 'UPDATE_STATUS':
      if (state.status !== 'success') return state;
      return {
        ...state,
        reports: state.reports.map((r) =>
          r.id === action.id
            ? {
                ...r,
                status: action.reportStatus,
                adminNote: action.note ?? r.adminNote,
                resolvedAt: new Date().toISOString(),
              }
            : r,
        ),
      };
    default: return state;
  }
}

export function useReports() {
  const [state, dispatch] = useReducer(reducer, { status: 'idle' });

  const load = useCallback(async () => {
    dispatch({ type: 'FETCH_START' });
    try {
      const reports = await fetchReports();
      dispatch({ type: 'FETCH_SUCCESS', reports });
    } catch (err) {
      dispatch({
        type: 'FETCH_ERROR',
        message: err instanceof Error ? err.message : 'Failed to load reports',
      });
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleAction = useCallback(async (id: string, action: ReportAction, note?: string) => {
    const newStatus = STATUS_MAP[action];
    // Persist first — only touch local state on success so a failed
    // request can never masquerade as a resolved/dismissed report.
    try {
      await reportAction(id, action, note);
    } catch (err) {
      throw new Error(err instanceof Error ? err.message : 'Failed to update report');
    }
    dispatch({ type: 'UPDATE_STATUS', id, reportStatus: newStatus, note });
  }, []);

  return {
    loading: state.status === 'idle' || state.status === 'loading',
    error: state.status === 'error' ? state.message : null,
    reports: state.status === 'success' ? state.reports : [],
    reload: load,
    handleAction,
  };
}

import { useCallback, useEffect, useReducer } from 'react';
import {
  fetchBroadcasts,
  createBroadcast,
  deleteBroadcast,
} from '../services/broadcastsService';
import type {
  Broadcast,
  CreateBroadcastPayload,
} from '../services/broadcastsService';

type State =
  | { status: 'idle' | 'loading' }
  | { status: 'error'; message: string }
  | { status: 'success'; broadcasts: Broadcast[] };

type Action =
  | { type: 'FETCH_START' }
  | { type: 'FETCH_SUCCESS'; broadcasts: Broadcast[] }
  | { type: 'FETCH_ERROR'; message: string }
  | { type: 'PREPEND'; broadcast: Broadcast }
  | { type: 'REMOVE'; id: string };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'FETCH_START':   return { status: 'loading' };
    case 'FETCH_SUCCESS': return { status: 'success', broadcasts: action.broadcasts };
    case 'FETCH_ERROR':   return { status: 'error', message: action.message };
    case 'PREPEND':
      if (state.status !== 'success') return state;
      return { ...state, broadcasts: [action.broadcast, ...state.broadcasts] };
    case 'REMOVE':
      if (state.status !== 'success') return state;
      return { ...state, broadcasts: state.broadcasts.filter((b) => b.id !== action.id) };
    default: return state;
  }
}

export function useBroadcasts() {
  const [state, dispatch] = useReducer(reducer, { status: 'idle' });

  const load = useCallback(async () => {
    dispatch({ type: 'FETCH_START' });
    try {
      const broadcasts = await fetchBroadcasts();
      dispatch({ type: 'FETCH_SUCCESS', broadcasts });
    } catch (err) {
      dispatch({ type: 'FETCH_ERROR', message: err instanceof Error ? err.message : 'Failed to load broadcasts' });
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleCreate = useCallback(async (payload: CreateBroadcastPayload) => {
    const created = await createBroadcast(payload); // throws on error — let caller handle
    dispatch({ type: 'PREPEND', broadcast: created });
    return created;
  }, []);

  const handleDelete = useCallback(async (id: string) => {
    dispatch({ type: 'REMOVE', id }); // optimistic
    try { await deleteBroadcast(id); } catch { load(); }
  }, [load]);

  return {
    loading: state.status === 'idle' || state.status === 'loading',
    error: state.status === 'error' ? state.message : null,
    broadcasts: state.status === 'success' ? state.broadcasts : [],
    reload: load,
    handleCreate,
    handleDelete,
  };
}

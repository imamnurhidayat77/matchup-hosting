import { useCallback, useEffect, useReducer } from 'react';
import {
  fetchMembers,
  updateMemberStatus,
  deleteMember,
} from '../services/membersService';
import type { Member, MemberStatus } from '../services/membersService';

type State =
  | { status: 'idle' | 'loading' }
  | { status: 'error'; message: string }
  | { status: 'success'; members: Member[] };

type Action =
  | { type: 'FETCH_START' }
  | { type: 'FETCH_SUCCESS'; members: Member[] }
  | { type: 'FETCH_ERROR'; message: string }
  | { type: 'UPDATE_STATUS'; id: string; memberStatus: MemberStatus }
  | { type: 'REMOVE'; id: string };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'FETCH_START':
      return { status: 'loading' };
    case 'FETCH_SUCCESS':
      return { status: 'success', members: action.members };
    case 'FETCH_ERROR':
      return { status: 'error', message: action.message };
    case 'UPDATE_STATUS':
      if (state.status !== 'success') return state;
      return {
        ...state,
        members: state.members.map((m) =>
          m.id === action.id ? { ...m, status: action.memberStatus } : m,
        ),
      };
    case 'REMOVE':
      if (state.status !== 'success') return state;
      return {
        ...state,
        members: state.members.filter((m) => m.id !== action.id),
      };
    default:
      return state;
  }
}

export function useMembers() {
  const [state, dispatch] = useReducer(reducer, { status: 'idle' });

  const load = useCallback(async () => {
    dispatch({ type: 'FETCH_START' });
    try {
      const members = await fetchMembers();
      dispatch({ type: 'FETCH_SUCCESS', members });
    } catch (err) {
      dispatch({
        type: 'FETCH_ERROR',
        message: err instanceof Error ? err.message : 'Failed to load members',
      });
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleStatusChange = useCallback(
    async (id: string, memberStatus: MemberStatus) => {
      dispatch({ type: 'UPDATE_STATUS', id, memberStatus }); // optimistic
      try {
        await updateMemberStatus(id, memberStatus);
      } catch (err) {
        load(); // revert on error
        throw err; // surface to caller (bulk summary / toast)
      }
    },
    [load],
  );

  const handleDelete = useCallback(
    async (id: string) => {
      dispatch({ type: 'REMOVE', id }); // optimistic
      try {
        await deleteMember(id);
      } catch (err) {
        load();
        throw err; // surface to caller
      }
    },
    [load],
  );

  return {
    loading: state.status === 'idle' || state.status === 'loading',
    error: state.status === 'error' ? state.message : null,
    members: state.status === 'success' ? state.members : [],
    reload: load,
    handleStatusChange,
    handleDelete,
  };
}

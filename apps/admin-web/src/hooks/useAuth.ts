/**
 * Placeholder auth hook. The real implementation will be wired up in
 * the MVP phase alongside the API auth routes.
 */
export interface AuthUser {
  id: string;
  email: string;
  role: 'member' | 'moderator' | 'admin';
}

export function useAuth(): { user: AuthUser | null; loading: boolean } {
  return { user: null, loading: false };
}
import type { NextFunction, Request, Response } from 'express';
import { ApiError } from '../common/ApiError';

/**
 * Placeholder auth middleware.
 *
 * The real implementation (JWT / session validation) will be added during
 * MVP implementation. For now, it accepts any request and attaches an
 * empty user object so downstream handlers can rely on `req.user` shape.
 */
export interface AuthenticatedUser {
  id: string;
  role: 'member' | 'moderator' | 'admin';
}

declare module 'express-serve-static-core' {
  interface Request {
    user?: AuthenticatedUser;
  }
}

export function authMiddleware(req: Request, _res: Response, next: NextFunction): void {
  // TODO(real-auth): validate Authorization header, attach user to req.
  // For the boilerplate phase, intentionally permissive.
  if (req.headers.authorization) {
    req.user = { id: 'placeholder', role: 'member' };
  }
  next();
}

/** Helper for routes that should refuse anonymous callers. */
export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  if (!req.user) {
    next(ApiError.unauthorized());
    return;
  }
  next();
}
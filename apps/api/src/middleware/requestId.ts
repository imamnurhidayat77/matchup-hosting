import type { NextFunction, Request, Response } from 'express';
import { randomUUID } from 'node:crypto';

declare module 'express-serve-static-core' {
  interface Request {
    id?: string;
  }
}

/**
 * Attach a unique request id to every incoming request so logs and
 * downstream calls can be correlated.
 */
export function requestId(req: Request, _res: Response, next: NextFunction): void {
  req.id = req.headers['x-request-id']?.toString() ?? randomUUID();
  next();
}
import type { NextFunction, Request, Response } from 'express';

/**
 * Wrap an async route handler so thrown errors / rejected promises are
 * forwarded to Express's error middleware automatically.
 */
export const asyncHandler =
  <TReq extends Request = Request, TRes extends Response = Response>(
    fn: (req: TReq, res: TRes, next: NextFunction) => Promise<unknown>,
  ) =>
  (req: TReq, res: TRes, next: NextFunction): void => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
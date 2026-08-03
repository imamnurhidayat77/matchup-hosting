import type { Request, Response } from 'express';
import { ApiError } from '../common/ApiError';

export function notFoundHandler(_req: Request, _res: Response, next: (err?: unknown) => void): void {
  next(ApiError.notFound());
}
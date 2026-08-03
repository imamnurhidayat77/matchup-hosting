import type { ErrorRequestHandler } from 'express';
import { ApiError } from '../common/ApiError';
import { logger } from '../config/logger';

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof ApiError) {
    res.status(err.status).json({
      ok: false,
      error: { code: err.code, message: err.message, details: err.details },
    });
    return;
  }

  logger.error({ err }, 'unhandled error in request');
  res.status(500).json({
    ok: false,
    error: { code: 'INTERNAL', message: 'Internal server error' },
  });
};
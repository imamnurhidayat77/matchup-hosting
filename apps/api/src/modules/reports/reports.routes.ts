import { Router } from 'express';
import { asyncHandler } from '../../common/asyncHandler';

/**
 * Reports module — placeholder.
 *
 * Real reporting flow (POST /, GET /, PATCH /:id/resolve) will be
 * implemented during the MVP phase.
 */
export const reportsRouter = Router();

reportsRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    res.json({ ok: true, data: { message: 'reports module placeholder' } });
  }),
);
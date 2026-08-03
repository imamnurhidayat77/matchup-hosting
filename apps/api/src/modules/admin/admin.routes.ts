import { Router } from 'express';
import { asyncHandler } from '../../common/asyncHandler';

/**
 * Admin module — placeholder.
 *
 * Real admin routes (dashboard summary, user management, broadcasts) will
 * be implemented during the MVP phase.
 */
export const adminRouter = Router();

adminRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    res.json({ ok: true, data: { message: 'admin module placeholder' } });
  }),
);
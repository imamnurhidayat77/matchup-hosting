import { Router } from 'express';
import { asyncHandler } from '../../common/asyncHandler';

/**
 * Auth module — placeholder.
 *
 * Real routes (POST /login, POST /register, POST /refresh, POST /logout)
 * will be implemented during the MVP phase.
 */
export const authRouter = Router();

authRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    res.json({ ok: true, data: { message: 'auth module placeholder' } });
  }),
);
import { Router } from 'express';
import { asyncHandler } from '../../common/asyncHandler';

/**
 * Users module — placeholder.
 *
 * Real CRUD routes (GET /, GET /:id, PATCH /:id, DELETE /:id) will be
 * implemented during the MVP phase.
 */
export const usersRouter = Router();

usersRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    res.json({ ok: true, data: { message: 'users module placeholder' } });
  }),
);
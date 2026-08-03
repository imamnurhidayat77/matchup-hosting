import { Router } from 'express';
import { asyncHandler } from '../../common/asyncHandler';

/**
 * Activities module — placeholder.
 *
 * Real routes (CRUD, join, leave, list-by-user) will be implemented during
 * the MVP phase.
 */
export const activitiesRouter = Router();

activitiesRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    res.json({ ok: true, data: { message: 'activities module placeholder' } });
  }),
);
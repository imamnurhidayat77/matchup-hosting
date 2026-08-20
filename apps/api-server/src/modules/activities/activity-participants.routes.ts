import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware.js';
import { joinActivityHandler, leaveActivityHandler, getParticipantsHandler } from './activity-participants.controller.js';

export const activityParticipantsRouter = Router();

activityParticipantsRouter.post('/:activityId/participants', requireAuth, joinActivityHandler);
activityParticipantsRouter.get('/:activityId/participants', getParticipantsHandler);
activityParticipantsRouter.delete('/:activityId/participants/:uid', requireAuth, leaveActivityHandler);
import { Router } from 'express';
import { createActivityHandler, getActivityHandler } from './activities.controller.js';
import { activityParticipantsRouter } from './activity-participants.routes.js';
import { requireAuth } from '../../middleware/auth.middleware.js';

export const activitiesRouter = Router();

activitiesRouter.post('/', requireAuth, createActivityHandler);
activitiesRouter.get('/:activityId', getActivityHandler);

activitiesRouter.use('/', activityParticipantsRouter);

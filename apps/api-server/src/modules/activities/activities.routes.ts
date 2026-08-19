import { Router } from 'express';
import { createActivityHandler, getActivityHandler } from './activities.controller.js';
import { activityParticipantsRouter } from './activity-participants.routes.js';

export const activitiesRouter = Router();

activitiesRouter.post('/', createActivityHandler);
activitiesRouter.get('/:activityId', getActivityHandler);

activitiesRouter.use('/', activityParticipantsRouter);

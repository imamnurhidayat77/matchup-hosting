import { Router } from 'express';
import {
    createActivityHandler,
    getActivityHandler,
    listActivitiesHandler,
    updateActivityHandler,
    updateActivityStatusHandler,
} from './activities.controller.js';
import { activityParticipantsRouter } from './activity-participants.routes.js';
import { requireAuth } from '../../middleware/auth.middleware.js';

export const activitiesRouter = Router();

activitiesRouter.post('/', requireAuth, createActivityHandler);
activitiesRouter.get('/', requireAuth, listActivitiesHandler);
activitiesRouter.patch('/:activityId/status', requireAuth, updateActivityStatusHandler);
activitiesRouter.patch('/:activityId', requireAuth, updateActivityHandler);
activitiesRouter.get('/:activityId', requireAuth, getActivityHandler);
activitiesRouter.use('/', activityParticipantsRouter);

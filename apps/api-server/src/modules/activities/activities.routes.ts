import { Router } from 'express';
import { createActivityHandler, getActivityHandler } from './activities.controller.js';

export const activitiesRouter = Router();

activitiesRouter.post('/', createActivityHandler);
activitiesRouter.get('/:activityId', getActivityHandler);

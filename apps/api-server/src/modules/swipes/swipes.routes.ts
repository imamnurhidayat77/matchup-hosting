import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware.js';
import {
    getSwipeDecisionHandler,
    listSwipeDecisionsHandler,
    saveSwipeDecisionHandler,
} from './swipes.controller.js';

export const swipesRouter = Router();

swipesRouter.post('/', requireAuth, saveSwipeDecisionHandler);
swipesRouter.get('/:uid/:activityId', requireAuth, getSwipeDecisionHandler);
swipesRouter.get('/:uid', requireAuth, listSwipeDecisionsHandler);


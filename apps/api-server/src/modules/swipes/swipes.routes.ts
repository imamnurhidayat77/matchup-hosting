import { Router } from 'express';
import {
    getSwipeDecisionHandler,
    listSwipeDecisionsHandler,
    saveSwipeDecisionHandler,
} from './swipes.controller.js';

export const swipesRouter = Router();

swipesRouter.post('/', saveSwipeDecisionHandler);
swipesRouter.get('/:uid/:activityId', getSwipeDecisionHandler);
swipesRouter.get('/:uid', listSwipeDecisionsHandler);


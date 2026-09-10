import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware.js';
import {
    bootstrapUserHandler,
    getCustomTokenHandler,
    getPublicUserProfileHandler,
    getMyUserHandler,
    updateMyUserProfileHandler,
} from './users.controller.js';

export const usersRouter = Router();

usersRouter.post('/me', requireAuth, bootstrapUserHandler);
usersRouter.post('/custom-token', requireAuth, getCustomTokenHandler);
usersRouter.get('/me', requireAuth, getMyUserHandler);
usersRouter.patch('/me', requireAuth, updateMyUserProfileHandler);
usersRouter.get('/:uid/profile', requireAuth, getPublicUserProfileHandler);

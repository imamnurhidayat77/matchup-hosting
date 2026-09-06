import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware.js';
import {
    bootstrapUserHandler,
    getPublicUserProfileHandler,
    getMyUserHandler,
    updateMyUserProfileHandler,
} from './users.controller.js';

export const usersRouter = Router();

usersRouter.post('/me', requireAuth, bootstrapUserHandler);
usersRouter.get('/me', requireAuth, getMyUserHandler);
usersRouter.patch('/me', requireAuth, updateMyUserProfileHandler);
usersRouter.get('/:uid/profile', requireAuth, getPublicUserProfileHandler);

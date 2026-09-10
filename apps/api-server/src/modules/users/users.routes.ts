import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware.js';
import {
    bootstrapUserHandler,
    getCustomTokenHandler,
    getPublicUserProfileHandler,
    getMyUserHandler,
    updateMyUserPhotoHandler,
    updateMyUserProfileHandler,
} from './users.controller.js';

export const usersRouter = Router();

usersRouter.post('/me', requireAuth, bootstrapUserHandler);
usersRouter.post('/custom-token', requireAuth, getCustomTokenHandler);
usersRouter.get('/me', requireAuth, getMyUserHandler);
usersRouter.patch('/me/photo', requireAuth, updateMyUserPhotoHandler);
usersRouter.patch('/me', requireAuth, updateMyUserProfileHandler);
usersRouter.get('/:uid/profile', requireAuth, getPublicUserProfileHandler);

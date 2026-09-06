import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware.js';
import {
    listMyNotificationsHandler,
    markMyNotificationReadHandler,
} from './notifications.controller.js';

export const notificationsRouter = Router();

notificationsRouter.get('/me', requireAuth, listMyNotificationsHandler);
notificationsRouter.patch('/me/:notificationId/read', requireAuth, markMyNotificationReadHandler);

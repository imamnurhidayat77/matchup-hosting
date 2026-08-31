import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware.js';
import {
    createNotificationHandler,
    listMyNotificationsHandler,
    listNotificationsHandler,
    markMyNotificationReadHandler,
    markNotificationReadHandler,
} from './notifications.controller.js';

export const notificationsRouter = Router();

notificationsRouter.post('/', createNotificationHandler);
notificationsRouter.get('/me', requireAuth, listMyNotificationsHandler);
notificationsRouter.patch('/me/:notificationId/read', requireAuth, markMyNotificationReadHandler);
notificationsRouter.get('/:uid', requireAuth, listNotificationsHandler);
notificationsRouter.patch('/:uid/:notificationId/read', requireAuth, markNotificationReadHandler);

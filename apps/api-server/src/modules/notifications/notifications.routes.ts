import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware.js';
import {
    createNotificationHandler,
    listNotificationsHandler,
    markNotificationReadHandler,
} from './notifications.controller.js';

export const notificationsRouter = Router();

notificationsRouter.post('/', createNotificationHandler);
notificationsRouter.get('/:uid', requireAuth, listNotificationsHandler);
notificationsRouter.patch('/:uid/:notificationId/read', requireAuth, markNotificationReadHandler);
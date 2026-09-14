import { Router } from 'express';
import { getMessagesHandler, sendMessageHandler } from './chat.controller.js';
import { sendMessageSchema } from './chat.schema.js';
import { requireAuth } from '../../middleware/auth.middleware.js';
import { validateBody } from '../../middleware/validate.js';

export const chatRouter = Router();

chatRouter.post(
    '/messages',
    requireAuth,
    validateBody(sendMessageSchema),
    sendMessageHandler,
);
chatRouter.get('/:activityId/messages', requireAuth, getMessagesHandler);

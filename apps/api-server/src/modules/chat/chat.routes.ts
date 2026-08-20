import { Router } from 'express';
import { getMessagesHandler, sendMessageHandler} from './chat.controller.js';
import { requireAuth } from '../../middleware/auth.middleware.js';

export const chatRouter = Router();

chatRouter.post('/messages', requireAuth, sendMessageHandler);
chatRouter.get('/:activityId/messages', getMessagesHandler);
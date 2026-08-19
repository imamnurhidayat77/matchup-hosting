import { Router } from 'express';
import { getMessagesHandler, sendMessageHandler} from './chat.controller.js'

export const chatRouter = Router();

chatRouter.post('/messages', sendMessageHandler);
chatRouter.get('/:activityId/messages', getMessagesHandler);
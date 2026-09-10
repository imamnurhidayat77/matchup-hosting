import { Router } from 'express';
import {
    getThreadHandler,
    listDmMessagesHandler,
    sendDmHandler,
} from './dm.controller.js';
import { requireAuth } from '../../middleware/auth.middleware.js';

export const dmRouter = Router();

dmRouter.get('/:uid/thread', requireAuth, getThreadHandler);
dmRouter.get('/:uid/messages', requireAuth, listDmMessagesHandler);
dmRouter.post('/:uid/messages', requireAuth, sendDmHandler);

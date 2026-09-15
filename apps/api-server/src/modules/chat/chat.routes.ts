import { Router } from 'express';
import {
    createPollHandler,
    getMessagesHandler,
    getPollsHandler,
    getReactionsHandler,
    sendMessageHandler,
    toggleReactionHandler,
    votePollHandler,
} from './chat.controller.js';
import { createPollSchema, sendMessageSchema, toggleReactionSchema, votePollSchema } from './chat.schema.js';
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
chatRouter.post(
    '/:activityId/messages/:messageId/reactions',
    requireAuth,
    validateBody(toggleReactionSchema),
    toggleReactionHandler,
);
chatRouter.get('/:activityId/reactions', requireAuth, getReactionsHandler);
chatRouter.get(
    '/:activityId/messages/:messageId/reactions',
    requireAuth,
    getReactionsHandler,
);
chatRouter.post(
    '/:activityId/polls',
    requireAuth,
    validateBody(createPollSchema),
    createPollHandler,
);
chatRouter.get('/:activityId/polls', requireAuth, getPollsHandler);
chatRouter.post(
    '/:activityId/polls/:pollId/votes',
    requireAuth,
    validateBody(votePollSchema),
    votePollHandler,
);

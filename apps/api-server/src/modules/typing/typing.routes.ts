import { Router } from 'express';
import { getTypingHandler, setTypingHandler } from './typing.controller.js'

export const typingRouter = Router();

typingRouter.post('/', setTypingHandler);
typingRouter.get('/:activityId/:uid', getTypingHandler)
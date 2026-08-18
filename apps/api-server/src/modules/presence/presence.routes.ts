import { Router } from 'express';
import { getPresenceHandler, setPresenceHandler } from './presence.controller.js';

export const presenceRouter = Router();

presenceRouter.post('/', setPresenceHandler);
presenceRouter.get('/:uid', getPresenceHandler);
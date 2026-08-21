import { Router } from 'express';
import { joinActivityHandler, leaveActivityHandler, getParticipantsHandler } from './activity-participants.controller.js';

export const activityParticipantsRouter = Router();

activityParticipantsRouter.post('/:activityId/participants', joinActivityHandler);
activityParticipantsRouter.get('/:activityId/participants', getParticipantsHandler);
activityParticipantsRouter.delete('/:activityId/participants/:uid', leaveActivityHandler);
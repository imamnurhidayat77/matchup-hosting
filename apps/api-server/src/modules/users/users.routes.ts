import { Router } from 'express';
import { createUserHandler, getUserHandler } from './users.controller.js';

export const usersRouter = Router();

usersRouter.post('/', createUserHandler);
usersRouter.get('/:authUid', getUserHandler);
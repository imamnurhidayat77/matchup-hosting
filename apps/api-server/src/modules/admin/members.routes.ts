import { Router } from 'express';
import { requireAuth, requireAdmin } from '../../middleware/auth.middleware.js';
import {
    deleteMemberHandler,
    getMemberHandler,
    listMembersHandler,
    setMemberStatusHandler,
} from './members.controller.js';

export const adminMembersRouter = Router();

adminMembersRouter.get('/', requireAuth, requireAdmin, listMembersHandler);
adminMembersRouter.get('/:uid', requireAuth, requireAdmin, getMemberHandler);
adminMembersRouter.patch(
    '/:uid/status',
    requireAuth,
    requireAdmin,
    setMemberStatusHandler,
);
adminMembersRouter.delete('/:uid', requireAuth, requireAdmin, deleteMemberHandler);

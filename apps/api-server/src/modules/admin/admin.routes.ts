import { Router } from 'express';
import { requireAuth, requireAdmin } from '../../middleware/auth.middleware.js';
import { adminMembersRouter } from './members.routes.js';
import { adminActivitiesRouter } from './activities.routes.js';
import { adminBroadcastsRouter } from './broadcasts.routes.js';
import { adminSportsRouter } from './sports.routes.js';
import { adminTemplatesRouter } from './templates.routes.js';

/**
 * Admin API namespace (`/api/admin/*`). Every sub-router enforces
 * `requireAuth + requireAdmin` per route — no open admin endpoints.
 */
export const adminRouter = Router();

/** Login gate for the admin web: proves the caller's token is admin. */
adminRouter.get('/me', requireAuth, requireAdmin, (req, res) => {
    return res.status(200).json({
        ok: true,
        data: {
            uid: req.auth?.uid,
            email:
                typeof req.auth?.token.email === 'string'
                    ? req.auth.token.email
                    : null,
            admin: true,
        },
    });
});

adminRouter.use('/members', adminMembersRouter);
adminRouter.use('/activities', adminActivitiesRouter);
adminRouter.use('/broadcasts', adminBroadcastsRouter);
adminRouter.use('/sports', adminSportsRouter);
adminRouter.use('/templates', adminTemplatesRouter);

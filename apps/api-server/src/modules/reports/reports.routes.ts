import { Router } from 'express';
import {
    dismissReportHandler,
    listReportsHandler,
    resolveReportHandler,
    submitReportHandler,
} from './reports.controller.js';
import {
    requireAdmin,
    requireAuth,
} from '../../middleware/auth.middleware.js';

export const reportsRouter = Router();

reportsRouter.post('/', requireAuth, submitReportHandler);

// Triage board — admin only (uid allowlist via ADMIN_UIDS).
reportsRouter.get('/', requireAuth, requireAdmin, listReportsHandler);
reportsRouter.post('/:id/resolve', requireAuth, requireAdmin, resolveReportHandler);
reportsRouter.post('/:id/dismiss', requireAuth, requireAdmin, dismissReportHandler);

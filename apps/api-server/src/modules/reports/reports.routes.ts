import { Router } from 'express';
import { submitReportHandler } from './reports.controller.js';
import { requireAuth } from '../../middleware/auth.middleware.js';

export const reportsRouter = Router();

reportsRouter.post('/', requireAuth, submitReportHandler);

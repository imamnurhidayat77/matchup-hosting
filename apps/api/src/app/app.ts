import express, { type Application, type Request, type Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { env } from '../config/env';
import { prisma } from '../database/prisma';
import { requestId } from '../middleware/requestId';
import { authMiddleware } from '../middleware/auth';
import { errorHandler } from '../middleware/errorHandler';
import { notFoundHandler } from '../middleware/notFound';
import { authRouter } from '../modules/auth/auth.routes';
import { usersRouter } from '../modules/users/users.routes';
import { activitiesRouter } from '../modules/activities/activities.routes';
import { reportsRouter } from '../modules/reports/reports.routes';
import { adminRouter } from '../modules/admin/admin.routes';

/**
 * Build and return the Express application.
 *
 * The factory pattern lets us instantiate separate app instances for tests
 * without binding to a port.
 */
export function createApp(): Application {
  const app = express();

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(
    cors({
      origin: env.CORS_ORIGIN.split(',').map((o) => o.trim()),
      credentials: true,
    }),
  );
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true }));
  app.use(requestId);
  app.use(morgan('combined'));
  app.use(authMiddleware);

  // Health endpoint — used by load balancers and the local development guide.
  app.get('/health', async (_req: Request, res: Response) => {
    try {
      await prisma.$queryRaw`SELECT 1`;
      res.json({ ok: true, data: { status: 'ok', service: 'matchup-api', database: 'connected' } });
    } catch {
      res.status(503).json({ ok: false, error: { code: 'DB_UNAVAILABLE', message: 'Database unreachable' } });
    }
  });

  // Module routes
  app.use('/auth', authRouter);
  app.use('/users', usersRouter);
  app.use('/activities', activitiesRouter);
  app.use('/reports', reportsRouter);
  app.use('/admin', adminRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
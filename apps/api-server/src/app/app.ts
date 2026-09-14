import express, { type NextFunction, type Request, type Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { checkFirestoreConnection } from '../database/firebase.js';
import { corsOrigins } from '../config/env.js';
import {
    AUTOCOMPLETE_RATE_LIMIT,
    GLOBAL_RATE_LIMIT,
    TYPING_RATE_LIMIT,
    createRateLimiter,
} from '../middleware/rate-limit.js';
import { usersRouter } from '../modules/users/users.routes.js';
import { presenceRouter } from '../modules/presence/presence.routes.js';
import { typingRouter } from '../modules/typing/typing.routes.js';
import { chatRouter } from '../modules/chat/chat.routes.js';
import { dmRouter } from '../modules/dm/dm.routes.js';
import { activitiesRouter } from '../modules/activities/activities.routes.js';
import { adminRouter } from '../modules/admin/admin.routes.js';
import { appealsRouter } from '../modules/appeals/appeals.routes.js';
import { listPublicActivityTeasersHandler } from '../modules/activities/activities.controller.js';
import { listPublicSportsHandler } from '../modules/admin/public-sports.controller.js';
import { swipesRouter } from '../modules/swipes/swipes.routes.js';
import { notificationsRouter } from '../modules/notifications/notifications.routes.js';
import { devicesRouter } from '../modules/devices/devices.routes.js';
import { placesRouter } from '../modules/places/places.routes.js';
import { reportsRouter } from '../modules/reports/reports.routes.js';

export function createApp(){
    const app = express();

    const allowedOrigins = corsOrigins();
    if (allowedOrigins.length === 0) {
        // Permissive default preserves existing clients (mobile/admin-web)
        // when CORS_ORIGINS is unset. Set CORS_ORIGINS in production.
        console.warn(
            '[cors] CORS_ORIGINS is not set — allowing all origins. ' +
            'Set CORS_ORIGINS to a comma-separated allowlist in production.',
        );
        app.use(cors());
    } else {
        app.use(cors({ origin: allowedOrigins }));
    }
    app.use(helmet());
    app.use(morgan(':date[iso] :method :url :status :response-time ms'));
    // Global volume guard (skips /api/health); route limiters below add
    // tighter burst caps on abuse-prone endpoints. Limiter instances are
    // created per app so tests stay isolated.
    app.use(createRateLimiter(GLOBAL_RATE_LIMIT));
    app.use(express.json({ limit: '1mb' }));
    app.use('/api/typing', createRateLimiter(TYPING_RATE_LIMIT));
    app.use('/api/places/autocomplete', createRateLimiter(AUTOCOMPLETE_RATE_LIMIT));

    app.get('/api/health', async (_req, res) =>{
        try {
            await checkFirestoreConnection();
            res.json({
                ok: true,
                data:{
                    status : 'ok',
                    service: 'api-server',
                    database: 'connected',
                },
            })
        } catch (error) {
            res.status(503).json({
                ok: false,
                error: {
                    code: 'DB_UNAVAILABLE',
                    message: 'Firestore unreachable',
                },
            })
        }
    })

    app.get('/api/public/activities', listPublicActivityTeasersHandler);
    app.get('/api/public/sports', listPublicSportsHandler);

    app.use('/api/users', usersRouter);
    app.use('/api/presence', presenceRouter);
    app.use('/api/typing', typingRouter);
    app.use('/api/chat', chatRouter);
    app.use('/api/dm', dmRouter);
    app.use('/api/activities', activitiesRouter);
    app.use('/api/swipes', swipesRouter);
    app.use('/api/notifications', notificationsRouter);
    app.use('/api/devices', devicesRouter);
    app.use('/api/places', placesRouter);
    app.use('/api/reports', reportsRouter);
    app.use('/api/appeals', appealsRouter);
    app.use('/api/admin', adminRouter);

    // Unknown /api/* routes return the JSON envelope (the mobile api_client
    // parses every response as the envelope — Express' default HTML 404
    // breaks it). Non-/api paths keep Express' default handler.
    app.use('/api', (_req: Request, res: Response) => {
        res.status(404).json({
            ok: false,
            error: {
                code: 'NOT_FOUND',
                message: 'Not found',
            },
        });
    });

    // Generic error middleware: always the envelope, never leaks stacks.
    // Must be registered last (4-arg signature so Express treats it as an
    // error handler, including body-parser SyntaxError / 413 errors).
    app.use((err: unknown, _req: Request, res: Response, next: NextFunction) => {
        if (res.headersSent) {
            next(err);
            return;
        }
        // Stacks stay in the server log; clients only get the envelope.
        console.error('[api] unhandled error:', err);
        const bodyStatus = bodyParserErrorStatus(err);
        if (bodyStatus === 413) {
            res.status(413).json({
                ok: false,
                error: {
                    code: 'PAYLOAD_TOO_LARGE',
                    message: 'Request body too large',
                },
            });
            return;
        }
        if (bodyStatus === 400) {
            res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'Invalid JSON body',
                },
            });
            return;
        }
        res.status(500).json({
            ok: false,
            error: {
                code: 'INTERNAL_ERROR',
                message: 'Internal server error',
            },
        });
    });

    return app;
}

/** Maps express.json() failures to their HTTP status, else null. */
function bodyParserErrorStatus(err: unknown): 400 | 413 | null {
    if (typeof err !== 'object' || err === null) {
        return null;
    }
    const record = err as { status?: unknown; type?: unknown };
    if (record.type === 'entity.too.large' && record.status === 413) {
        return 413;
    }
    if (
        (record.type === 'entity.parse.failed' || err instanceof SyntaxError) &&
        record.status === 400
    ) {
        return 400;
    }
    return null;
}

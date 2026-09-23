import type { Request, Response } from 'express';
import { getAnalytics, getDashboard } from './analytics.service.js';

const RANGE_DAYS: Record<string, number> = { '7d': 7, '30d': 30, '90d': 90 };

export async function getAnalyticsHandler(req: Request, res: Response) {
    try {
        const rawRange = req.query.range;
        const rangeKey = rawRange === undefined ? '7d' : String(rawRange);
        const rangeDays = RANGE_DAYS[rangeKey];
        if (rangeDays === undefined) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'range must be 7d, 30d, or 90d',
                },
            });
        }
        const view = await getAnalytics(rangeDays);
        // Empty-state signal for dashboards: the un-collected
        // retention/health series are documented in `view.note`; the
        // header lets caches/proxies see it without parsing the body.
        // Guarded (not unconditional) so mocked/legacy views without a
        // note never crash header serialization.
        if (typeof view.note === 'string' && view.note.length > 0) {
            res.setHeader('X-Analytics-Note', view.note);
        }
        return res.status(200).json({ ok: true, data: view });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

export async function getDashboardHandler(_req: Request, res: Response) {
    try {
        const view = await getDashboard();
        return res.status(200).json({ ok: true, data: view });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

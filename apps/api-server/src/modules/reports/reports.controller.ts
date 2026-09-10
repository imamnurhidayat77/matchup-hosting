import type { Request, Response } from 'express';
import { submitReport } from './reports.service.js';

export async function submitReportHandler(req: Request, res: Response) {
    try {
        const reporterId = req.auth?.uid;
        const { targetId, targetType, reason, details } = req.body as {
            targetId?: unknown;
            targetType?: unknown;
            reason?: unknown;
            details?: unknown;
        };

        if (!reporterId) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (
            typeof targetId !== 'string' ||
            typeof reason !== 'string' ||
            (details !== undefined && typeof details !== 'string')
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'targetId and reason must be strings',
                },
            });
        }

        if (targetType !== 'user' && targetType !== 'activity') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'targetType must be user or activity',
                },
            });
        }

        if (!targetId.trim() || !reason.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'targetId and reason are required',
                },
            });
        }

        const result = await submitReport({
            reporterId,
            targetId,
            targetType: targetType as 'user' | 'activity',
            reason,
            ...(typeof details === 'string' && details.trim()
                ? { details }
                : {}),
        });

        return res.status(201).json({
            ok: true,
            data: {
                reportId: result.reportId,
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Target not found') {
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message,
                },
            });
        }

        if (
            message === 'cannot report yourself' ||
            message.startsWith('reason must be') ||
            message.startsWith('details must be')
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message,
                },
            });
        }

        return res.status(500).json({
            ok: false,
            error: {
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}

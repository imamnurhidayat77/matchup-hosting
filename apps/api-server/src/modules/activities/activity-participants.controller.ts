import type { Request, Response } from 'express';
import { getParticipants, joinActivity, leaveActivity } from './activity-participants.service.js';

type ActivityParams = {
    activityId: string;
};

type LeaveActivityParams = {
    activityId: string;
    uid: string;
};

export async function joinActivityHandler(req: Request<ActivityParams>, res: Response) {
    try {
        const { activityId } = req.params;
        const { uid } = req.body as { uid?: unknown };

        if (typeof uid !== 'string') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'uid must be a string',
                },
            });
        }

        if (!activityId.trim() || !uid.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId and uid are required',
                },
            });
        }

        await joinActivity(activityId, uid);

        return res.status(200).json({
            ok: true,
            data: {
                activityId,
                uid,
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Activity not found') {
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message,
                },
            });
        }

        if (message === 'Activity is not open for joining' ||
            message === 'Activity is full' ||
            message === 'User already joined this activity'
        ) {
            return res.status(409).json({
                ok: false,
                error: {
                    code: 'CONFLICT',
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

export async function getParticipantsHandler(
    req: Request<ActivityParams>, res: Response,
) {
    try {
        const { activityId } = req.params;

        if (!activityId.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        }

        const participants = await getParticipants(activityId);

        return res.status(200).json({
            ok: true,
            data: participants,
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        return res.status(500).json({
            ok: false,
            error: {
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}

export async function leaveActivityHandler(req: Request<LeaveActivityParams>, res: Response) {
    try {
        const { activityId, uid } = req.params;

        if (!activityId.trim() || !uid.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId and uid are required',
                },
            });
        }

        await leaveActivity(activityId, uid);

        return res.status(200).json({
            ok: true,
            data: {
                activityId,
                uid,
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Activity not found' || message === 'Participant not found') {
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
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

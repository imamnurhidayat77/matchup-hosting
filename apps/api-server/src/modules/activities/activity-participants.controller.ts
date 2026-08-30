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
        const uid = req.auth?.uid;
        const { activityId } = req.params;

        if (!uid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (!activityId.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
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
        const authUid = req.auth?.uid;
        const { activityId, uid } = req.params;

        if(!authUid){
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required'
                }
            })
        }

        if (!activityId.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        }

        await leaveActivity({
            activityId,
            targetUid: uid,
            actorUid: authUid,
        });

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

        if (message === 'Only the participant or activity host can remove this participant') {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
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

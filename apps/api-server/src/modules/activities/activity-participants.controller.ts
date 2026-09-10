import type { Request, Response } from 'express';
import {
    approveJoinRequest,
    declineJoinRequest,
    getParticipants,
    joinActivity,
    leaveActivity,
    listJoinRequests,
    requestToJoin,
} from './activity-participants.service.js';
import { getActivityById } from './activities.service.js';
import { createNotification } from '../notifications/notifications.service.js';

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
        const activity = await getActivityById(activityId);

        if (activity && activity.hostId !== uid) {
            await createNotification({
                recipientUid: activity.hostId,
                type: 'activity_joined',
                title: 'New participant',
                body: 'Someone joined your activity',
                activityId,
                senderUid: uid,
            });
        }

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
            message === 'User already joined this activity' ||
            message === 'This activity requires host approval — request to join instead'
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

        if (!authUid) {
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

        if (!uid.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'uid is required',
                },
            });
        }

        await leaveActivity({
            activityId,
            targetUid: uid,
            actorUid: authUid,
        });
        const activity = await getActivityById(activityId);

        const isSelfRemoval = uid === authUid;
        const isHostRemoval = activity?.hostId === authUid && uid !== authUid;
        const isHostSelfRemoval = activity?.hostId === authUid && uid === authUid;

        if (activity && isSelfRemoval && activity.hostId !== uid) {
            await createNotification({
                recipientUid: activity.hostId,
                type: 'activity_left',
                title: 'Participant left',
                body: 'Someone left your activity',
                activityId,
                senderUid: uid,
            });
        } else if (activity && isHostRemoval) {
            await createNotification({
                recipientUid: uid,
                type: 'participant_removed',
                title: 'Removed from activity',
                body: 'The host removed you from an activity',
                activityId,
                senderUid: authUid,
            });
        } else if (activity && isHostSelfRemoval) {
            const participants = await getParticipants(activityId);
            const notificationRecipients = participants
                .map((participant) => participant.uid)
                .filter((participantUid) => participantUid !== authUid);

            await Promise.all(
                notificationRecipients.map((recipientUid) =>
                    createNotification({
                        recipientUid,
                        type: 'activity_cancelled',
                        title: 'Activity cancelled',
                        body: 'The host cancelled this activity',
                        activityId,
                        senderUid: authUid,
                    }),
                ),
            );
        }

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

type JoinRequestParams = {
    activityId: string;
    uid: string;
};

export async function requestJoinActivityHandler(
    req: Request<ActivityParams>,
    res: Response,
) {
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

        await requestToJoin(activityId, uid);

        return res.status(201).json({
            ok: true,
            data: {
                activityId,
                uid,
                status: 'pending',
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
            message === 'User already joined this activity' ||
            message === 'The host is already in this activity' ||
            message === 'Join request already pending' ||
            message === 'This activity does not require approval — join directly'
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

export async function listJoinRequestsHandler(
    req: Request<ActivityParams>,
    res: Response,
) {
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

        const activity = await getActivityById(activityId);

        if (!activity) {
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message: 'Activity not found',
                },
            });
        }

        if (activity.hostId !== uid) {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'Only the activity host can view join requests',
                },
            });
        }

        const requests = await listJoinRequests(activityId);

        return res.status(200).json({
            ok: true,
            data: requests,
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

async function decideJoinRequestHandler(
    req: Request<JoinRequestParams>,
    res: Response,
    decision: 'approved' | 'declined',
) {
    try {
        const actorUid = req.auth?.uid;
        const { activityId, uid } = req.params;

        if (!actorUid) {
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

        if (!uid.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'uid is required',
                },
            });
        }

        if (decision === 'approved') {
            await approveJoinRequest(activityId, uid, actorUid);
        } else {
            await declineJoinRequest(activityId, uid, actorUid);
        }

        return res.status(200).json({
            ok: true,
            data: {
                activityId,
                uid,
                status: decision === 'approved' ? 'approved' : 'declined',
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Activity not found' || message === 'Join request not found') {
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message,
                },
            });
        }

        if (message === 'Only the activity host can decide join requests') {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message,
                },
            });
        }

        if (message === 'Activity is not open for joining' ||
            message === 'Activity is full'
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

export async function approveJoinRequestHandler(
    req: Request<JoinRequestParams>,
    res: Response,
) {
    return decideJoinRequestHandler(req, res, 'approved');
}

export async function declineJoinRequestHandler(
    req: Request<JoinRequestParams>,
    res: Response,
) {
    return decideJoinRequestHandler(req, res, 'declined');
}

import type { Request, Response } from 'express';
import {
    createNotification,
    listNotifications,
    markNotificationRead,
} from './notifications.service.js';

type NotificationParams = {
    uid: string;
};

type MarkNotificationReadParams = {
    uid: string;
    notificationId: string;
};

type MarkMyNotificationReadParams = {
    notificationId: string;
};

export async function createNotificationHandler(req: Request, res: Response) {
    try {
        const {
            recipientUid,
            type,
            title,
            body,
            activityId,
            senderUid,
        } = req.body as {
            recipientUid?: unknown;
            type?: unknown;
            title?: unknown;
            body?: unknown;
            activityId?: unknown;
            senderUid?: unknown;
        };

        if (
            typeof recipientUid !== 'string' ||
            typeof type !== 'string' ||
            typeof title !== 'string' ||
            typeof body !== 'string'
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'recipientUid, type, title, and body must be strings',
                },
            });
        }

        if (
            (activityId !== undefined && typeof activityId !== 'string') ||
            (senderUid !== undefined && typeof senderUid !== 'string')
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'activityId and senderUid must be strings when provided',
                },
            });
        }

        if (
            type !== 'activity_reminder' &&
            type !== 'activity_interest' &&
            type !== 'activity_joined' &&
            type !== 'activity_left' &&
            type !== 'participant_removed' &&
            type !== 'chat_message' &&
            type !== 'system'
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'type must be activity_reminder, activity_interest, activity_joined, activity_left, participant_removed, chat_message, or system',
                },
            });
        }

        if (
            !recipientUid.trim() ||
            !title.trim() ||
            !body.trim()
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'recipientUid, title, and body are required',
                },
            });
        }

        const result = await createNotification({
            recipientUid,
            type,
            title,
            body,
            ...(typeof activityId === 'string' ? { activityId } : {}),
            ...(typeof senderUid === 'string' ? { senderUid } : {}),
        });

        return res.status(201).json({
            ok: true,
            data: {
                notificationId: result.notificationId,
            },
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

export async function listNotificationsHandler(
    req: Request<NotificationParams>,
    res: Response,
) {
    try {
        const authUid = req.auth?.uid;
        const { uid } = req.params;

        if (!authUid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
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

        if (authUid !== uid) {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'You can only access your own notifications',
                },
            });
        }

        const notifications = await listNotifications(uid);

        return res.status(200).json({
            ok: true,
            data: notifications,
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

export async function listMyNotificationsHandler(req: Request, res: Response) {
    try {
        const authUid = req.auth?.uid;

        if (!authUid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        const notifications = await listNotifications(authUid);

        return res.status(200).json({
            ok: true,
            data: notifications,
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

export async function markNotificationReadHandler(
    req: Request<MarkNotificationReadParams>,
    res: Response,
) {
    try {
        const authUid = req.auth?.uid;
        const { uid, notificationId } = req.params;

        if (!authUid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (!uid.trim() || !notificationId.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'uid and notificationId are required',
                },
            });
        }

        if (authUid !== uid) {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'You can only update your own notifications',
                },
            });
        }

        await markNotificationRead(uid, notificationId);

        return res.status(200).json({
            ok: true,
            data: {
                uid,
                notificationId,
                isRead: true,
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Notification not found') {
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

export async function markMyNotificationReadHandler(
    req: Request<MarkMyNotificationReadParams>,
    res: Response,
) {
    try {
        const authUid = req.auth?.uid;
        const { notificationId } = req.params;

        if (!authUid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (!notificationId.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'notificationId is required',
                },
            });
        }

        await markNotificationRead(authUid, notificationId);

        return res.status(200).json({
            ok: true,
            data: {
                uid: authUid,
                notificationId,
                isRead: true,
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Notification not found') {
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

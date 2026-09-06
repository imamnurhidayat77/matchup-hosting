import type { Request, Response } from 'express';
import { getMessages, sendMessage } from './chat.service.js';
import { canAccessActivityChat } from '../activities/activity-participants.service.js';

type GetMessagesParams = {
    activityId: string;
};

export async function sendMessageHandler(req: Request, res: Response) {
    try {
        const senderId = req.auth?.uid;
        const { activityId, text, type } = req.body as {
            activityId?: unknown;
            text?: unknown;
            type?: unknown;
        };

        if(!senderId){
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (typeof activityId !== 'string' ||
            typeof text !== 'string'
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'activityId and text must be strings',
                },
            });
        }

        if (type !== undefined && type !== 'text' && type !== 'system') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'type must be text or system',
                },
            });
        }

        if (!activityId.trim() || !text.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId and text are required',
                },
            });
        }

        const canAccessChat = await canAccessActivityChat(activityId, senderId);

        if (!canAccessChat) {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'Only the activity host or participants can access this chat',
                },
            });
        }

        const result = await sendMessage(
            activityId,
            senderId,
            text,
            type === undefined ? 'text' : type,
        );

        return res.status(201).json({
            ok: true,
            data: {
                messageId: result.messageId,
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message: 'Unknown error';

        if (message === 'Activity not found') {
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
            error:{
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}

export async function getMessagesHandler(req: Request<GetMessagesParams>, res: Response){
    try{
        const uid = req.auth?.uid;
        const{ activityId } = req.params;

        if (!uid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if(!activityId.trim()){
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        }

        const canAccessChat = await canAccessActivityChat(activityId, uid);

        if (!canAccessChat) {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'Only the activity host or participants can access this chat',
                },
            });
        }

        const messages = await getMessages(activityId);

        return res.status(200).json({
            ok: true,
            data: messages,
        });
    } catch (error){
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

        return res.status(500).json({
            ok: false,
            error:{
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}

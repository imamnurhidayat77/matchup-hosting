import type { Request, Response } from 'express';
import { createPoll, getMessageReactions, getMessages, getPolls, getReactions, sendMessage, toggleReaction, votePoll } from './chat.service.js';
import type { CreatePollInput, SendMessageInput, ToggleReactionInput, VotePollInput } from './chat.schema.js';
import { canAccessActivityChat } from '../activities/activity-participants.service.js';

type GetMessagesParams = {
    activityId: string;
};

export async function sendMessageHandler(req: Request, res: Response) {
    try {
        const senderId = req.auth?.uid;
        // Shape already enforced by `validateBody(sendMessageSchema)` —
        // trimmed, non-blank, `type` defaulted. Only auth + membership
        // remain for the controller to check.
        const { activityId, text, type } = req.body as SendMessageInput;

        if(!senderId){
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
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
            type,
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

        if (message === 'Chat is archived') {
            return archivedChat(res, message);
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

type ReactionParams = {
    activityId: string;
    messageId: string;
};

function forbiddenChat(res: Response) {
    return res.status(403).json({
        ok: false,
        error: {
            code: 'FORBIDDEN',
            message: 'Only the activity host or participants can access this chat',
        },
    });
}

function unauthorized(res: Response) {
    return res.status(401).json({
        ok: false,
        error: {
            code: 'UNAUTHORIZED',
            message: 'Authenticated user is required',
        },
    });
}

/** Read-only archive: history stays readable, writes stop. */
function archivedChat(res: Response, message: string) {
    return res.status(403).json({
        ok: false,
        error: { code: 'CHAT_ARCHIVED', message },
    });
}

export async function toggleReactionHandler(req: Request<ReactionParams>, res: Response) {
    try {
        const uid = req.auth?.uid;
        const { activityId, messageId } = req.params;
        // Shape already enforced by `validateBody(toggleReactionSchema)` —
        // `emoji` is one of the supported reactions.
        const { emoji } = req.body as ToggleReactionInput;

        if (!uid) return unauthorized(res);

        if (!activityId?.trim() || !messageId?.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId and messageId are required',
                },
            });
        }

        const canAccessChat = await canAccessActivityChat(activityId, uid);
        if (!canAccessChat) return forbiddenChat(res);

        const result = await toggleReaction(activityId, messageId, uid, emoji);

        return res.status(200).json({ ok: true, data: result });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Activity not found' || message === 'Message not found') {
            return res.status(404).json({
                ok: false,
                error: { code: 'NOT_FOUND', message },
            });
        }

        if (message === 'Chat is archived') {
            return archivedChat(res, message);
        }

        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

export async function getReactionsHandler(req: Request<ReactionParams>, res: Response) {
    try {
        const uid = req.auth?.uid;
        const { activityId, messageId } = req.params;

        if (!uid) return unauthorized(res);

        if (!activityId?.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        }

        const canAccessChat = await canAccessActivityChat(activityId, uid);
        if (!canAccessChat) return forbiddenChat(res);

        const data = messageId?.trim()
            ? await getMessageReactions(activityId, messageId)
            : await getReactions(activityId);

        return res.status(200).json({ ok: true, data });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Activity not found') {
            return res.status(404).json({
                ok: false,
                error: { code: 'NOT_FOUND', message },
            });
        }

        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

type PollParams = {
    activityId: string;
    pollId: string;
};

function badRequest(res: Response, message: string) {
    return res.status(400).json({
        ok: false,
        error: { code: 'EMPTY_INPUT', message },
    });
}

export async function createPollHandler(req: Request<PollParams>, res: Response) {
    try {
        const uid = req.auth?.uid;
        const { activityId } = req.params;
        // Shape already enforced by `validateBody(createPollSchema)` —
        // non-blank question, 2–6 non-blank options.
        const { question, options } = req.body as CreatePollInput;

        if (!uid) return unauthorized(res);
        if (!activityId?.trim()) return badRequest(res, 'activityId is required');

        const canAccessChat = await canAccessActivityChat(activityId, uid);
        if (!canAccessChat) return forbiddenChat(res);

        const result = await createPoll(activityId, uid, question, options);

        return res.status(201).json({ ok: true, data: result });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Activity not found') {
            return res.status(404).json({
                ok: false,
                error: { code: 'NOT_FOUND', message },
            });
        }

        if (message === 'Chat is archived') {
            return archivedChat(res, message);
        }

        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

export async function getPollsHandler(req: Request<PollParams>, res: Response) {
    try {
        const uid = req.auth?.uid;
        const { activityId } = req.params;

        if (!uid) return unauthorized(res);
        if (!activityId?.trim()) return badRequest(res, 'activityId is required');

        const canAccessChat = await canAccessActivityChat(activityId, uid);
        if (!canAccessChat) return forbiddenChat(res);

        const polls = await getPolls(activityId);

        return res.status(200).json({ ok: true, data: polls });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Activity not found') {
            return res.status(404).json({
                ok: false,
                error: { code: 'NOT_FOUND', message },
            });
        }

        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

export async function votePollHandler(req: Request<PollParams>, res: Response) {
    try {
        const uid = req.auth?.uid;
        const { activityId, pollId } = req.params;
        // Shape already enforced by `validateBody(votePollSchema)`.
        const { optionIndex } = req.body as VotePollInput;

        if (!uid) return unauthorized(res);
        if (!activityId?.trim() || !pollId?.trim()) {
            return badRequest(res, 'activityId and pollId are required');
        }

        const canAccessChat = await canAccessActivityChat(activityId, uid);
        if (!canAccessChat) return forbiddenChat(res);

        const result = await votePoll(activityId, pollId, uid, optionIndex);

        return res.status(200).json({ ok: true, data: result });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Activity not found' || message === 'Poll not found') {
            return res.status(404).json({
                ok: false,
                error: { code: 'NOT_FOUND', message },
            });
        }

        if (message === 'Chat is archived') {
            return archivedChat(res, message);
        }

        if (message === 'optionIndex is out of range') {
            return res.status(400).json({
                ok: false,
                error: { code: 'INVALID_INPUT', message },
            });
        }

        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

import type { Request, Response } from 'express';
import { getTyping, setTyping } from './typing.service.js';

type GetTypingParams = {
    activityId: string,
    uid: string;
};

export async function setTypingHandler(req: Request, res: Response) {
   try{
    const { activityId, uid, isTyping } = req.body as {
        activityId?: unknown,
        uid?: unknown,
        isTyping?: unknown,
    };

    if (typeof activityId !== 'string' || typeof uid !== 'string'){
        return res.status(400).json({
            ok: false,
            error: {
                code: 'INVALID_INPUT',
                message: 'activityId and uid must be strings',
            },
        });
    }

    if (typeof isTyping !== 'boolean'){
        return res.status(400).json({
            ok: false,
            error: {
                code: 'INVALID_INPUT',
                message: 'isTyping must be a boolean'
            },
        });
    }

    if (!activityId.trim() || !uid.trim()){
        return res.status(400).json({
            ok: false,
            error: {
                code: 'EMPTY_INPUT',
                message: 'activityId and uid are required',
            },
        });
    }

    await setTyping(activityId, uid, isTyping);

    return res.status(200).json({
        ok: true,
        data: {
            activityId: activityId.trim(),
            uid: uid.trim(),
            isTyping,
        },
    });
   } catch (error){
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

export async function getTypingHandler(req: Request<GetTypingParams>, res: Response) {
    try{
        const { activityId, uid } = req.params;

        if (!uid.trim()){
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'uid are required'
                },
            });
        }

        if (!activityId.trim()){
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId are required'
                },
            });
        }

        const typing = await getTyping(activityId, uid);

        if (!typing){
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message: 'Typing status not found',
                },
            });
        }

        return res.status(200).json({
            ok: true,
            data: typing,
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
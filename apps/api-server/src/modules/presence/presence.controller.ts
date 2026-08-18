import type { Request, Response } from 'express';
import { getPresence, setPresence } from './presence.service.js';

type GetPresenceParams = {
    uid: string;
};

export async function setPresenceHandler(req: Request, res: Response) {
    try {
        const {uid, state} = req.body as {
            uid?: string;
            state?: unknown;
        };

        if (typeof uid !== 'string'){
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_UID',
                    message: 'uid must be a string',
                },
            });
        }

        if (state !== 'online' && state !== 'offline'){
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_STATE',
                    message: 'State must be online or offline',
                },
            });
        }

        if (!uid.trim()){
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_UID',
                    message: 'uid is required',
                },
            });
        }

        await setPresence(uid, state);

        return res.status(200).json({
            ok: true,
            data: {
                uid: uid.trim(),
                state,
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

export async function getPresenceHandler(req: Request<GetPresenceParams>, res: Response) {
    try{
        const { uid } = req.params;

        if (!uid.trim()){
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'uid is required',
                },
            });
        }

        const presence = await getPresence(uid);

        if(!presence){
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message: 'Presence not found'
                },
            });
        }

        return res.status(200).json({
            ok: true,
            data: presence,
        });
    } catch (error){
        const message = error instanceof Error ? error.message : "Unknown error";
        
        return res.status(500).json({
            ok: false,
            error: {
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}
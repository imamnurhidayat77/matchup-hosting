import type { NextFunction, Request, Response } from 'express';
import { auth } from '../database/firebase.js'


export async function requireAuth(
    req: Request,
    res: Response,
    next: NextFunction) {
    try {
        const authorization = req.header('Authorization');

        if (!authorization || !authorization.startsWith("Bearer ")) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Missing or invalid Authorization header',
                },
            });
        }
        const idToken = authorization?.slice('Bearer '.length).trim();

        if (!idToken) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Missing Firebase ID token',
                },
            });
        }

        const decodedToken = await auth.verifyIdToken(idToken);

        req.auth = {
            uid: decodedToken.uid,
            token: decodedToken,
        };

        next();
    } catch (error){
        return res.status(401).json({
            ok: false,
            error: {
                code: 'UNAUTHORIZED',
                message: 'Invalid or expired Firebase ID token',
            },
        });
    }
}

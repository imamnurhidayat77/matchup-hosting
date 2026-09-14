import type { NextFunction, Request, Response } from 'express';
import { auth, firestore } from '../database/firebase.js';
import { adminUids } from '../config/env.js';


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

        // Suspension enforcement (admin members panel): a user whose doc
        // carries `status: 'suspended'` loses API access immediately, even
        // with a still-valid ID token. Docs without the field (including
        // pre-suspension docs and non-existent docs) default to active, so
        // this is backwards compatible. A failed lookup fails OPEN —
        // availability wins over enforcement on infra errors; the status
        // is enforced whenever it is readable.
        try {
            const userSnap = await firestore
                .collection('users')
                .doc(decodedToken.uid)
                .get();
            const status = userSnap.exists
                ? userSnap.data()?.status
                : undefined;
            if (status === 'suspended') {
                return res.status(403).json({
                    ok: false,
                    error: {
                        code: 'ACCOUNT_SUSPENDED',
                        message: 'Account suspended',
                    },
                });
            }
        } catch {
            // Fail open (see above).
        }

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

/**
 * Admin gate for triage routes (report list/resolve/dismiss). Must run
 * after [requireAuth] — returns 401 without a verified uid, 403 when
 * the uid is not in `ADMIN_UIDS`. An empty allowlist denies everyone
 * (fail-closed) so the routes are safe by default.
 */
export function requireAdmin(
    req: Request,
    res: Response,
    next: NextFunction,
) {
    const uid = req.auth?.uid;
    if (!uid) {
        return res.status(401).json({
            ok: false,
            error: {
                code: 'UNAUTHORIZED',
                message: 'Authenticated user is required',
            },
        });
    }
    if (!adminUids().includes(uid)) {
        return res.status(403).json({
            ok: false,
            error: {
                code: 'FORBIDDEN',
                message: 'Admin access is required',
            },
        });
    }
    next();
}

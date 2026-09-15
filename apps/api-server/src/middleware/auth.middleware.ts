import type { NextFunction, Request, Response } from 'express';
import { auth, firestore } from '../database/firebase.js';
import { adminUids } from '../config/env.js';


type VerifiedIdentity = {
    uid: string;
    token: Awaited<ReturnType<typeof auth.verifyIdToken>>;
};

/** Verifies the Bearer token. Returns the identity or the 401 message. */
async function verifyBearer(
    req: Request,
): Promise<
    | { ok: true; identity: VerifiedIdentity }
    | { ok: false; message: string }
> {
    const authorization = req.header('Authorization');

    if (!authorization || !authorization.startsWith('Bearer ')) {
        return { ok: false, message: 'Missing or invalid Authorization header' };
    }
    const idToken = authorization?.slice('Bearer '.length).trim();

    if (!idToken) {
        return { ok: false, message: 'Missing Firebase ID token' };
    }

    try {
        const decodedToken = await auth.verifyIdToken(idToken);
        return {
            ok: true,
            identity: { uid: decodedToken.uid, token: decodedToken },
        };
    } catch (error) {
        // Log the Firebase error code server-side only (auth/id-token-expired
        // vs auth/id-token-revoked vs auth/invalid-id-token …). The client
        // keeps the generic message so token validity details never leak.
        const code =
            typeof error === 'object' && error !== null && 'code' in error
                ? String((error as { code: unknown }).code)
                : 'unknown';
        console.warn(`[auth] verifyIdToken rejected: ${code}`);
        return { ok: false, message: 'Invalid or expired Firebase ID token' };
    }
}

/**
 * Suspension enforcement (admin members panel): a user whose doc carries
 * `status: 'suspended'` loses API access immediately, even with a
 * still-valid ID token. Docs without the field (including pre-suspension
 * docs and non-existent docs) default to active, so this is backwards
 * compatible. A failed lookup fails OPEN — availability wins over
 * enforcement on infra errors; the status is enforced whenever it is
 * readable. Returns true when the request was rejected.
 */
async function rejectIfSuspended(
    uid: string,
    res: Response,
): Promise<boolean> {
    try {
        const userSnap = await firestore.collection('users').doc(uid).get();
        const status = userSnap.exists ? userSnap.data()?.status : undefined;
        if (status === 'suspended') {
            res.status(403).json({
                ok: false,
                error: {
                    code: 'ACCOUNT_SUSPENDED',
                    message: 'Account suspended',
                },
            });
            return true;
        }
    } catch {
        // Fail open (see above).
    }
    return false;
}

function unauthorized(res: Response, message: string) {
    return res.status(401).json({
        ok: false,
        error: {
            code: 'UNAUTHORIZED',
            message,
        },
    });
}

export async function requireAuth(
    req: Request,
    res: Response,
    next: NextFunction,
) {
    const verified = await verifyBearer(req);
    if (!verified.ok) {
        return unauthorized(res, verified.message);
    }
    if (await rejectIfSuspended(verified.identity.uid, res)) {
        return;
    }
    req.auth = {
        uid: verified.identity.uid,
        token: verified.identity.token,
    };
    next();
}

/**
 * Token verification WITHOUT the suspension gate. Used exclusively by the
 * user-facing appeals endpoints: a suspended user must still be able to
 * submit and track an appeal against their own suspension — otherwise the
 * suspension flow has no recourse. Never use this for general routes.
 */
export async function requireAuthAllowSuspended(
    req: Request,
    res: Response,
    next: NextFunction,
) {
    const verified = await verifyBearer(req);
    if (!verified.ok) {
        return unauthorized(res, verified.message);
    }
    req.auth = {
        uid: verified.identity.uid,
        token: verified.identity.token,
    };
    next();
}

/**
 * Admin gate for triage routes (report list/resolve/dismiss). Must run
 * after [requireAuth] — returns 401 without a verified uid, 403 when
 * the uid is not an admin.
 *
 * Admin sources (either grants access):
 *   1. Firestore `admins/{uid}` doc exists — managed from the Firebase
 *      Console (or any Admin SDK script), no server restart needed.
 *   2. `ADMIN_UIDS` env allowlist — bootstrap fallback so the first
 *      admin can be set before any DB row exists.
 *
 * Fail-closed: an unreadable `admins` lookup denies (unlike the
 * suspension check, which fails open for availability — an admin gate
 * must never fail open).
 */
export async function requireAdmin(
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
    if (adminUids().includes(uid)) {
        next();
        return;
    }
    try {
        const adminSnap = await firestore.collection('admins').doc(uid).get();
        if (adminSnap.exists) {
            next();
            return;
        }
    } catch {
        // Fall through to 403 — fail closed (see above).
    }
    return res.status(403).json({
        ok: false,
        error: {
            code: 'FORBIDDEN',
            message: 'Admin access is required',
        },
    });
}

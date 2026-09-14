import express from 'express';
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

// requireAdmin itself never touches Firebase, but importing the middleware
// module pulls database/firebase.js — mock it so no Admin SDK init runs.
vi.mock('../database/firebase.js', () => ({
    auth: { verifyIdToken: vi.fn() },
    firestore: {},
    rtdb: {},
}));

import { requireAdmin } from './auth.middleware.js';

/**
 * Fail-closed proof for the admin gate: with the default test env
 * (`ADMIN_UIDS` unset), EVERY authenticated uid is denied. Uses the real
 * middleware + real env parsing — no mocks — so this breaks loudly if
 * the allowlist ever defaults open.
 */
function createAdminApp() {
    const app = express();
    app.get('/admin-only', requireAdmin, (_req, res) => {
        res.status(200).json({ ok: true });
    });
    // Simulate requireAuth having run first.
    app.get('/admin-only-authed', (req, _res, next) => {
        req.auth = { uid: 'some-user', token: {} as never };
        next();
    }, requireAdmin, (_req, res) => {
        res.status(200).json({ ok: true });
    });
    return app;
}

describe('requireAdmin', () => {
    it('without prior auth => 401 UNAUTHORIZED', async () => {
        const response = await request(createAdminApp()).get('/admin-only');
        expect(response.status).toBe(401);
        expect(response.body).toEqual({
            ok: false,
            error: {
                code: 'UNAUTHORIZED',
                message: 'Authenticated user is required',
            },
        });
    });

    it('with non-allowlisted uid and empty ADMIN_UIDS => 403 FORBIDDEN', async () => {
        const response = await request(createAdminApp()).get(
            '/admin-only-authed',
        );
        expect(response.status).toBe(403);
        expect(response.body).toEqual({
            ok: false,
            error: {
                code: 'FORBIDDEN',
                message: 'Admin access is required',
            },
        });
    });
});

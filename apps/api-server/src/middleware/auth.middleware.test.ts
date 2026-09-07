import express from 'express';
import request from 'supertest';
import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../database/firebase.js', () => {
  return {
    auth: {
      verifyIdToken: vi.fn(),
    },
  };
});

import { auth } from '../database/firebase.js';
import { requireAuth } from './auth.middleware.js';

function createProtectedApp() {
  const app = express();

  app.get('/protected', requireAuth, (req, res) => {
    res.status(200).json({
      ok: true,
      data: {
        uid: req.auth?.uid,
        email: req.auth?.token.email,
      },
    });
  });

  return app;
}

describe('requireAuth middleware', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('when Authorization header is missing => expected 401 w/ UNAUTHORIZED', async () => {
    const app = createProtectedApp();

    const response = await request(app).get('/protected');

    expect(response.status).toBe(401);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Missing or invalid Authorization header',
      },
    });
    expect(auth.verifyIdToken).not.toHaveBeenCalled();
  });

  it('when Authorization header is not Bearer token => expected 401 w/ UNAUTHORIZED', async () => {
    const app = createProtectedApp();

    const response = await request(app)
      .get('/protected')
      .set('Authorization', 'Token abc');

    expect(response.status).toBe(401);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Missing or invalid Authorization header',
      },
    });
    expect(auth.verifyIdToken).not.toHaveBeenCalled();
  });

  it('when Bearer token is blank => expected 401 w/ UNAUTHORIZED', async () => {
    const app = createProtectedApp();

    const response = await request(app)
      .get('/protected')
      .set('Authorization', 'Bearer ');

    expect(response.status).toBe(401);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Missing or invalid Authorization header',
      },
    });
    expect(auth.verifyIdToken).not.toHaveBeenCalled();
  });

  it('when Firebase token verification fails => expected 401 w/ UNAUTHORIZED', async () => {
    vi.mocked(auth.verifyIdToken).mockRejectedValueOnce(new Error('invalid token'));

    const app = createProtectedApp();

    const response = await request(app)
      .get('/protected')
      .set('Authorization', 'Bearer invalid-token');

    expect(response.status).toBe(401);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Invalid or expired Firebase ID token',
      },
    });
    expect(auth.verifyIdToken).toHaveBeenCalledWith('invalid-token');
  });

  it('when Firebase token is valid => expected 200', async () => {
    vi.mocked(auth.verifyIdToken).mockResolvedValueOnce({
      uid: 'test-uid-1',
      email: 'user@example.com',
    } as never);

    const app = createProtectedApp();

    const response = await request(app)
      .get('/protected')
      .set('Authorization', 'Bearer valid-token');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      ok: true,
      data: {
        uid: 'test-uid-1',
        email: 'user@example.com',
      },
    });
    expect(auth.verifyIdToken).toHaveBeenCalledWith('valid-token');
  });
});

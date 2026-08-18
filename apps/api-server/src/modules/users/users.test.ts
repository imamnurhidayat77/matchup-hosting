import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

vi.mock('./users.service.js', () => {
  return {
    createUser: vi.fn().mockResolvedValue(undefined),
    getUserByAuthUid: vi.fn(),
  };
});

import { createApp } from '../../app/app.js';
import * as usersService from './users.service.js';

describe('users routes', () => {
  it('creates a user with POST /users', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/users')
      .send({
        authUid: 'test-uid-1',
        email: 'user@example.com',
      });

    expect(response.status).toBe(201);
    expect(response.body).toEqual({
      ok: true,
      data: {
        authUid: 'test-uid-1',
        email: 'user@example.com',
      },
    });
  });

  it('gets a user with GET /users/:authUid', async () => {
    vi.mocked(usersService.getUserByAuthUid).mockResolvedValueOnce({
      authUid: 'test-uid-1',
      email: 'user@example.com',
      createdAt: {
        toDate: () => new Date('2026-08-18T00:00:00Z'),
      } as never,
    });

    const app = createApp();

    const response = await request(app).get('/users/test-uid-1');

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      ok: true,
      data: {
        authUid: 'test-uid-1',
        email: 'user@example.com',
      },
    });
  });

  it('returns 404 from GET /users/:authUid when user is not found', async () => {
    vi.mocked(usersService.getUserByAuthUid).mockResolvedValueOnce(null);

    const app = createApp();

    const response = await request(app).get('/users/missing-user');

    expect(response.status).toBe(404);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'NOT_FOUND',
        message: 'User not found',
      },
    });
  });
  
  it('returns 400 from POST /users when input is invalid', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/users')
      .send({
        authUid: '',
        email: 123,
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_INPUT_TYPE',
        message: 'authUid and email must be strings',
      },
    });
  });

    it('returns 409 from POST /users when user already exists', async () => {
    vi.mocked(usersService.createUser).mockRejectedValueOnce(
      new Error('User already exists'),
    );

    const app = createApp();

    const response = await request(app)
      .post('/users')
      .send({
        authUid: 'test-uid-1',
        email: 'user@example.com',
      });

    expect(response.status).toBe(409);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'CONFLICT',
        message: 'User already exists',
      },
    });
  });
});
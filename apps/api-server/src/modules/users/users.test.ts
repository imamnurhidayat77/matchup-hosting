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

  /*
########################################################################  
      Test section for typing POST route
########################################################################
*/

  it('creates a user with POST /users => expected 200', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/api/users')
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

  it('POST /users when input is invalid => expected 400 w/ INVALID_INPUT', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/api/users')
      .send({
        authUid: '',
        email: 123,
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_INPUT',
        message: 'authUid and email must be strings',
      },
    });
  });

  it('POST /users when input is empty => expected 400 w/ EMPTY_INPUT', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/api/users')
      .send({
        authUid: '   ',
        email: '    ',
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'EMPTY_INPUT',
        message: 'authUid and email are required',
      },
    });
  });

  it('POST /users when user already exists => expected 409 w/ CONFLICT', async () => {
    vi.mocked(usersService.createUser).mockRejectedValueOnce(
      new Error('User already exists'),
    );

    const app = createApp();

    const response = await request(app)
      .post('/api/users')
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

  it('POST /users when email already exists => expected 409 w/ CONFLICT', async () => {
    vi.mocked(usersService.createUser).mockRejectedValueOnce(
      new Error('Email already in use'),
    );

    const app = createApp();

    const response = await request(app)
      .post('/api/users')
      .send({
        authUid: 'test-uid-1',
        email: 'user@example.com',
      });

    expect(response.status).toBe(409);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'CONFLICT',
        message: 'Email already in use',
      },
    });
  });

  it('POST /users when server throws => expected 500 w/ INTERNAL_ERROR', async () => {
    vi.mocked(usersService.createUser).mockRejectedValueOnce(
      new Error('Unknown error'),
    );

    const app = createApp();

    const response = await request(app)
      .post('/api/users')
      .send({
        authUid: 'test-uid-1',
        email: 'user@example.com',
      });

    expect(response.status).toBe(500);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Unknown error',
      },
    });
  });

  /*
  ########################################################################  
        Test section for typing GET route
  ########################################################################
  */

  it('gets a user with GET /users/:authUid => expected 200', async () => {
    vi.mocked(usersService.getUserByAuthUid).mockResolvedValueOnce({
      authUid: 'test-uid-1',
      email: 'user@example.com',
      createdAt: {
        toDate: () => new Date('2026-08-18T00:00:00Z'),
      } as never,
    });

    const app = createApp();

    const response = await request(app).get('/api/users/test-uid-1');

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      ok: true,
      data: {
        authUid: 'test-uid-1',
        email: 'user@example.com',
      },
    });
  });

  it('GET /users/:authUid when user is not found => expected 404 w/ NOT_FOUND', async () => {
    vi.mocked(usersService.getUserByAuthUid).mockResolvedValueOnce(null);

    const app = createApp();

    const response = await request(app).get('/api/users/missing-user');

    expect(response.status).toBe(404);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'NOT_FOUND',
        message: 'User not found',
      },
    });
  });


});

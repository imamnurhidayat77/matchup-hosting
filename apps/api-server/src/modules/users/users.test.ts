import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

vi.mock('./users.service.js', () => {
  return {
    createUser: vi.fn().mockResolvedValue(undefined),
    getUserByAuthUid: vi.fn(),
  };
});

import { createApp } from '../../app/app.js';
import { getUserByAuthUid } from './users.service.js';

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
    vi.mocked(getUserByAuthUid).mockResolvedValueOnce({
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
});
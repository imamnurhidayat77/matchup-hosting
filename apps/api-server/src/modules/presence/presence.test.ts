import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

vi.mock('./presence.service.js', () => {
  return {
    setPresence: vi.fn().mockResolvedValue(undefined),
    getPresence: vi.fn(),
  };
});

import { createApp } from '../../app/app.js';
import * as presenceService from './presence.service.js';

describe('presence routes', () => {

  /* 
########################################################################  
      Test section for presence POST route
########################################################################
  */

  it('sets presence with POST /presence', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/api/presence')
      .send({
        uid: 'test-uid-1',
        state: 'online',
      });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      ok: true,
      data: {
        uid: 'test-uid-1',
        state: 'online',
      },
    });
  });

  it('returns 400 from POST /presence when state is invalid', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/api/presence')
      .send({
        uid: 'test-uid-1',
        state: 'busy',
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_STATE',
        message: 'state must be online or offline',
      },
    });
  });

  it('returns 400 from POST /presence when uid is blank', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/api/presence')
      .send({
        uid: '   ',
        state: 'online',
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'EMPTY_INPUT',
        message: 'uid is required',
      },
    });
  });

  it('returns 400 from POST /presence when uid is not a string', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/api/presence')
      .send({
        uid: 123,
        state: 'online',
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_INPUT',
        message: 'uid must be a string',
      },
    });
  });

  it('returns 500 from POST /presence when service throws', async () => {
    vi.mocked(presenceService.setPresence).mockRejectedValueOnce(
      new Error('Unknown error'),
    );

    const app = createApp();

    const response = await request(app)
      .post('/api/presence')
      .send({
        uid: 'test-uid-1',
        state: 'online',
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
      Test section for presence GET route
########################################################################
  */

  it('gets presence with GET /presence/:uid', async () => {
    vi.mocked(presenceService.getPresence).mockResolvedValueOnce({
      state: 'online',
      lastChanged: 1787000000000,
    });

    const app = createApp();

    const response = await request(app).get('/api/presence/test-uid-1');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      ok: true,
      data: {
        state: 'online',
        lastChanged: 1787000000000,
      },
    });
  });

  it('return 400 from GET /presence/:id when uid is blank', async () => {

    const app = createApp();
    const response = await request(app).get('/api/presence/%20%20')

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'EMPTY_INPUT',
        message: 'uid is required',
      },
    })
  })

  it('returns 404 from GET /presence/:uid when presence is not found', async () => {
    vi.mocked(presenceService.getPresence).mockResolvedValueOnce(null);

    const app = createApp();

    const response = await request(app).get('/api/presence/missing-user');

    expect(response.status).toBe(404);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'NOT_FOUND',
        message: 'presence not found',
      },
    });
  });

  it('returns 500 from GET /presence/:uid when service throws', async () => {
    vi.mocked(presenceService.getPresence).mockRejectedValueOnce(new Error('Unknown error'));

    const app = createApp();
    const response = await request(app).get('/api/presence/test-uid-1');

    expect(response.status).toBe(500);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Unknown error',
      },
    });
  });
});

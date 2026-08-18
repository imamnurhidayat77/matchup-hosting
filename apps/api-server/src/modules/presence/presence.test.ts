import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

vi.mock('./presence.service.js', () => {
  return {
    setPresence: vi.fn().mockResolvedValue(undefined),
    getPresence: vi.fn(),
  };
});

import { createApp } from '../../app/app.js';
import { getPresence } from './presence.service.js';

describe('presence routes', () => {
  it('sets presence with POST /presence', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/presence')
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

  it('gets presence with GET /presence/:uid', async () => {
    vi.mocked(getPresence).mockResolvedValueOnce({
      state: 'online',
      lastChanged: 1787000000000,
    });

    const app = createApp();

    const response = await request(app).get('/presence/test-uid-1');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      ok: true,
      data: {
        state: 'online',
        lastChanged: 1787000000000,
      },
    });
  });
});
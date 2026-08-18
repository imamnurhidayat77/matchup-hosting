import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

vi.mock('./typing.service.js', () => {
  return {
    setTyping: vi.fn().mockResolvedValue(undefined),
    getTyping: vi.fn(),
  };
});

import { createApp } from '../../app/app.js';
import { getTyping } from './typing.service.js';

describe('typing routes', () => {
  it('sets typing with POST /typing', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/typing')
      .send({
        activityId: 'activity-1',
        uid: 'test-uid-1',
        isTyping: true,
      });

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      ok: true,
      data: {
        activityId: 'activity-1',
        uid: 'test-uid-1',
        isTyping: true,
      },
    });
  });

  it('gets typing with GET /typing/:activityId/:uid', async () => {
    vi.mocked(getTyping).mockResolvedValueOnce({
      isTyping: true,
    });

    const app = createApp();

    const response = await request(app).get('/typing/activity-1/test-uid-1');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      ok: true,
      data: {
        isTyping: true,
      },
    });
  });
});
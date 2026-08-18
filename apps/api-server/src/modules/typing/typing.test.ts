import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

vi.mock('./typing.service.js', () => {
  return {
    setTyping: vi.fn().mockResolvedValue(undefined),
    getTyping: vi.fn(),
  };
});

import { createApp } from '../../app/app.js';
import * as typingService from './typing.service.js';

describe('typing routes', () => {

  /* 
########################################################################  
      Test section for typing POST route
########################################################################
  */

  it('sets typing with POST /typing => expected 200', async () => {
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

  it('POST /typing when isTyping is not a boolean => expected 400 w/ INVALID_INPUT', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/typing')
      .send({
        activityId: 'activity-1',
        uid: 'test-uid-1',
        isTyping: 'yes',
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_INPUT',
        message: 'isTyping must be a boolean',
      },
    });
  });

  it('POST /typing when activityId is not a string => expected 400 w/ INVALID_INPUT', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/typing')
      .send({
        activityId: 123,
        uid: 'test-uid-1',
        isTyping: true,
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_INPUT',
        message: 'activityId and uid must be strings',
      },
    });
  });

  it('POST /typing when activityId is blank => expected 400 w/ INVALID_INPUT', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/typing')
      .send({
        activityId: '   ',
        uid: 'test-uid-1',
        isTyping: true,
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_INPUT',
        message: 'activityId and uid are required',
      },
    });
  });

  it('POST /typing when uid is not a string => expected 400 w/ INVALID_INPUT', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/typing')
      .send({
        activityId: 'activity-1',
        uid: 123456,
        isTyping: true,
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_INPUT',
        message: 'activityId and uid must be strings',
      },
    });
  });

  it('POST /typing when uid is blank => expected 400 w/ INVALID_INPUT', async () => {
    const app = createApp();

    const response = await request(app)
      .post('/typing')
      .send({
        activityId: 'activity-1',
        uid: '   ',
        isTyping: true,
      });

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_INPUT',
        message: 'activityId and uid are required',
      },
    });
  });

  it('POST /typing when service throws => expected 500 w/ INTERNAL_ERROR', async () => {
    vi.mocked(typingService.setTyping).mockRejectedValueOnce(
      new Error('Unexpected failure'),
    );

    const app = createApp();

    const response = await request(app)
      .post('/typing')
      .send({
        activityId: 'activity-1',
        uid: 'test-uid-1',
        isTyping: true,
      });

    expect(response.status).toBe(500);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Unexpected failure',
      },
    });
  });

  /* 
########################################################################  
      Test section for typing GET route
########################################################################
  */

  it('gets typing with GET /typing/:activityId/:uid => expected 200', async () => {
    vi.mocked(typingService.getTyping).mockResolvedValueOnce({
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

  it('GET /typing/:activityId/:uid when activityId is blank => expected 400 w/ INVALID_INPUT', async () => {

    const app = createApp();

    const response = await request(app).get('/typing/%20%20/test-uid-1');

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_INPUT',
        message: 'activityId and uid are required'
      },
    });
  });

  it('GET /typing/:activityId/:uid when uid is blank => expected 400 w/ INVALID_INPUT', async () => {

    const app = createApp();

    const response = await request(app).get('/typing/activity-1/%20%20');

    expect(response.status).toBe(400);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'INVALID_INPUT',
        message: 'activityId and uid are required'
      },
    });
  });

  it('GET /typing/:activityId/:uid when isTyping record is not found => expected 404 w/ NOT_FOUND', async () => {
    vi.mocked(typingService.getTyping).mockResolvedValueOnce(null);

    const app = createApp();

    const response = await request(app).get('/typing/activity-1/missing-user');

    expect(response.status).toBe(404);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'NOT_FOUND',
        message: 'Typing status not found'
      },
    });
  });

  it('GET /typing/:activityId/:uid when service throws +> expected 500 w/ INTERNAL_ERROR', async () => {
    vi.mocked(typingService.getTyping).mockRejectedValueOnce(
      new Error('Unknown error'),
    );

    const app = createApp();

    const response = await request(app).get('/typing/activity-1/test-uid-1');

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
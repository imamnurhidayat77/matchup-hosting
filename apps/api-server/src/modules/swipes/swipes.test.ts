import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

vi.mock('./swipes.service.js', () => {
  return {
    saveSwipeDecision: vi.fn().mockResolvedValue(undefined),
    getSwipeDecision: vi.fn(),
    listSwipeDecisions: vi.fn(),
  };
});

import { createApp } from '../../app/app.js';
import * as swipesService from './swipes.service.js';

describe('swipes routes', () => {
  describe('POST /swipes', () => {
    it('saves swipe decision with POST /swipes => expected 200', async () => {
      const app = createApp();

      const response = await request(app).post('/api/swipes').send({
        uid: 'test-uid-1',
        activityId: 'activity-1',
        decision: 'join',
      });

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        ok: true,
        data: {
          uid: 'test-uid-1',
          activityId: 'activity-1',
          decision: 'join',
        },
      });
    });

    it('when uid or activityId are not strings => expected 400 w/ INVALID_INPUT', async () => {
      const app = createApp();

      const response = await request(app).post('/api/swipes').send({
        uid: 123,
        activityId: 'activity-1',
        decision: 'join',
      });

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'INVALID_INPUT',
          message: 'uid and activityId must be strings',
        },
      });
    });

    it('when decision is invalid => expected 400 w/ INVALID_INPUT', async () => {
      const app = createApp();

      const response = await request(app).post('/api/swipes').send({
        uid: 'test-uid-1',
        activityId: 'activity-1',
        decision: 'maybe',
      });

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'INVALID_INPUT',
          message: 'decision must be pass or join',
        },
      });
    });

    it.each([
      {
        name: 'uid is blank',
        body: {
          uid: '   ',
          activityId: 'activity-1',
          decision: 'join',
        },
      },
      {
        name: 'activityId is blank',
        body: {
          uid: 'test-uid-1',
          activityId: '   ',
          decision: 'join',
        },
      },
    ])('when $name => expected 400 w/ EMPTY_INPUT', async ({ body }) => {
      const app = createApp();

      const response = await request(app).post('/api/swipes').send(body);

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'uid and activityId are required',
        },
      });
    });

    it('when activity is not found => expected 400 w/ NOT_FOUND', async () => {
      vi.mocked(swipesService.saveSwipeDecision).mockRejectedValueOnce(
        new Error('Activity not found'),
      );

      const app = createApp();

      const response = await request(app).post('/api/swipes').send({
        uid: 'test-uid-1',
        activityId: 'missing-activity',
        decision: 'join',
      });

      expect(response.status).toBe(404);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'NOT_FOUND',
          message: 'Activity not found',
        },
      });
    });

    it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
      vi.mocked(swipesService.saveSwipeDecision).mockRejectedValueOnce(
        new Error('Unknown error'),
      );

      const app = createApp();

      const response = await request(app).post('/api/swipes').send({
        uid: 'test-uid-1',
        activityId: 'activity-1',
        decision: 'join',
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
  });

  describe('GET /swipes/:uid/:activityId', () => {
    it('success-path from GET method => expected 200', async () => {
      vi.mocked(swipesService.getSwipeDecision).mockResolvedValueOnce({
        swipeId: 'activity-1',
        uid: 'test-uid-1',
        activityId: 'activity-1',
        decision: 'join',
        createdAt: { toDate: () => new Date('2026-08-20T00:00:00Z') } as never,
        updatedAt: { toDate: () => new Date('2026-08-20T00:00:00Z') } as never,
      });

      const app = createApp();

      const response = await request(app).get('/api/swipes/test-uid-1/activity-1');

      expect(response.status).toBe(200);
      expect(response.body).toMatchObject({
        ok: true,
        data: {
          swipeId: 'activity-1',
          uid: 'test-uid-1',
          activityId: 'activity-1',
          decision: 'join',
        },
      });
    });

    it.each([
      '/api/swipes/%20%20/activity-1',
      '/api/swipes/test-uid-1/%20%20',
    ])('when route params are blank: %s ==> expected 400 w/ EMPTY_INPUT', async (path) => {
      const app = createApp();

      const response = await request(app).get(path);

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'uid and activityId are required',
        },
      });
    });

    it('when swipe decision is not found => expected 400 w/ NOT_FOUND', async () => {
      vi.mocked(swipesService.getSwipeDecision).mockResolvedValueOnce(null);

      const app = createApp();

      const response = await request(app).get('/api/swipes/test-uid-1/activity-1');

      expect(response.status).toBe(404);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'NOT_FOUND',
          message: 'Swipe decision not found',
        },
      });
    });

    it('when service throws => expected 500 w/ INTERNAL_ERROR', async () => {
      vi.mocked(swipesService.getSwipeDecision).mockRejectedValueOnce(
        new Error('Unknown error'),
      );

      const app = createApp();

      const response = await request(app).get('/api/swipes/test-uid-1/activity-1');

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

  describe('GET /swipes/:uid', () => {
    it('success-path from GET method => expected 200', async () => {
      vi.mocked(swipesService.listSwipeDecisions).mockResolvedValueOnce([
        {
          swipeId: 'activity-2',
          uid: 'test-uid-1',
          activityId: 'activity-2',
          decision: 'pass',
          createdAt: { toDate: () => new Date('2026-08-20T00:00:00Z') } as never,
          updatedAt: { toDate: () => new Date('2026-08-20T01:00:00Z') } as never,
        },
      ]);

      const app = createApp();

      const response = await request(app).get('/api/swipes/test-uid-1');

      expect(response.status).toBe(200);
      expect(response.body).toMatchObject({
        ok: true,
        data: [
          {
            swipeId: 'activity-2',
            uid: 'test-uid-1',
            activityId: 'activity-2',
            decision: 'pass',
          },
        ],
      });
    });

    it('when uid is blank => expected 400 w/ EMPTY_INPUT', async () => {
      const app = createApp();

      const response = await request(app).get('/api/swipes/%20%20');

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'uid is required',
        },
      });
    });

    it('when no swipe decisions exist => expected 200 with empty array', async () => {
      vi.mocked(swipesService.listSwipeDecisions).mockResolvedValueOnce([]);

      const app = createApp();

      const response = await request(app).get('/api/swipes/test-uid-1');

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        ok: true,
        data: [],
      });
    });

    it('when service throws => expected 500 w/ INTERNAL_ERROR', async () => {
      vi.mocked(swipesService.listSwipeDecisions).mockRejectedValueOnce(
        new Error('Unknown error'),
      );

      const app = createApp();

      const response = await request(app).get('/api/swipes/test-uid-1');

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
});

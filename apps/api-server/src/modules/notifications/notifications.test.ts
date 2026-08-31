import request from 'supertest';
import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('./notifications.service.js', () => {
  return {
    createNotification: vi.fn().mockResolvedValue({ notificationId: 'notification-1' }),
    listNotifications: vi.fn(),
    markNotificationRead: vi.fn().mockResolvedValue(undefined),
  };
});

vi.mock('../../middleware/auth.middleware.js', () => {
  return {
    requireAuth: vi.fn((req, _res, next) => {
      req.auth = {
        uid: 'test-uid-1',
        token: {} as never,
      };
      next();
    }),
  };
});

import { createApp } from '../../app/app.js';
import * as notificationsService from './notifications.service.js';

describe('notifications routes', () => {
  describe('POST /api/notifications', () => {
    beforeEach(() => {
      vi.clearAllMocks();
    });

    it('when request body is valid => expected 201', async () => {
      const app = createApp();

      const response = await request(app).post('/api/notifications').send({
        recipientUid: 'test-uid-1',
        type: 'activity_joined',
        title: 'New participant',
        body: 'A user joined your activity',
        activityId: 'activity-1',
        senderUid: 'test-uid-2',
      });

      expect(response.status).toBe(201);
      expect(response.body).toEqual({
        ok: true,
        data: {
          notificationId: 'notification-1',
        },
      });
      expect(notificationsService.createNotification).toHaveBeenCalledWith({
        recipientUid: 'test-uid-1',
        type: 'activity_joined',
        title: 'New participant',
        body: 'A user joined your activity',
        activityId: 'activity-1',
        senderUid: 'test-uid-2',
      });
    });

    it('when required fields are not strings => expected 400 w/ INVALID_INPUT', async () => {
      const app = createApp();

      const response = await request(app).post('/api/notifications').send({
        recipientUid: 123,
        type: 'activity_joined',
        title: 'New participant',
        body: 'A user joined your activity',
      });

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'INVALID_INPUT',
          message: 'recipientUid, type, title, and body must be strings',
        },
      });
    });

    it('when optional fields are not strings => expected 400 w/ INVALID_INPUT', async () => {
      const app = createApp();

      const response = await request(app).post('/api/notifications').send({
        recipientUid: 'test-uid-1',
        type: 'activity_joined',
        title: 'New participant',
        body: 'A user joined your activity',
        activityId: 123,
      });

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'INVALID_INPUT',
          message: 'activityId and senderUid must be strings when provided',
        },
      });
    });

    it('when type is invalid => expected 400 w/ INVALID_INPUT', async () => {
      const app = createApp();

      const response = await request(app).post('/api/notifications').send({
        recipientUid: 'test-uid-1',
        type: 'unknown',
        title: 'New participant',
        body: 'A user joined your activity',
      });

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'INVALID_INPUT',
          message: 'type must be activity_reminder, activity_interest, activity_joined, activity_left, participant_removed, chat_message, or system',
        },
      });
    });

    it('when required fields are blank => expected 400 w/ EMPTY_INPUT', async () => {
      const app = createApp();

      const response = await request(app).post('/api/notifications').send({
        recipientUid: '   ',
        type: 'activity_joined',
        title: 'New participant',
        body: 'A user joined your activity',
      });

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'recipientUid, title, and body are required',
        },
      });
    });

    it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
      vi.mocked(notificationsService.createNotification).mockRejectedValueOnce(
        new Error('Unknown error'),
      );

      const app = createApp();

      const response = await request(app).post('/api/notifications').send({
        recipientUid: 'test-uid-1',
        type: 'activity_joined',
        title: 'New participant',
        body: 'A user joined your activity',
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

  describe('GET /api/notifications/me', () => {
    beforeEach(() => {
      vi.clearAllMocks();
    });

    it('when authenticated user requests own notifications => expected 200', async () => {
      vi.mocked(notificationsService.listNotifications).mockResolvedValueOnce([
        {
          notificationId: 'notification-1',
          recipientUid: 'test-uid-1',
          type: 'activity_joined',
          title: 'New participant',
          body: 'A user joined your activity',
          isRead: false,
          createdAt: { toDate: () => new Date('2026-08-30T00:00:00Z') } as never,
          activityId: 'activity-1',
          senderUid: 'test-uid-2',
        },
      ]);

      const app = createApp();

      const response = await request(app).get('/api/notifications/me');

      expect(response.status).toBe(200);
      expect(response.body).toMatchObject({
        ok: true,
        data: [
          {
            notificationId: 'notification-1',
            recipientUid: 'test-uid-1',
            type: 'activity_joined',
            title: 'New participant',
            body: 'A user joined your activity',
            isRead: false,
            activityId: 'activity-1',
            senderUid: 'test-uid-2',
          },
        ],
      });
      expect(notificationsService.listNotifications).toHaveBeenCalledWith('test-uid-1');
    });

    it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
      vi.mocked(notificationsService.listNotifications).mockRejectedValueOnce(
        new Error('Unknown error'),
      );

      const app = createApp();

      const response = await request(app).get('/api/notifications/me');

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

  describe('GET /api/notifications/:uid', () => {
    beforeEach(() => {
      vi.clearAllMocks();
    });

    it('when notifications exist => expected 200', async () => {
      vi.mocked(notificationsService.listNotifications).mockResolvedValueOnce([
        {
          notificationId: 'notification-1',
          recipientUid: 'test-uid-1',
          type: 'activity_joined',
          title: 'New participant',
          body: 'A user joined your activity',
          isRead: false,
          createdAt: { toDate: () => new Date('2026-08-30T00:00:00Z') } as never,
          activityId: 'activity-1',
          senderUid: 'test-uid-2',
        },
      ]);

      const app = createApp();

      const response = await request(app).get('/api/notifications/test-uid-1');

      expect(response.status).toBe(200);
      expect(response.body).toMatchObject({
        ok: true,
        data: [
          {
            notificationId: 'notification-1',
            recipientUid: 'test-uid-1',
            type: 'activity_joined',
            title: 'New participant',
            body: 'A user joined your activity',
            isRead: false,
            activityId: 'activity-1',
            senderUid: 'test-uid-2',
          },
        ],
      });
    });

    it('when uid is blank => expected 400 w/ EMPTY_INPUT', async () => {
      const app = createApp();

      const response = await request(app).get('/api/notifications/%20%20');

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'uid is required',
        },
      });
    });

    it('when authenticated user accesses another user notifications => expected 403 w/ FORBIDDEN', async () => {
      const app = createApp();

      const response = await request(app).get('/api/notifications/other-uid');

      expect(response.status).toBe(403);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'FORBIDDEN',
          message: 'You can only access your own notifications',
        },
      });
    });

    it('when no notifications exist => expected 200', async () => {
      vi.mocked(notificationsService.listNotifications).mockResolvedValueOnce([]);

      const app = createApp();

      const response = await request(app).get('/api/notifications/test-uid-1');

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        ok: true,
        data: [],
      });
    });

    it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
      vi.mocked(notificationsService.listNotifications).mockRejectedValueOnce(
        new Error('Unknown error'),
      );

      const app = createApp();

      const response = await request(app).get('/api/notifications/test-uid-1');

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

  describe('PATCH /api/notifications/me/:notificationId/read', () => {
    beforeEach(() => {
      vi.clearAllMocks();
    });

    it('when authenticated user marks own notification read => expected 200', async () => {
      const app = createApp();

      const response = await request(app).patch(
        '/api/notifications/me/notification-1/read',
      );

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        ok: true,
        data: {
          uid: 'test-uid-1',
          notificationId: 'notification-1',
          isRead: true,
        },
      });
      expect(notificationsService.markNotificationRead).toHaveBeenCalledWith(
        'test-uid-1',
        'notification-1',
      );
    });

    it('when notificationId is blank => expected 400 w/ EMPTY_INPUT', async () => {
      const app = createApp();

      const response = await request(app).patch('/api/notifications/me/%20%20/read');

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'notificationId is required',
        },
      });
    });

    it('when notification is not found => expected 404 w/ NOT_FOUND', async () => {
      vi.mocked(notificationsService.markNotificationRead).mockRejectedValueOnce(
        new Error('Notification not found'),
      );

      const app = createApp();

      const response = await request(app).patch(
        '/api/notifications/me/missing-notification/read',
      );

      expect(response.status).toBe(404);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'NOT_FOUND',
          message: 'Notification not found',
        },
      });
    });

    it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
      vi.mocked(notificationsService.markNotificationRead).mockRejectedValueOnce(
        new Error('Unknown error'),
      );

      const app = createApp();

      const response = await request(app).patch(
        '/api/notifications/me/notification-1/read',
      );

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

  describe('PATCH /api/notifications/:uid/:notificationId/read', () => {
    beforeEach(() => {
      vi.clearAllMocks();
    });

    it('when request is valid => expected 200', async () => {
      const app = createApp();

      const response = await request(app).patch(
        '/api/notifications/test-uid-1/notification-1/read',
      );

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        ok: true,
        data: {
          uid: 'test-uid-1',
          notificationId: 'notification-1',
          isRead: true,
        },
      });
      expect(notificationsService.markNotificationRead).toHaveBeenCalledWith(
        'test-uid-1',
        'notification-1',
      );
    });

    it('when uid is blank => expected 400 w/ EMPTY_INPUT', async () => {
      const app = createApp();

      const response = await request(app).patch(
        '/api/notifications/%20%20/notification-1/read',
      );

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'uid and notificationId are required',
        },
      });
    });

    it('when notificationId is blank => expected 400 w/ EMPTY_INPUT', async () => {
      const app = createApp();

      const response = await request(app).patch(
        '/api/notifications/test-uid-1/%20%20/read',
      );

      expect(response.status).toBe(400);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'uid and notificationId are required',
        },
      });
    });

    it('when authenticated user updates another user notification => expected 403 w/ FORBIDDEN', async () => {
      const app = createApp();

      const response = await request(app).patch(
        '/api/notifications/other-uid/notification-1/read',
      );

      expect(response.status).toBe(403);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'FORBIDDEN',
          message: 'You can only update your own notifications',
        },
      });
    });

    it('when notification is not found => expected 404 w/ NOT_FOUND', async () => {
      vi.mocked(notificationsService.markNotificationRead).mockRejectedValueOnce(
        new Error('Notification not found'),
      );

      const app = createApp();

      const response = await request(app).patch(
        '/api/notifications/test-uid-1/missing-notification/read',
      );

      expect(response.status).toBe(404);
      expect(response.body).toEqual({
        ok: false,
        error: {
          code: 'NOT_FOUND',
          message: 'Notification not found',
        },
      });
    });

    it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
      vi.mocked(notificationsService.markNotificationRead).mockRejectedValueOnce(
        new Error('Unknown error'),
      );

      const app = createApp();

      const response = await request(app).patch(
        '/api/notifications/test-uid-1/notification-1/read',
      );

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

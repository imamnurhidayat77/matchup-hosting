import request from 'supertest';
import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('./chat.service.js', () => {
    return {
        sendMessage: vi.fn().mockResolvedValue({ messageId: 'msg-1' }),
        getMessages: vi.fn(),
    };
});

vi.mock('../activities/activity-participants.service.js', () => {
    return {
        canAccessActivityChat: vi.fn().mockResolvedValue(true),
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
import * as chatService from './chat.service.js';
import * as activityParticipantsService from '../activities/activity-participants.service.js';

describe('chat routes', () => {
    /* 
  ########################################################################  
        Test section for chat POST route
  ########################################################################
    */
    describe('POST /api/chat/messages', () => {
        beforeEach(() => {
            vi.clearAllMocks();
        });

        it('when request body is valid => expected 201', async () => {
            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 'activity-1',
                text: 'Hello from chat',
                type: 'text',
            });

            expect(response.status).toBe(201);
            expect(response.body).toEqual({
                ok: true,
                data: {
                    messageId: 'msg-1',
                },
            });
            expect(activityParticipantsService.canAccessActivityChat).toHaveBeenCalledWith(
                'activity-1',
                'test-uid-1',
            );
        });

        it('when activityId is not a string => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 123,
                text: 'Hello from chat',
                type: 'text',
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'activityId and text must be strings',
                },
            });
        });

        it('when text is not a string => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 'activity-1',
                text: 123,
                type: 'text',
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'activityId and text must be strings',
                },
            });
        });

        it('when type is invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 'activity-1',
                text: 'Hello from chat',
                type: 'image',
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'type must be text or system',
                },
            });
        });

        it.each([
            {
                name: 'activityId is blank',
                body: { activityId: '   ', text: 'Hello', type: 'text' },
            },
            {
                name: 'text is blank',
                body: { activityId: 'activity-1', text: '   ', type: 'text' },
            },
        ])('when $name => expected 400 w/ EMPTY_INPUT', async ({ body }) => {
            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send(body);

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId and text are required',
                },
            });
        });

        it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
            vi.mocked(chatService.sendMessage).mockRejectedValueOnce(
                new Error('Unknown error'),
            );

            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 'activity-1',
                text: 'Hello from chat',
                type: 'text',
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

        it('when authenticated user is not host or participant => expected 403 w/ FORBIDDEN', async () => {
            vi.mocked(activityParticipantsService.canAccessActivityChat).mockResolvedValueOnce(false);

            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 'activity-1',
                text: 'Hello from chat',
                type: 'text',
            });

            expect(response.status).toBe(403);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'Only the activity host or participants can access this chat',
                },
            });
            expect(chatService.sendMessage).not.toHaveBeenCalled();
        });

        it('when activity is not found => expected 404 w/ NOT_FOUND', async () => {
            vi.mocked(activityParticipantsService.canAccessActivityChat).mockRejectedValueOnce(
                new Error('Activity not found'),
            );

            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 'missing-activity',
                text: 'Hello from chat',
                type: 'text',
            });

            expect(response.status).toBe(404);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message: 'Activity not found',
                },
            });
            expect(chatService.sendMessage).not.toHaveBeenCalled();
        });
    });

    describe('GET /api/chat/:activityId/messages', () => {
        beforeEach(() => {
            vi.clearAllMocks();
        });

        it('when messages exist => expected 200', async () => {
            vi.mocked(chatService.getMessages).mockResolvedValueOnce([
                {
                    messageId: 'msg-1',
                    senderId: 'test-uid-1',
                    text: 'Hello from chat',
                    type: 'text',
                    timestamp: 1787000000000,
                },
            ]);

            const app = createApp();

            const response = await request(app).get('/api/chat/activity-1/messages');

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                ok: true,
                data: [
                    {
                        messageId: 'msg-1',
                        senderId: 'test-uid-1',
                        text: 'Hello from chat',
                        type: 'text',
                        timestamp: 1787000000000,
                    },
                ],
            });
            expect(activityParticipantsService.canAccessActivityChat).toHaveBeenCalledWith(
                'activity-1',
                'test-uid-1',
            );
        });

        it('when activityId is blank => expected 400 w/ EMPTY_INPUT', async () => {
            const app = createApp();

            const response = await request(app).get('/api/chat/%20%20/messages');

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        });

        it('when no messages exist => expected 200', async () => {
            vi.mocked(chatService.getMessages).mockResolvedValueOnce([]);

            const app = createApp();

            const response = await request(app).get('/api/chat/activity-empty/messages');

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                ok: true,
                data: [],
            });
        });

        it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
            vi.mocked(chatService.getMessages).mockRejectedValueOnce(new Error('Unknown error'));

            const app = createApp();

            const response = await request(app).get('/api/chat/activity-1/messages');

            expect(response.status).toBe(500);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INTERNAL_ERROR',
                    message: 'Unknown error',
                },
            });
        });

        it('when authenticated user is not host or participant => expected 403 w/ FORBIDDEN', async () => {
            vi.mocked(activityParticipantsService.canAccessActivityChat).mockResolvedValueOnce(false);

            const app = createApp();

            const response = await request(app).get('/api/chat/activity-1/messages');

            expect(response.status).toBe(403);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'Only the activity host or participants can access this chat',
                },
            });
            expect(chatService.getMessages).not.toHaveBeenCalled();
        });

        it('when activity is not found => expected 404 w/ NOT_FOUND', async () => {
            vi.mocked(activityParticipantsService.canAccessActivityChat).mockRejectedValueOnce(
                new Error('Activity not found'),
            );

            const app = createApp();

            const response = await request(app).get('/api/chat/missing-activity/messages');

            expect(response.status).toBe(404);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message: 'Activity not found',
                },
            });
            expect(chatService.getMessages).not.toHaveBeenCalled();
        });
    })
})

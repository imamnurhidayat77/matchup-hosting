import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

vi.mock('./chat.service.js', () => {
    return {
        sendMessage: vi.fn().mockResolvedValue({ messageId: 'msg-1' }),
        getMessages: vi.fn(),
    };
});

import { createApp } from '../../app/app.js';
import * as chatService from './chat.service.js';

describe('chat routes', () => {
    /* 
  ########################################################################  
        Test section for chat POST route
  ########################################################################
    */
    describe('POST /chat/messages', () => {
        it('send message with POST /chat/messages => expected 201', async () => {
            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 'activity-1',
                senderId: 'test-uid-1',
                text: 'Hello from chat',
                type: 'text',
            });

            expect(response.status).toBe(201);
            expect(response.body).toEqual({
                ok: true,
                data: {
                    messageId: 'msg-1'
                },
            });
        });

        it('send request when activityId, senderId, or text are not strings => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 123,
                senderId: 'test-uid-1',
                text: 'Hello from chat',
                type: 'text',
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'activityId, senderId, and text must be strings',
                },
            });
        });

        it('send request when type is invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 'activity-1',
                senderId: 'test-uid-1',
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
                body: { activityId: '   ', senderId: 'test-uid-1', text: 'Hello', type: 'text' },
            },
            {
                name: 'senderId is blank',
                body: { activityId: 'activity-1', senderId: '   ', text: 'Hello', type: 'text' },
            },
            {
                name: 'text is blank',
                body: { activityId: 'activity-1', senderId: 'test-uid-1', text: '   ', type: 'text' },
            },
        ])('returns 400 when $name', async ({ body }) => {
            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send(body);

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId, senderId, and text are required',
                },
            });
        });

        it('send request when service throws => expected 500 w/ INTERNAL_ERROR', async () => {
            vi.mocked(chatService.sendMessage).mockRejectedValueOnce(new Error('Unknown error'));

            const app = createApp();

            const response = await request(app).post('/api/chat/messages').send({
                activityId: 'activity-1',
                senderId: 'test-uid-1',
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
    });

    describe('GET /chat/:activityId/messages', () => {
        it('returns 200 with messages', async () => {
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
        });

        it('returns 400 when activityId is blank', async () => {
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

        it('returns 200 with empty array when no messages exist', async () => {
            vi.mocked(chatService.getMessages).mockResolvedValueOnce([]);

            const app = createApp();

            const response = await request(app).get('/api/chat/activity-empty/messages');

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                ok: true,
                data: [],
            });
        });

        it('returns 500 when service throws', async () => {
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
    })
})

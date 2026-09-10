import request from 'supertest';
import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('./reports.service.js', () => {
    return {
        submitReport: vi.fn().mockResolvedValue({ reportId: 'report-1' }),
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
import * as reportsService from './reports.service.js';

describe('reports routes', () => {
    describe('POST /api/reports', () => {
        beforeEach(() => {
            vi.clearAllMocks();
        });

        it('when request body is valid => expected 201', async () => {
            const app = createApp();

            const response = await request(app).post('/api/reports').send({
                targetId: 'activity-1',
                targetType: 'activity',
                reason: 'Spam / Fake activity',
                details: 'Looks copy-pasted',
            });

            expect(response.status).toBe(201);
            expect(response.body).toEqual({
                ok: true,
                data: {
                    reportId: 'report-1',
                },
            });
            expect(reportsService.submitReport).toHaveBeenCalledWith({
                reporterId: 'test-uid-1',
                targetId: 'activity-1',
                targetType: 'activity',
                reason: 'Spam / Fake activity',
                details: 'Looks copy-pasted',
            });
        });

        it('when details is omitted => expected 201 without details', async () => {
            const app = createApp();

            const response = await request(app).post('/api/reports').send({
                targetId: 'user-2',
                targetType: 'user',
                reason: 'Harassment',
            });

            expect(response.status).toBe(201);
            expect(reportsService.submitReport).toHaveBeenCalledWith({
                reporterId: 'test-uid-1',
                targetId: 'user-2',
                targetType: 'user',
                reason: 'Harassment',
            });
        });

        it.each([
            {
                name: 'targetId is not a string',
                body: { targetId: 123, targetType: 'user', reason: 'Spam' },
            },
            {
                name: 'reason is not a string',
                body: { targetId: 'user-2', targetType: 'user', reason: 123 },
            },
            {
                name: 'details is not a string',
                body: {
                    targetId: 'user-2',
                    targetType: 'user',
                    reason: 'Spam',
                    details: 123,
                },
            },
        ])('when $name => expected 400 w/ INVALID_INPUT', async ({ body }) => {
            const app = createApp();

            const response = await request(app).post('/api/reports').send(body);

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'targetId and reason must be strings',
                },
            });
            expect(reportsService.submitReport).not.toHaveBeenCalled();
        });

        it('when targetType is invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/reports').send({
                targetId: 'activity-1',
                targetType: 'group',
                reason: 'Spam',
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'targetType must be user or activity',
                },
            });
            expect(reportsService.submitReport).not.toHaveBeenCalled();
        });

        it.each([
            {
                name: 'targetId is blank',
                body: { targetId: '   ', targetType: 'user', reason: 'Spam' },
            },
            {
                name: 'reason is blank',
                body: { targetId: 'user-2', targetType: 'user', reason: '   ' },
            },
        ])('when $name => expected 400 w/ EMPTY_INPUT', async ({ body }) => {
            const app = createApp();

            const response = await request(app).post('/api/reports').send(body);

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'targetId and reason are required',
                },
            });
            expect(reportsService.submitReport).not.toHaveBeenCalled();
        });

        it('when target does not exist => expected 404 w/ NOT_FOUND', async () => {
            vi.mocked(reportsService.submitReport).mockRejectedValueOnce(
                new Error('Target not found'),
            );

            const app = createApp();

            const response = await request(app).post('/api/reports').send({
                targetId: 'missing-activity',
                targetType: 'activity',
                reason: 'Spam',
            });

            expect(response.status).toBe(404);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message: 'Target not found',
                },
            });
        });

        it('when user reports themselves => expected 400 w/ INVALID_INPUT', async () => {
            vi.mocked(reportsService.submitReport).mockRejectedValueOnce(
                new Error('cannot report yourself'),
            );

            const app = createApp();

            const response = await request(app).post('/api/reports').send({
                targetId: 'test-uid-1',
                targetType: 'user',
                reason: 'Spam',
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'cannot report yourself',
                },
            });
        });

        it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
            vi.mocked(reportsService.submitReport).mockRejectedValueOnce(
                new Error('Unknown error'),
            );

            const app = createApp();

            const response = await request(app).post('/api/reports').send({
                targetId: 'activity-1',
                targetType: 'activity',
                reason: 'Spam',
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
});

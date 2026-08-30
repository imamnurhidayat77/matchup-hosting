import request from 'supertest';
import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('./activities.service.js', () => {
    return {
        createActivity: vi.fn().mockResolvedValue({ activityId: 'activity-1' }),
        getActivityById: vi.fn(),
        listActivities: vi.fn(),
        updateActivity: vi.fn().mockResolvedValue(undefined),
        updateActivityStatus: vi.fn().mockResolvedValue(undefined),
    };
});

vi.mock('./activity-participants.service.js', () => {
    return {
        joinActivity: vi.fn().mockResolvedValue(undefined),
        getParticipants: vi.fn(),
        leaveActivity: vi.fn().mockResolvedValue(undefined),
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
import * as activitiesService from './activities.service.js';
import * as activityParticipantsService from './activity-participants.service.js';

describe('activities routes', () => {
    describe('POST /api/activities', () => {
        beforeEach(() => {
            vi.clearAllMocks();
        });

        it('when request body is valid => expected 201', async () => {
            const app = createApp();

            const response = await request(app).post('/api/activities').send({
                title: 'Evening Futsal',
                sportType: 'futsal',
                description: 'Casual 5v5 session',
                locationName: 'Auckland Domain',
                geohash: 'rckq2m',
                startTime: '2026-08-19T18:30:00+12:00',
                skillLevel: 'any',
                capacity: 10,
            });

            expect(response.status).toBe(201);
            expect(response.body).toEqual({
                ok: true,
                data: {
                    activityId: 'activity-1',
                },
            });
        });

        it('when required string fields are not strings => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/activities').send({
                title: 123,
                sportType: 'futsal',
                description: 'Casual 5v5 session',
                locationName: 'Auckland Domain',
                geohash: 'rckq2m',
                startTime: '2026-08-19T18:30:00+12:00',
                skillLevel: 'any',
                capacity: 10,
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'title, sportType, description, locationName, geohash, and startTime must be strings',
                },
            });
        });

        it('when optional string fields are invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/activities').send({
                title: 'Evening Futsal',
                sportType: 'futsal',
                description: 'Casual 5v5 session',
                locationName: 'Auckland Domain',
                address: 123,
                geohash: 'rckq2m',
                startTime: '2026-08-19T18:30:00+12:00',
                skillLevel: 'any',
                capacity: 10,
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'address, endTime, and coverImageUrl must be strings when provided',
                },
            });
        });

        it('when skillLevel is invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/activities').send({
                title: 'Evening Futsal',
                sportType: 'futsal',
                description: 'Casual 5v5 session',
                locationName: 'Auckland Domain',
                geohash: 'rckq2m',
                startTime: '2026-08-19T18:30:00+12:00',
                skillLevel: 'expert',
                capacity: 10,
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'skillLevel must be beginner, intermediate, advanced, or any',
                },
            });
        });

        it('when capacity is invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/activities').send({
                title: 'Evening Futsal',
                sportType: 'futsal',
                description: 'Casual 5v5 session',
                locationName: 'Auckland Domain',
                geohash: 'rckq2m',
                startTime: '2026-08-19T18:30:00+12:00',
                skillLevel: 'any',
                capacity: 0,
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'capacity must be a positive integer',
                },
            });
        });

        it('when required string fields are blank => expected 400 w/ EMPTY_INPUT', async () => {
            const app = createApp();

            const response = await request(app).post('/api/activities').send({
                title: '   ',
                sportType: 'futsal',
                description: 'Casual 5v5 session',
                locationName: 'Auckland Domain',
                geohash: 'rckq2m',
                startTime: '2026-08-19T18:30:00+12:00',
                skillLevel: 'any',
                capacity: 10,
            });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'title, sportType, description, locationName, geohash, and startTime are required',
                },
            });
        });

        it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
            vi.mocked(activitiesService.createActivity).mockRejectedValueOnce(
                new Error('Unknown error'),
            );

            const app = createApp();

            const response = await request(app).post('/api/activities').send({
                title: 'Evening Futsal',
                sportType: 'futsal',
                description: 'Casual 5v5 session',
                locationName: 'Auckland Domain',
                geohash: 'rckq2m',
                startTime: '2026-08-19T18:30:00+12:00',
                skillLevel: 'any',
                capacity: 10,
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

    describe('PATCH /api/activities/:activityId', () => {
        beforeEach(() => {
            vi.clearAllMocks();
        });

        it('when request body is valid => expected 200', async () => {
            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1')
                .send({
                    title: 'Updated Futsal',
                    capacity: 12,
                    skillLevel: 'intermediate',
                });

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                ok: true,
                data: {
                    activityId: 'activity-1',
                },
            });
            expect(activitiesService.updateActivity).toHaveBeenCalledWith({
                activityId: 'activity-1',
                hostId: 'test-uid-1',
                title: 'Updated Futsal',
                skillLevel: 'intermediate',
                capacity: 12,
            });
        });

        it('when updated string field is not a string => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1')
                .send({
                    title: 123,
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'updated string fields must be strings',
                },
            });
        });

        it('when skillLevel is invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1')
                .send({
                    skillLevel: 'expert',
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'skillLevel must be beginner, intermediate, advanced, or any',
                },
            });
        });

        it('when capacity is invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1')
                .send({
                    capacity: 0,
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'capacity must be a positive integer',
                },
            });
        });

        it('when activityId is blank => expected 400 w/ EMPTY_INPUT', async () => {
            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/%20%20')
                .send({
                    title: 'Updated Futsal',
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        });

        it('when updated string field is blank => expected 400 w/ EMPTY_INPUT', async () => {
            vi.mocked(activitiesService.updateActivity).mockRejectedValueOnce(
                new Error('updated string fields cannot be blank'),
            );

            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1')
                .send({
                    title: '   ',
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'updated string fields cannot be blank',
                },
            });
        });

        it('when activity is not found => expected 404 w/ NOT_FOUND', async () => {
            vi.mocked(activitiesService.updateActivity).mockRejectedValueOnce(
                new Error('Activity not found'),
            );

            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/missing-activity')
                .send({
                    title: 'Updated Futsal',
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

        it('when authenticated user is not activity host => expected 403 w/ FORBIDDEN', async () => {
            vi.mocked(activitiesService.updateActivity).mockRejectedValueOnce(
                new Error('Only the activity host can update this activity'),
            );

            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1')
                .send({
                    title: 'Updated Futsal',
                });

            expect(response.status).toBe(403);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'Only the activity host can update this activity',
                },
            });
        });

        it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
            vi.mocked(activitiesService.updateActivity).mockRejectedValueOnce(
                new Error('Unknown error'),
            );

            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1')
                .send({
                    title: 'Updated Futsal',
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

    describe('PATCH /api/activities/:activityId/status', () => {
        beforeEach(() => {
            vi.clearAllMocks();
        });

        it('when request body is valid => expected 200', async () => {
            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1/status')
                .send({
                    status: 'cancelled',
                });

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                ok: true,
                data: {
                    activityId: 'activity-1',
                    status: 'cancelled',
                },
            });
            expect(activitiesService.updateActivityStatus).toHaveBeenCalledWith({
                activityId: 'activity-1',
                hostId: 'test-uid-1',
                status: 'cancelled',
            });
        });

        it('when status is not a string => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1/status')
                .send({
                    status: 123,
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'status must be a string',
                },
            });
        });

        it('when status is invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1/status')
                .send({
                    status: 'full',
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'status must be open, cancelled, completed, or removed',
                },
            });
        });

        it('when activityId is blank => expected 400 w/ EMPTY_INPUT', async () => {
            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/%20%20/status')
                .send({
                    status: 'cancelled',
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId and status are required',
                },
            });
        });

        it('when status is blank => expected 400 w/ EMPTY_INPUT', async () => {
            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1/status')
                .send({
                    status: '   ',
                });

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId and status are required',
                },
            });
        });

        it('when activity is not found => expected 404 w/ NOT_FOUND', async () => {
            vi.mocked(activitiesService.updateActivityStatus).mockRejectedValueOnce(
                new Error('Activity not found'),
            );

            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/missing-activity/status')
                .send({
                    status: 'cancelled',
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

        it('when authenticated user is not activity host => expected 403 w/ FORBIDDEN', async () => {
            vi.mocked(activitiesService.updateActivityStatus).mockRejectedValueOnce(
                new Error('Only the activity host can update this activity'),
            );

            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1/status')
                .send({
                    status: 'cancelled',
                });

            expect(response.status).toBe(403);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'Only the activity host can update this activity',
                },
            });
        });

        it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
            vi.mocked(activitiesService.updateActivityStatus).mockRejectedValueOnce(
                new Error('Unknown error'),
            );

            const app = createApp();

            const response = await request(app)
                .patch('/api/activities/activity-1/status')
                .send({
                    status: 'cancelled',
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


    /* 
  ########################################################################  
        Test section for activity participants POST route
  ########################################################################
    */
    describe('POST /api/activities/:activityId/participants', () => {
        beforeEach(() => {
            vi.clearAllMocks();
        });

        it('when request is valid => expected 200', async () => {
            const app = createApp();

            const response = await request(app)
                .post('/api/activities/activity-1/participants')
                .send({});

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                ok: true,
                data: {
                    activityId: 'activity-1',
                    uid: 'test-uid-1',
                },
            });
        });

        it('when activityId is blank => expected 400 w/ EMPTY_INPUT', async () => {
            const app = createApp();

            const response = await request(app)
                .post('/api/activities/%20%20/participants')
                .send({});

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        });

        it.each([
            'Activity is not open for joining',
            'Activity is full',
            'User already joined this activity',
        ])('when service rejects with %s => expected 409 w/ CONFLICT', async (message) => {
            vi.mocked(activityParticipantsService.joinActivity).mockRejectedValueOnce(
                new Error(message),
            );

            const app = createApp();

            const response = await request(app)
                .post('/api/activities/activity-1/participants')
                .send({});

            expect(response.status).toBe(409);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'CONFLICT',
                    message,
                },
            });
        });

        it('when activity is not found => expected 404 w/ NOT_FOUND', async () => {
            vi.mocked(activityParticipantsService.joinActivity).mockRejectedValueOnce(
                new Error('Activity not found'),
            );

            const app = createApp();

            const response = await request(app)
                .post('/api/activities/activity-1/participants')
                .send({});

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
            vi.mocked(activityParticipantsService.joinActivity).mockRejectedValueOnce(
                new Error('Unknown error'),
            );

            const app = createApp();

            const response = await request(app)
                .post('/api/activities/activity-1/participants')
                .send({});

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

    /* 
  ########################################################################  
        Test section for activities GET route
  ########################################################################
    */
    describe('GET /api/activities', () => {
        beforeEach(() => {
            vi.clearAllMocks();
        });

        it('when activities exist => expected 200', async () => {
            vi.mocked(activitiesService.listActivities).mockResolvedValueOnce([
                {
                    activityId: 'activity-1',
                    hostId: 'test-uid-1',
                    title: 'Evening Futsal',
                    sportType: 'futsal',
                    description: 'Casual 5v5 session',
                    locationName: 'Auckland Domain',
                    geohash: 'rckq2m',
                    startTime: '2026-08-19T18:30:00+12:00',
                    skillLevel: 'any',
                    capacity: 10,
                    participantCount: 0,
                    status: 'open',
                    createdAt: { toDate: () => new Date('2026-08-19T06:00:00Z') } as never,
                    updatedAt: { toDate: () => new Date('2026-08-19T06:00:00Z') } as never,
                },
            ]);

            const app = createApp();

            const response = await request(app).get('/api/activities');

            expect(response.status).toBe(200);
            expect(response.body).toMatchObject({
                ok: true,
                data: [
                    {
                        activityId: 'activity-1',
                        hostId: 'test-uid-1',
                        title: 'Evening Futsal',
                        sportType: 'futsal',
                        description: 'Casual 5v5 session',
                        locationName: 'Auckland Domain',
                        geohash: 'rckq2m',
                        startTime: '2026-08-19T18:30:00+12:00',
                        skillLevel: 'any',
                        capacity: 10,
                        participantCount: 0,
                        status: 'open',
                    },
                ],
            });
            expect(activitiesService.listActivities).toHaveBeenCalledWith({
                status: 'open',
                limit: 20,
            });
        });

        it('when filters are valid => expected 200', async () => {
            vi.mocked(activitiesService.listActivities).mockResolvedValueOnce([]);

            const app = createApp();

            const response = await request(app).get(
                '/api/activities?status=completed&sportType=futsal&skillLevel=any&limit=10',
            );

            expect(response.status).toBe(200);
            expect(response.body).toEqual({
                ok: true,
                data: [],
            });
            expect(activitiesService.listActivities).toHaveBeenCalledWith({
                status: 'completed',
                sportType: 'futsal',
                skillLevel: 'any',
                limit: 10,
            });
        });

        it('when status is invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).get('/api/activities?status=invalid');

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'status must be open, full, cancelled, completed, or removed',
                },
            });
        });

        it('when skillLevel is invalid => expected 400 w/ INVALID_INPUT', async () => {
            const app = createApp();

            const response = await request(app).get('/api/activities?skillLevel=expert');

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'skillLevel must be beginner, intermediate, advanced, or any',
                },
            });
        });

        it('when sportType is blank => expected 400 w/ EMPTY_INPUT', async () => {
            const app = createApp();

            const response = await request(app).get('/api/activities?sportType=%20%20');

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'sportType is required when provided',
                },
            });
        });

        it.each(['0', '51', '1.5', 'abc'])(
            'when limit is %s => expected 400 w/ INVALID_INPUT',
            async (limit) => {
                const app = createApp();

                const response = await request(app).get(`/api/activities?limit=${limit}`);

                expect(response.status).toBe(400);
                expect(response.body).toEqual({
                    ok: false,
                    error: {
                        code: 'INVALID_INPUT',
                        message: 'limit must be an integer between 1 and 50',
                    },
                });
            },
        );

        it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
            vi.mocked(activitiesService.listActivities).mockRejectedValueOnce(
                new Error('Unknown error'),
            );

            const app = createApp();

            const response = await request(app).get('/api/activities');

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

    describe('GET /api/activities/:activityId', () => {
        it('when activity exists => expected 200', async () => {
            vi.mocked(activitiesService.getActivityById).mockResolvedValueOnce({
                activityId: 'activity-1',
                hostId: 'test-uid-1',
                title: 'Evening Futsal',
                sportType: 'futsal',
                description: 'Casual 5v5 session',
                locationName: 'Auckland Domain',
                geohash: 'rckq2m',
                startTime: '2026-08-19T18:30:00+12:00',
                skillLevel: 'any',
                capacity: 10,
                participantCount: 0,
                status: 'open',
                createdAt: { toDate: () => new Date('2026-08-19T06:00:00Z') } as never,
                updatedAt: { toDate: () => new Date('2026-08-19T06:00:00Z') } as never,
            });

            const app = createApp();

            const response = await request(app).get('/api/activities/activity-1');

            expect(response.status).toBe(200);
            expect(response.body).toMatchObject({
                ok: true,
                data: {
                    activityId: 'activity-1',
                    hostId: 'test-uid-1',
                    title: 'Evening Futsal',
                    sportType: 'futsal',
                    description: 'Casual 5v5 session',
                    locationName: 'Auckland Domain',
                    geohash: 'rckq2m',
                    startTime: '2026-08-19T18:30:00+12:00',
                    skillLevel: 'any',
                    capacity: 10,
                    participantCount: 0,
                    status: 'open',
                },
            });
        });

        it('when activityId is blank => expected 400 w/ EMPTY_INPUT', async () => {
            const app = createApp();

            const response = await request(app).get('/api/activities/%20%20');

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        });

        it('when activity is not found => expected 404 w/ NOT_FOUND', async () => {
            vi.mocked(activitiesService.getActivityById).mockResolvedValueOnce(null);

            const app = createApp();

            const response = await request(app).get('/api/activities/missing-activity');

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
            vi.mocked(activitiesService.getActivityById).mockRejectedValueOnce(
                new Error('Unknown error'),
            );

            const app = createApp();

            const response = await request(app).get('/api/activities/activity-1');

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

/*
########################################################################  
    Test section for activity participants GET route
########################################################################
*/

describe('GET /api/activities/:activityId/participants', () => {
    it('when participants exist => expected 200', async () => {
        vi.mocked(activityParticipantsService.getParticipants).mockResolvedValueOnce([
            {
                participantId: 'test-uid-1',
                uid: 'test-uid-1',
                joinedAt: { toDate: () => new Date('2026-08-19T06:00:00Z') } as never,
            },
        ]);

        const app = createApp();

        const response = await request(app).get('/api/activities/activity-1/participants');

        expect(response.status).toBe(200);
        expect(response.body).toMatchObject({
            ok: true,
            data: [
                {
                    participantId: 'test-uid-1',
                    uid: 'test-uid-1',
                },
            ],
        });
    });

    it('when activityId is blank => expected 400 w/ EMPTY_INPUT', async () => {
        const app = createApp();

        const response = await request(app).get('/api/activities/%20%20/participants');

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            ok: false,
            error: {
                code: 'EMPTY_INPUT',
                message: 'activityId is required',
            },
        });
    });

    it('when no participants exist => expected 200', async () => {
        vi.mocked(activityParticipantsService.getParticipants).mockResolvedValueOnce([]);

        const app = createApp();

        const response = await request(app).get('/api/activities/activity-1/participants');

        expect(response.status).toBe(200);
        expect(response.body).toEqual({
            ok: true,
            data: [],
        });
    });

    it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
        vi.mocked(activityParticipantsService.getParticipants).mockRejectedValueOnce(
            new Error('Unknown error'),
        );

        const app = createApp();

        const response = await request(app).get('/api/activities/activity-1/participants');

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

describe('DELETE /api/activities/:activityId/participants/:uid', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it('when request is valid => expected 200', async () => {
        const app = createApp();

        const response = await request(app).delete(
            '/api/activities/activity-1/participants/test-uid-1',
        );

        expect(response.status).toBe(200);
        expect(response.body).toEqual({
            ok: true,
            data: {
                activityId: 'activity-1',
                uid: 'test-uid-1',
            },
        });
        expect(activityParticipantsService.leaveActivity).toHaveBeenCalledWith({
            activityId: 'activity-1',
            targetUid: 'test-uid-1',
            actorUid: 'test-uid-1',
        });
    });

    it('when activity host removes another participant => expected 200', async () => {
        const app = createApp();

        const response = await request(app).delete(
            '/api/activities/activity-1/participants/other-user',
        );

        expect(response.status).toBe(200);
        expect(response.body).toEqual({
            ok: true,
            data: {
                activityId: 'activity-1',
                uid: 'other-user',
            },
        });
        expect(activityParticipantsService.leaveActivity).toHaveBeenCalledWith({
            activityId: 'activity-1',
            targetUid: 'other-user',
            actorUid: 'test-uid-1',
        });
    });

    it('when activityId is blank => expected 400 w/ EMPTY_INPUT', async () => {
        const app = createApp();

        const response = await request(app).delete(
            '/api/activities/%20%20/participants/test-uid-1',
        );

        expect(response.status).toBe(400);
        expect(response.body).toEqual({
            ok: false,
            error: {
                code: 'EMPTY_INPUT',
                message: 'activityId is required',
            },
        });
    });

    it('when actor is neither participant nor activity host => expected 403 w/ FORBIDDEN', async () => {
        vi.mocked(activityParticipantsService.leaveActivity).mockRejectedValueOnce(
            new Error('Only the participant or activity host can remove this participant'),
        );

        const app = createApp();

        const response = await request(app).delete(
            '/api/activities/activity-1/participants/other-user',
        );

        expect(response.status).toBe(403);
        expect(response.body).toEqual({
            ok: false,
            error: {
                code: 'FORBIDDEN',
                message: 'Only the participant or activity host can remove this participant',
            },
        });
    });

    it.each(['Activity not found', 'Participant not found'])(
        'when service rejects with %s => expected 404 w/ NOT_FOUND',
        async (message) => {
            vi.mocked(activityParticipantsService.leaveActivity).mockRejectedValueOnce(
                new Error(message),
            );

            const app = createApp();

            const response = await request(app).delete(
                '/api/activities/activity-1/participants/test-uid-1',
            );

            expect(response.status).toBe(404);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message,
                },
            });
        },
    );

    it('when service throws unknown error => expected 500 w/ INTERNAL_ERROR', async () => {
        vi.mocked(activityParticipantsService.leaveActivity).mockRejectedValueOnce(
            new Error('Unknown error'),
        );

        const app = createApp();

        const response = await request(app).delete(
            '/api/activities/activity-1/participants/test-uid-1',
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

import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

vi.mock('./activities.service.js', () => {
    return {
        createActivity: vi.fn().mockResolvedValue({ activityId: 'activity-1' }),
        getActivityById: vi.fn(),
    };
});

import { createApp } from '../../app/app.js';
import * as activitiesService from './activities.service.js';

describe('activities routes', () => {

    /* 
  ########################################################################  
        Test section for activities POST route
  ########################################################################
    */
    describe('POST /activities', () => {
        it('creates activity with POST /activities => expected 201', async () => {
            const app = createApp();

            const response = await request(app).post('/activities').send({
                hostId: 'test-uid-1',
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

        it('returns 400 when required fields are not strings', async () => {
            const app = createApp();

            const response = await request(app).post('/activities').send({
                hostId: 123,
                title: 'Evening Futsal',
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
                    message:
                        'hostId, title, sportType, description, locationName, geohash, and startTime must be strings',
                },
            });
        });

        it('returns 400 when optional fields are not strings', async () => {
            const app = createApp();

            const response = await request(app).post('/activities').send({
                hostId: 'test-uid-1',
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

        it('returns 400 when skillLevel is invalid', async () => {
            const app = createApp();

            const response = await request(app).post('/activities').send({
                hostId: 'test-uid-1',
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

        it.each([0, -1, 1.5, '10'])(
            'returns 400 when capacity is invalid: %p',
            async (capacity) => {
                const app = createApp();

                const response = await request(app).post('/activities').send({
                    hostId: 'test-uid-1',
                    title: 'Evening Futsal',
                    sportType: 'futsal',
                    description: 'Casual 5v5 session',
                    locationName: 'Auckland Domain',
                    geohash: 'rckq2m',
                    startTime: '2026-08-19T18:30:00+12:00',
                    skillLevel: 'any',
                    capacity,
                });

                expect(response.status).toBe(400);
                expect(response.body).toEqual({
                    ok: false,
                    error: {
                        code: 'INVALID_INPUT',
                        message: 'capacity must be a positive integer',
                    },
                });
            },
        );

        it.each([
            {
                name: 'hostId is blank',
                body: {
                    hostId: '   ',
                    title: 'Evening Futsal',
                    sportType: 'futsal',
                    description: 'Casual 5v5 session',
                    locationName: 'Auckland Domain',
                    geohash: 'rckq2m',
                    startTime: '2026-08-19T18:30:00+12:00',
                    skillLevel: 'any',
                    capacity: 10,
                },
            },
            {
                name: 'title is blank',
                body: {
                    hostId: 'test-uid-1',
                    title: '   ',
                    sportType: 'futsal',
                    description: 'Casual 5v5 session',
                    locationName: 'Auckland Domain',
                    geohash: 'rckq2m',
                    startTime: '2026-08-19T18:30:00+12:00',
                    skillLevel: 'any',
                    capacity: 10,
                },
            },
            {
                name: 'sportType is blank',
                body: {
                    hostId: 'test-uid-1',
                    title: 'Evening Futsal',
                    sportType: '   ',
                    description: 'Casual 5v5 session',
                    locationName: 'Auckland Domain',
                    geohash: 'rckq2m',
                    startTime: '2026-08-19T18:30:00+12:00',
                    skillLevel: 'any',
                    capacity: 10,
                },
            },
            {
                name: 'description is blank',
                body: {
                    hostId: 'test-uid-1',
                    title: 'Evening Futsal',
                    sportType: 'futsal',
                    description: '   ',
                    locationName: 'Auckland Domain',
                    geohash: 'rckq2m',
                    startTime: '2026-08-19T18:30:00+12:00',
                    skillLevel: 'any',
                    capacity: 10,
                },
            },
            {
                name: 'locationName is blank',
                body: {
                    hostId: 'test-uid-1',
                    title: 'Evening Futsal',
                    sportType: 'futsal',
                    description: 'Casual 5v5 session',
                    locationName: '   ',
                    geohash: 'rckq2m',
                    startTime: '2026-08-19T18:30:00+12:00',
                    skillLevel: 'any',
                    capacity: 10,
                },
            },
            {
                name: 'geohash is blank',
                body: {
                    hostId: 'test-uid-1',
                    title: 'Evening Futsal',
                    sportType: 'futsal',
                    description: 'Casual 5v5 session',
                    locationName: 'Auckland Domain',
                    geohash: '   ',
                    startTime: '2026-08-19T18:30:00+12:00',
                    skillLevel: 'any',
                    capacity: 10,
                },
            },
            {
                name: 'startTime is blank',
                body: {
                    hostId: 'test-uid-1',
                    title: 'Evening Futsal',
                    sportType: 'futsal',
                    description: 'Casual 5v5 session',
                    locationName: 'Auckland Domain',
                    geohash: 'rckq2m',
                    startTime: '   ',
                    skillLevel: 'any',
                    capacity: 10,
                },
            },
        ])('returns 400 when $name', async ({ body }) => {
            const app = createApp();

            const response = await request(app).post('/activities').send(body);

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message:
                        'hostId, title, sportType, description, locationName, geohash, and startTime are required',
                },
            });
        });

        it('returns 500 when service throws', async () => {
            vi.mocked(activitiesService.createActivity).mockRejectedValueOnce(
                new Error('Unknown error'),
            );

            const app = createApp();

            const response = await request(app).post('/activities').send({
                hostId: 'test-uid-1',
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

    /* 
  ########################################################################  
        Test section for activities GET route
  ########################################################################
    */

    describe('GET /activities/:activityId', () => {
        it('returns 200 with activity', async () => {
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

            const response = await request(app).get('/activities/activity-1');

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

        it('returns 400 when activityId is blank', async () => {
            const app = createApp();

            const response = await request(app).get('/activities/%20%20');

            expect(response.status).toBe(400);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        });

        it('returns 404 when activity is not found', async () => {
            vi.mocked(activitiesService.getActivityById).mockResolvedValueOnce(null);

            const app = createApp();

            const response = await request(app).get('/activities/missing-activity');

            expect(response.status).toBe(404);
            expect(response.body).toEqual({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message: 'Activity not found',
                },
            });
        });

        it('returns 500 when service throws', async () => {
            vi.mocked(activitiesService.getActivityById).mockRejectedValueOnce(
                new Error('Unknown error'),
            );

            const app = createApp();

            const response = await request(app).get('/activities/activity-1');

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
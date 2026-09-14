import request from 'supertest';
import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('./members.service.js', () => ({
    ADMIN_MEMBERS_PAGE_LIMIT_DEFAULT: 20,
    ADMIN_MEMBERS_PAGE_LIMIT_MAX: 100,
    listMembers: vi.fn(),
    getMemberDetail: vi.fn(),
    setMemberStatus: vi.fn(),
    deleteMember: vi.fn().mockResolvedValue(undefined),
}));

vi.mock('./activities.service.js', () => ({
    ADMIN_ACTIVITIES_LIMIT_DEFAULT: 20,
    ADMIN_ACTIVITIES_LIMIT_MAX: 100,
    listAdminActivities: vi.fn(),
    setAdminActivityStatus: vi.fn().mockResolvedValue(undefined),
    deleteAdminActivity: vi.fn().mockResolvedValue(undefined),
}));

vi.mock('../../middleware/auth.middleware.js', () => ({
    requireAuth: vi.fn((req, _res, next) => {
        req.auth = { uid: 'admin-1', token: {} as never };
        next();
    }),
    requireAdmin: vi.fn((_req, _res, next) => {
        next();
    }),
}));

import { createApp } from '../../app/app.js';
import * as membersService from './members.service.js';
import * as activitiesService from './activities.service.js';

beforeEach(() => {
    vi.clearAllMocks();
});

describe('admin routes', () => {
    it('GET /api/admin/me returns the admin identity', async () => {
        const response = await request(createApp()).get('/api/admin/me');
        expect(response.status).toBe(200);
        expect(response.body).toEqual({
            ok: true,
            data: { uid: 'admin-1', email: null, admin: true },
        });
    });

    it('GET /api/admin/members lists members', async () => {
        vi.mocked(membersService.listMembers).mockResolvedValue([]);
        const response = await request(createApp()).get('/api/admin/members');
        expect(response.status).toBe(200);
        expect(membersService.listMembers).toHaveBeenCalledWith(20);
    });

    it('GET /api/admin/members/:uid maps NOT_FOUND to 404', async () => {
        vi.mocked(membersService.getMemberDetail).mockRejectedValue(
            new Error('User not found'),
        );
        const response = await request(createApp()).get('/api/admin/members/u-1');
        expect(response.status).toBe(404);
        expect(response.body.error.code).toBe('NOT_FOUND');
    });

    it('PATCH /api/admin/members/:uid/status maps INVALID_INPUT to 400', async () => {
        vi.mocked(membersService.setMemberStatus).mockRejectedValue(
            new Error('status must be active or suspended'),
        );
        const response = await request(createApp())
            .patch('/api/admin/members/u-1/status')
            .send({ status: 'admin' });
        expect(response.status).toBe(400);
    });

    it('DELETE /api/admin/members/:uid returns 200', async () => {
        const response = await request(createApp()).delete(
            '/api/admin/members/u-1',
        );
        expect(response.status).toBe(200);
    });

    it('PATCH /api/admin/activities/:id/status maps bad enum to 400', async () => {
        vi.mocked(activitiesService.setAdminActivityStatus).mockRejectedValue(
            new Error('status must be open, cancelled, completed, or removed'),
        );
        const response = await request(createApp())
            .patch('/api/admin/activities/a-1/status')
            .send({ status: 'hidden' });
        expect(response.status).toBe(400);
    });

    it('DELETE /api/admin/activities/:id maps missing to 404', async () => {
        vi.mocked(activitiesService.deleteAdminActivity).mockRejectedValue(
            new Error('Activity not found'),
        );
        const response = await request(createApp()).delete(
            '/api/admin/activities/ghost',
        );
        expect(response.status).toBe(404);
    });

    it('service throw maps to 500 INTERNAL_ERROR', async () => {
        vi.mocked(membersService.listMembers).mockRejectedValue(
            new Error('boom'),
        );
        const response = await request(createApp()).get('/api/admin/members');
        expect(response.status).toBe(500);
        expect(response.body.error.code).toBe('INTERNAL_ERROR');
    });
});

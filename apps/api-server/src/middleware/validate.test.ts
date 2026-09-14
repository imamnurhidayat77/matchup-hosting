import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';

import { validateBody } from './validate.js';

const schema = z.object({
    name: z.string().trim().min(1),
    age: z.number().int().positive().optional(),
});

function buildApp() {
    const app = express();
    app.use(express.json());
    app.post('/api/things', validateBody(schema), (req, res) => {
        res.json({ ok: true, data: req.body });
    });
    return app;
}

describe('validateBody', () => {
    it('passes parsed (trimmed/defaulted) bodies through', async () => {
        const res = await request(buildApp())
            .post('/api/things')
            .send({ name: '  Ada  ', age: 36 });
        expect(res.status).toBe(200);
        expect(res.body).toEqual({ ok: true, data: { name: 'Ada', age: 36 } });
    });

    it('rejects malformed bodies with the INVALID_INPUT envelope', async () => {
        const res = await request(buildApp())
            .post('/api/things')
            .send({ name: '   ', age: -1 });
        expect(res.status).toBe(400);
        expect(res.body.ok).toBe(false);
        expect(res.body.error.code).toBe('INVALID_INPUT');
        expect(res.body.error.details).toMatchObject({ name: expect.any(Array) });
    });

    it('rejects wrong types', async () => {
        const res = await request(buildApp())
            .post('/api/things')
            .send({ name: 42 });
        expect(res.status).toBe(400);
        expect(res.body.error.code).toBe('INVALID_INPUT');
    });
});

import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

vi.mock('../database/firebase.js', () => {
  return {
    checkFirestoreConnection: vi.fn().mockResolvedValue(undefined),
  };
});

import { createApp } from './app.js';

describe('createApp', () => {
  it('returns healthy response from GET /health', async () => {
    const app = createApp();

    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      ok: true,
      data: {
        status: 'ok',
        service: 'api-server',
        database: 'connected',
      },
    });
  });
  
  it('returns 503 from GET /health when database is unavailable', async () => {
    const { checkFirestoreConnection } = await import('../database/firebase.js');
    vi.mocked(checkFirestoreConnection).mockRejectedValueOnce(new Error('DB down'));

    const app = createApp();

    const response = await request(app).get('/health');

    expect(response.status).toBe(503);
    expect(response.body).toEqual({
      ok: false,
      error: {
        code: 'DB_UNAVAILABLE',
        message: 'Firestore unreachable',
      },
    });
  });
});
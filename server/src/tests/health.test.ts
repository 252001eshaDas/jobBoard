import { describe, it, expect } from 'vitest';
import request from 'supertest';

process.env.CLIENT_URL = 'http://localhost:5173';
process.env.MONGO_URI = 'mongodb://localhost:27017/test';
process.env.REDIS_URL = 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET = 'test_access_secret_123456';
process.env.JWT_REFRESH_SECRET = 'test_refresh_secret_12345';
process.env.AI_SERVICE_URL = 'http://localhost:8000';
process.env.S3_ENDPOINT = 'http://localhost:9000';
process.env.S3_BUCKET = 'resumes';
process.env.S3_ACCESS_KEY = 'x';
process.env.S3_SECRET_KEY = 'x';
process.env.SMTP_HOST = 'localhost';
process.env.SMTP_PORT = '1025';
process.env.MAIL_FROM = 'test@test.com';

describe('GET /api/health', () => {
  it('returns ok', async () => {
    const { app } = await import('../app');
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

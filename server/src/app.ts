import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import cookieParser from 'cookie-parser';
import rateLimit from 'express-rate-limit';
import { pinoHttp } from 'pino-http';
import { env } from './config/env';
import { logger } from './config/logger';
import { errorHandler, notFound } from './middlewares/errorHandler';
import { jobRouter } from './modules/jobs/job.routes';

export const app = express();

app.use(helmet());
app.use(cors({ origin: env.CLIENT_URL, credentials: true }));
app.use(compression());
app.use(pinoHttp({ logger }));

// NOTE: mount the Razorpay webhook with express.raw() BEFORE express.json(),
// because signature verification needs the raw body.
app.use(express.json({ limit: '1mb' }));
app.use(cookieParser());
app.use('/api', rateLimit({ windowMs: 15 * 60 * 1000, limit: 300 }));

app.get('/api/health', (_req, res) => res.json({ status: 'ok' }));

// Mount feature routers here as you build them:
// app.use('/api/auth', authRouter);
app.use('/api/jobs', jobRouter);

app.use(notFound);
app.use(errorHandler);

#!/usr/bin/env bash
# Job Portal with AI Resume Matching - one-shot project setup
# Usage: bash setup-jobportal.sh [project-name]
# Needs: Node 20+, npm, Python 3.11+, Docker, git
set -euo pipefail

APP="${1:-jobportal}"
mkdir -p "$APP"
cd "$APP"
ROOT="$(pwd)"
git init -q

echo "==> Creating folder structure"
mkdir -p server/src/{config,middlewares,utils,jobs,tests}
mkdir -p server/src/modules/{auth,users,companies,jobs,applications,resumes,payments,notifications,matching}
mkdir -p ai-service/app ai-service/tests
mkdir -p .github/workflows docs

# ------------------------------------------------------------------ root files
cat > .gitignore <<'EOF'
node_modules/
dist/
build/
.env
.env.*
!.env.example
__pycache__/
.venv/
*.log
coverage/
.DS_Store
EOF

cat > .prettierrc <<'EOF'
{ "singleQuote": true, "semi": true, "trailingComma": "all", "printWidth": 100 }
EOF

# ------------------------------------------------------------------ SERVER
echo "==> Setting up server (Express + TypeScript + Mongo)"
cd "$ROOT/server"
npm init -y >/dev/null

npm i express mongoose zod jsonwebtoken bcryptjs cookie-parser cors helmet \
  express-rate-limit compression pino pino-http dotenv multer \
  @aws-sdk/client-s3 @aws-sdk/s3-request-presigner ioredis bullmq nodemailer \
  razorpay swagger-ui-express swagger-jsdoc

npm i -D typescript tsx @types/node @types/express @types/jsonwebtoken \
  @types/cookie-parser @types/cors @types/compression @types/multer \
  @types/nodemailer @types/swagger-ui-express @types/swagger-jsdoc @types/supertest \
  vitest supertest mongodb-memory-server pino-pretty eslint typescript-eslint prettier

npm pkg set scripts.dev="tsx watch src/server.ts"
npm pkg set scripts.build="tsc -p tsconfig.json"
npm pkg set scripts.start="node dist/server.js"
npm pkg set scripts.test="vitest run"
npm pkg set scripts.lint="eslint src"

cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "moduleResolution": "node",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["src"],
  "exclude": ["src/**/*.test.ts", "src/tests"]
}
EOF

cat > eslint.config.mjs <<'EOF'
import tseslint from 'typescript-eslint';
export default tseslint.config(...tseslint.configs.recommended);
EOF

cat > .env.example <<'EOF'
NODE_ENV=development
PORT=5000
CLIENT_URL=http://localhost:5173
MONGO_URI=mongodb://localhost:27017/jobportal
REDIS_URL=redis://localhost:6379
JWT_ACCESS_SECRET=change_me_access_secret_32chars
JWT_REFRESH_SECRET=change_me_refresh_secret_32chars
AI_SERVICE_URL=http://localhost:8000
S3_ENDPOINT=http://localhost:9000
S3_REGION=us-east-1
S3_BUCKET=resumes
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
SMTP_HOST=localhost
SMTP_PORT=1025
MAIL_FROM=no-reply@jobportal.local
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
RAZORPAY_WEBHOOK_SECRET=
EOF

# real .env with random secrets for local use
ACCESS_SECRET="$(openssl rand -hex 32)"
REFRESH_SECRET="$(openssl rand -hex 32)"
sed -e "s/change_me_access_secret_32chars/${ACCESS_SECRET}/" \
    -e "s/change_me_refresh_secret_32chars/${REFRESH_SECRET}/" .env.example > .env

cat > src/config/env.ts <<'EOF'
import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(5000),
  CLIENT_URL: z.string().url(),
  MONGO_URI: z.string().min(1),
  REDIS_URL: z.string().min(1),
  JWT_ACCESS_SECRET: z.string().min(16),
  JWT_REFRESH_SECRET: z.string().min(16),
  AI_SERVICE_URL: z.string().url(),
  S3_ENDPOINT: z.string().url(),
  S3_REGION: z.string().default('us-east-1'),
  S3_BUCKET: z.string(),
  S3_ACCESS_KEY: z.string(),
  S3_SECRET_KEY: z.string(),
  SMTP_HOST: z.string(),
  SMTP_PORT: z.coerce.number(),
  MAIL_FROM: z.string(),
  RAZORPAY_KEY_ID: z.string().optional(),
  RAZORPAY_KEY_SECRET: z.string().optional(),
  RAZORPAY_WEBHOOK_SECRET: z.string().optional(),
});

// Fails fast at startup if any env var is missing or malformed.
export const env = schema.parse(process.env);
EOF

cat > src/config/logger.ts <<'EOF'
import pino from 'pino';
import { env } from './env';

export const logger = pino({
  level: env.NODE_ENV === 'production' ? 'info' : 'debug',
  transport: env.NODE_ENV === 'development' ? { target: 'pino-pretty' } : undefined,
});
EOF

cat > src/config/db.ts <<'EOF'
import mongoose from 'mongoose';
import { env } from './env';
import { logger } from './logger';

export async function connectDb() {
  await mongoose.connect(env.MONGO_URI);
  logger.info('MongoDB connected');
}
EOF

cat > src/utils/AppError.ts <<'EOF'
export class AppError extends Error {
  constructor(
    public statusCode: number,
    message: string,
    public details?: unknown,
  ) {
    super(message);
  }
}
EOF

cat > src/utils/asyncHandler.ts <<'EOF'
import { NextFunction, Request, RequestHandler, Response } from 'express';

// Wrap async controllers so thrown errors reach the error middleware.
export const asyncHandler =
  (fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown>): RequestHandler =>
  (req, res, next) => {
    fn(req, res, next).catch(next);
  };
EOF

cat > src/middlewares/errorHandler.ts <<'EOF'
import { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';
import { AppError } from '../utils/AppError';
import { logger } from '../config/logger';

export function notFound(_req: Request, res: Response) {
  res.status(404).json({ message: 'Route not found' });
}

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (err instanceof ZodError) {
    return res.status(400).json({ message: 'Validation failed', details: err.flatten() });
  }
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({ message: err.message, details: err.details });
  }
  logger.error(err);
  return res.status(500).json({ message: 'Internal server error' });
}
EOF

cat > src/middlewares/validate.ts <<'EOF'
import { NextFunction, Request, Response } from 'express';
import { ZodSchema } from 'zod';

// Usage: router.post('/', validate(createJobSchema), controller)
export const validate =
  (schema: ZodSchema) => (req: Request, _res: Response, next: NextFunction) => {
    req.body = schema.parse(req.body);
    next();
  };
EOF

cat > src/app.ts <<'EOF'
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
// app.use('/api/jobs', jobsRouter);

app.use(notFound);
app.use(errorHandler);
EOF

cat > src/server.ts <<'EOF'
import { app } from './app';
import { env } from './config/env';
import { connectDb } from './config/db';
import { logger } from './config/logger';

async function main() {
  await connectDb();
  const server = app.listen(env.PORT, () => logger.info(`API on :${env.PORT}`));

  const shutdown = () => {
    logger.info('Shutting down');
    server.close(() => process.exit(0));
  };
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

main().catch((err) => {
  logger.error(err);
  process.exit(1);
});
EOF

cat > src/tests/health.test.ts <<'EOF'
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
EOF

touch src/modules/{auth,users,companies,jobs,applications,resumes,payments,notifications,matching}/.gitkeep
touch src/jobs/.gitkeep

cat > Dockerfile <<'EOF'
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
USER node
EXPOSE 5000
CMD ["node", "dist/server.js"]
EOF

cat > .dockerignore <<'EOF'
node_modules
dist
.env
EOF

# ------------------------------------------------------------------ AI SERVICE
echo "==> Setting up AI service (FastAPI)"
cd "$ROOT/ai-service"

cat > requirements.txt <<'EOF'
fastapi
uvicorn[standard]
python-multipart
pypdf
scikit-learn
pydantic
pytest
httpx
EOF

touch app/__init__.py

cat > app/main.py <<'EOF'
import io

from fastapi import FastAPI, File, HTTPException, UploadFile
from pydantic import BaseModel
from pypdf import PdfReader
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

app = FastAPI(title="Resume AI service")


class MatchIn(BaseModel):
    resume_text: str
    job_text: str


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/parse-resume")
async def parse_resume(file: UploadFile = File(...)):
    if file.content_type != "application/pdf":
        raise HTTPException(status_code=415, detail="Only PDF resumes are supported")
    data = await file.read()
    reader = PdfReader(io.BytesIO(data))
    text = "\n".join((page.extract_text() or "") for page in reader.pages)
    return {"text": text.strip(), "pages": len(reader.pages)}


@app.post("/match")
def match(body: MatchIn):
    # Baseline: TF-IDF cosine similarity. Upgrade later to sentence-transformers embeddings.
    try:
        vec = TfidfVectorizer(stop_words="english", ngram_range=(1, 2))
        m = vec.fit_transform([body.resume_text, body.job_text])
    except ValueError:
        raise HTTPException(status_code=422, detail="Not enough text to compare")
    score = float(cosine_similarity(m[0], m[1])[0][0])
    terms = vec.get_feature_names_out()
    resume_vec, job_vec = m[0].toarray()[0], m[1].toarray()[0]
    matched = [terms[i] for i in range(len(terms)) if resume_vec[i] > 0 and job_vec[i] > 0]
    missing = [terms[i] for i in range(len(terms)) if job_vec[i] > 0 and resume_vec[i] == 0]
    return {
        "score": round(score * 100, 1),
        "matched_terms": matched[:30],
        "missing_terms": missing[:30],
    }
EOF

cat > tests/test_health.py <<'EOF'
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    assert client.get("/health").json() == {"status": "ok"}


def test_match_scores_similar_text_higher():
    body = {
        "resume_text": "React Node MongoDB developer with Express and TypeScript",
        "job_text": "Looking for a React and Node developer, MongoDB, TypeScript",
    }
    res = client.post("/match", json=body).json()
    assert res["score"] > 0
EOF

cat > Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# ------------------------------------------------------------------ CLIENT
echo "==> Setting up client (Vite + React + TypeScript)"
cd "$ROOT"
# If this prompts, accept the defaults (React + TypeScript).
npm create vite@latest client -- --template react-ts
cd "$ROOT/client"
npm install
npm i react-router-dom @tanstack/react-query zustand axios react-hook-form zod \
  @hookform/resolvers react-hot-toast tailwindcss @tailwindcss/vite
npm i -D vitest jsdom @testing-library/react @testing-library/jest-dom \
  @testing-library/user-event prettier

mkdir -p src/{features/{auth,jobs,applications,resumes,payments,dashboard},components,hooks,lib,routes,store,tests}
touch src/features/{auth,jobs,applications,resumes,payments,dashboard}/.gitkeep

cat > .env.example <<'EOF'
VITE_API_URL=http://localhost:5000/api
VITE_RAZORPAY_KEY_ID=
EOF
cp .env.example .env

cat > src/lib/api.ts <<'EOF'
import axios from 'axios';

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  withCredentials: true, // refresh token lives in an httpOnly cookie
});

// TODO: add a response interceptor that calls /auth/refresh on 401 and retries once.
EOF

cat > Dockerfile <<'EOF'
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
EOF

# ------------------------------------------------------------------ DOCKER COMPOSE
cd "$ROOT"
cat > docker-compose.yml <<'EOF'
services:
  mongo:
    image: mongo:7
    ports: ["27017:27017"]
    volumes: [mongo_data:/data/db]

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports: ["9000:9000", "9001:9001"]
    volumes: [minio_data:/data]

  mailhog:
    image: mailhog/mailhog
    ports: ["1025:1025", "8025:8025"]

  ai-service:
    build: ./ai-service
    ports: ["8000:8000"]

  # Full stack in containers: docker compose --profile full up --build
  server:
    profiles: ["full"]
    build: ./server
    env_file: ./server/.env
    environment:
      MONGO_URI: mongodb://mongo:27017/jobportal
      REDIS_URL: redis://redis:6379
      AI_SERVICE_URL: http://ai-service:8000
      S3_ENDPOINT: http://minio:9000
      SMTP_HOST: mailhog
    ports: ["5000:5000"]
    depends_on: [mongo, redis, minio, mailhog, ai-service]

volumes:
  mongo_data:
  minio_data:
EOF

# ------------------------------------------------------------------ CI
cat > .github/workflows/ci.yml <<'EOF'
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  server:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: server } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm, cache-dependency-path: server/package-lock.json }
      - run: npm ci
      - run: npm run lint
      - run: npm run build
      - run: npm test

  client:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: client } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: npm, cache-dependency-path: client/package-lock.json }
      - run: npm ci
      - run: npm run build

  ai-service:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: ai-service } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install -r requirements.txt
      - run: pytest
EOF

# ------------------------------------------------------------------ README
cat > README.md <<'EOF'
# Job Portal with AI Resume Matching

Roles: candidate, recruiter, admin. Candidates upload a PDF resume, the AI service parses it
and scores it against job descriptions. Recruiters pay (Razorpay) to feature jobs.

## Run locally
```bash
docker compose up -d mongo redis minio mailhog ai-service
cd server && npm run dev        # API on :5000, docs at /api/docs once added
cd client && npm run dev        # UI on :5173
```
- MinIO console: http://localhost:9001 (minioadmin / minioadmin), create bucket `resumes`
- Mailhog inbox: http://localhost:8025
- AI service docs: http://localhost:8000/docs

## Build order (checklist)
1. Auth: register/login, bcrypt, access JWT (15 min) + refresh JWT in httpOnly cookie, rotation, logout, RBAC middleware, email verification + password reset (BullMQ + Nodemailer)
2. Companies and Jobs: CRUD, text index search, filters, sort, pagination, soft delete, slugs
3. Applications: apply, status pipeline (applied, shortlisted, rejected, hired), recruiter dashboard
4. Resumes: multer to memory, upload to MinIO/S3, send to /parse-resume, store extracted text, presigned download URLs
5. Matching: on apply call /match, store score and missing terms, rank applicants by score, cache with Redis
6. Payments: Razorpay order create, client checkout, verify signature server-side, webhook (raw body, idempotent), Payment/Subscription models, featured-job flag
7. Notifications: queue emails on status change, in-app notification list
8. Hardening: rate limits per route (stricter on auth), request IDs, audit log, Swagger docs, seed script, indexes review
9. Tests: Vitest + Supertest + mongodb-memory-server (server), RTL (client), pytest (ai-service)
10. Deploy: Docker images, GitHub Actions deploy, Mongo Atlas, Upstash Redis, Render/Railway/AWS

## Data models
User, Company, Job, Application, Resume, Payment, Notification, RefreshToken (hashed)
EOF

echo
echo "==> Done. Remaining manual steps:"
echo "  1. Tailwind: add  import tailwindcss from '@tailwindcss/vite'  and  plugins: [react(), tailwindcss()]"
echo "     in client/vite.config.ts, then put  @import \"tailwindcss\";  at the top of client/src/index.css"
echo "  2. cd $ROOT && docker compose up -d mongo redis minio mailhog ai-service"
echo "  3. cd server && npm run dev     |     cd client && npm run dev"
echo "  4. In MinIO console (localhost:9001) create a bucket named 'resumes'"

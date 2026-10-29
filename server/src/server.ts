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

import { createApp } from './app/app';
import { env } from './config/env';
import { logger } from './config/logger';
import { disconnectPrisma } from './database/prisma';

const app = createApp();

const server = app.listen(env.PORT, () => {
  logger.info({ port: env.PORT, env: env.NODE_ENV }, 'matchup-api listening');
});

async function shutdown(signal: string): Promise<void> {
  logger.info({ signal }, 'shutdown signal received');
  server.close(async () => {
    await disconnectPrisma();
    process.exit(0);
  });
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
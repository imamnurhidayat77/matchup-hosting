/**
 * Migration entrypoint.
 *
 * The API now uses Prisma Migrate. This script delegates to
 * `prisma migrate deploy` so that existing CI / local workflows keep working.
 *
 * Usage:
 *   npm run migrate
 */
import { execSync } from 'node:child_process';
import { logger } from '../config/logger';

async function main(): Promise<void> {
  execSync('npx prisma migrate deploy', { stdio: 'inherit' });
  logger.info('prisma migrate deploy complete');
}

main().catch((err) => {
  logger.error({ err }, 'migration failed');
  process.exit(1);
});
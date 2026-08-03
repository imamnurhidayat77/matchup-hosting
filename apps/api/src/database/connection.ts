/**
 * Legacy database connection helpers.
 *
 * The API now uses Prisma via {@link ./prisma.ts}. These exports are kept as
 * thin wrappers around Prisma's queryRaw for any code that was written against
 * the old `pg` Pool interface during the boilerplate phase.
 */
import { prisma } from './prisma';

/**
 * @deprecated Use Prisma Client directly instead.
 */
export function getPool() {
  return {
    query: (sql: string, values?: unknown[]) =>
      prisma.$queryRawUnsafe(sql, ...(values ?? [])),
  } as const;
}

/**
 * @deprecated Use {@link prisma.$disconnect} instead.
 */
export async function closePool(): Promise<void> {
  await prisma.$disconnect();
}
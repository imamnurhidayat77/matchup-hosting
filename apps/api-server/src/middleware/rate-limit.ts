import type { NextFunction, Request, Response } from 'express';

export interface RateLimitOptions {
  /** Length of the fixed window in milliseconds. */
  windowMs: number;
  /** Max requests allowed per window, per IP. */
  max: number;
  /** Message returned in the 429 envelope. */
  message?: string;
  /** Return true to exempt a request (e.g. health checks). */
  skip?: (req: Request) => boolean;
}

interface WindowCounter {
  count: number;
  resetAt: number;
}

/**
 * Pluggable counter backend for the fixed-window limiter.
 *
 * The default is process memory (`MemoryRateLimitStore`), which is why
 * limits are currently enforced per instance (see note on
 * `createRateLimiter`). A Redis (or Firestore-transaction) implementation
 * behind this interface makes limits global without touching the
 * middleware — the shape is deliberately minimal (single increment +
 * opportunistic expiry) so it maps 1:1 onto `INCR` + `PEXPIRE`.
 */
export interface RateLimitStore {
  /** Atomically increments the window for `key`, returning the new state. */
  hit(key: string, now: number, windowMs: number): WindowCounter;
  /** Drops expired windows; called opportunistically, never on the hot path contract. */
  sweep(now: number): void;
}

export class MemoryRateLimitStore implements RateLimitStore {
  private readonly hits = new Map<string, WindowCounter>();

  hit(key: string, now: number, windowMs: number): WindowCounter {
    const existing = this.hits.get(key);
    if (!existing || existing.resetAt <= now) {
      const fresh = { count: 1, resetAt: now + windowMs };
      this.hits.set(key, fresh);
      return fresh;
    }
    existing.count += 1;
    return existing;
  }

  sweep(now: number): void {
    for (const [key, entry] of this.hits) {
      if (entry.resetAt <= now) {
        this.hits.delete(key);
      }
    }
  }
}

function clientIp(req: Request): string {
  return req.ip ?? req.socket?.remoteAddress ?? 'unknown';
}

/**
 * Small per-IP fixed-window rate limiter. No dependencies.
 *
 * NOTE (multi-instance limitation): the default store lives in process
 * memory, so limits are enforced per instance, not globally. Behind N
 * replicas each instance allows up to `max` requests per window (i.e. up
 * to N*max total). Pass a shared `RateLimitStore` (e.g. Redis) via
 * options to enforce one global budget. If strict global limits are ever
 * needed, replace the Map with a shared store (e.g. Redis/Firestore
 * atomic increments). For this app's threat model (abuse dampening,
 * upstream Nominatim policy compliance) per-instance limiting is
 * sufficient.
 */
export function createRateLimiter(
  options: RateLimitOptions & { store?: RateLimitStore },
) {
  const {
    windowMs,
    max,
    message = 'Too many requests, please slow down.',
    skip,
    store = new MemoryRateLimitStore(),
  } = options;

  return function rateLimiter(req: Request, res: Response, next: NextFunction): void {
    if (skip?.(req)) {
      next();
      return;
    }

    const now = Date.now();

    // Opportunistic cleanup of expired windows so the store cannot grow
    // unboundedly from one-off scanner IPs.
    store.sweep(now);

    const key = clientIp(req);
    const { count, resetAt } = store.hit(key, now, windowMs);

    const retryAfterSec = Math.max(1, Math.ceil((resetAt - now) / 1000));
    res.set('RateLimit-Limit', String(max));
    res.set('RateLimit-Remaining', String(Math.max(0, max - count)));
    res.set('RateLimit-Reset', String(Math.ceil(resetAt / 1000)));

    if (count > max) {
      res.set('Retry-After', String(retryAfterSec));
      res.status(429).json({
        ok: false,
        error: {
          code: 'RATE_LIMITED',
          message,
        },
      });
      return;
    }

    next();
  };
}

/**
 * Global default: 1200 req / 15 min per IP (avg ~80/min). Health checks
 * are skipped so load balancers / uptime probes are never throttled.
 *
 * Budget math (per docs/architecture/scalability.md): an open group chat
 * with the HTTP fallback costs ~20 req/min (messages every 3s) plus the
 * typing poll at ~30 req/min per roster member, so a 5-member chat alone
 * is ~170 req/min sustained. The old 300/15min budget (avg 20/min)
 * 429'd normal single-chat usage — including unrelated routes like
 * `GET /users/me` that share the per-IP window — which is why clients
 * saw `RATE_LIMITED` on profile reads while a chat was open.
 */
export const GLOBAL_RATE_LIMIT: RateLimitOptions = {
  windowMs: 15 * 60 * 1000,
  max: 1200,
  skip: (req) => req.path === '/api/health',
};

/**
 * Place autocomplete proxies Nominatim, whose usage policy asks for at most
 * ~1 req/s. 60 req / 1 min per IP matches that average while tolerating
 * debounced keystroke bursts from the venue picker.
 */
export const AUTOCOMPLETE_RATE_LIMIT: RateLimitOptions = {
  windowMs: 60 * 1000,
  max: 60,
  message: 'Too many place searches, please slow down.',
};

/**
 * Typing is polled (GET /api/typing/:activityId/:uid every ~2s per roster
 * member = ~30 req/min per member), so this is a burst guard, not a volume
 * cap: 120 req / 1 min per IP leaves headroom for a few concurrently polled
 * members while still blunting floods. The global limiter still caps
 * sustained volume.
 */
export const TYPING_RATE_LIMIT: RateLimitOptions = {
  windowMs: 60 * 1000,
  max: 120,
  message: 'Too many typing requests, please slow down.',
};

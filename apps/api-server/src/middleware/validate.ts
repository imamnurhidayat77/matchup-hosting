import type { NextFunction, Request, Response } from 'express';
import { z } from 'zod';

/**
 * zod body-validation middleware — the pilot for per-route schemas
 * (see `docs/security/owasp-top-10.md` A03). Rejects malformed bodies
 * with the same `{ ok, error }` envelope the controllers already use,
 * plus machine-readable `details` per field.
 *
 * On success `req.body` is replaced with the *parsed* (trimmed,
 * defaulted, coerced) value, so controllers stop re-checking shapes.
 */
export function validateBody<T extends z.ZodTypeAny>(schema: T) {
    return (req: Request, res: Response, next: NextFunction): void => {
        const parsed = schema.safeParse(req.body);
        if (!parsed.success) {
            res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'Invalid request body',
                    details: parsed.error.flatten().fieldErrors,
                },
            });
            return;
        }
        req.body = parsed.data;
        next();
    };
}

/**
 * zod query-validation middleware — same `{ ok, error }` envelope as
 * [validateBody], with per-field `details` from zod's `fieldErrors`.
 * On success `req.query` is replaced with the parsed (coerced,
 * defaulted) value so controllers stop re-checking shapes.
 *
 * Note: Express 5 exposes `req.query` as a getter, so plain assignment
 * throws — hence the `defineProperty` fallback.
 */
export function validateQuery<T extends z.ZodTypeAny>(schema: T) {
    return (req: Request, res: Response, next: NextFunction): void => {
        const parsed = schema.safeParse(req.query);
        if (!parsed.success) {
            res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'Invalid query parameters',
                    details: parsed.error.flatten().fieldErrors,
                },
            });
            return;
        }
        try {
            (req as { query: unknown }).query = parsed.data;
        } catch {
            Object.defineProperty(req, 'query', {
                value: parsed.data,
                writable: true,
                enumerable: true,
                configurable: true,
            });
        }
        next();
    };
}

/**
 * zod params-validation middleware — same envelope as [validateBody] /
 * [validateQuery], `details` from zod's `fieldErrors`. Catches malformed
 * path params (blank ids, bad shapes) before controllers run.
 */
export function validateParams<T extends z.ZodTypeAny>(schema: T) {
    return (req: Request, res: Response, next: NextFunction): void => {
        const parsed = schema.safeParse(req.params);
        if (!parsed.success) {
            res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'Invalid path parameters',
                    details: parsed.error.flatten().fieldErrors,
                },
            });
            return;
        }
        try {
            (req as { params: unknown }).params = parsed.data;
        } catch {
            Object.defineProperty(req, 'params', {
                value: parsed.data,
                writable: true,
                enumerable: true,
                configurable: true,
            });
        }
        next();
    };
}

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

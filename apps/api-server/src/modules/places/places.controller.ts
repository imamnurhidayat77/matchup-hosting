import type { Request, Response } from 'express';
import { autocompletePlaces } from './places.service.js';

/**
 * `GET /api/places/autocomplete?q=...&countryCodes=nz`
 *
 * Unauthenticated by design: the search happens on the pre-login
 * create wizard for signed-out hosts, and Nominatim labels carry no
 * user data. The repo caches aggressively, so anonymous access is
 * cheap.
 */
export async function autocompletePlacesHandler(req: Request, res: Response) {
    try {
        const { q, countryCodes } = req.query;

        if (typeof q !== 'string') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'q must be a string',
                },
            });
        }

        if (countryCodes !== undefined && typeof countryCodes !== 'string') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'countryCodes must be a string',
                },
            });
        }

        const suggestions = await autocompletePlaces(q, countryCodes);

        return res.status(200).json({
            ok: true,
            data: suggestions,
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'countryCodes must be a comma-separated list of ISO 3166-1 alpha-2 codes') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message,
                },
            });
        }

        return res.status(502).json({
            ok: false,
            error: {
                code: 'PLACES_UNAVAILABLE',
                message: 'Could not reach the places provider. Please try again.',
            },
        });
    }
}

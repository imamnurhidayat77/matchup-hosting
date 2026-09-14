import type { Request, Response } from 'express';
import { listSports } from './sports.service.js';

/**
 * `GET /api/public/sports` — the enabled master sports list for mobile
 * pickers (onboarding, discovery filter, create/edit forms).
 *
 * Public (no auth): sports config is non-sensitive, and onboarding runs
 * before some users finish sign-in. No counts (keeps it light) and no
 * disabled rows — clients filter surfaces (`showInFilter`,
 * `showInOnboarding`, `canHost`) themselves.
 */
export async function listPublicSportsHandler(_req: Request, res: Response) {
    try {
        const rows = await listSports();
        return res.status(200).json({
            ok: true,
            data: rows
                .filter((s) => s.enabled)
                .map((s) => ({
                    id: s.id,
                    name: s.name,
                    emoji: s.emoji,
                    showInFilter: s.showInFilter,
                    showInOnboarding: s.showInOnboarding,
                    canHost: s.canHost,
                    sortOrder: s.sortOrder,
                })),
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

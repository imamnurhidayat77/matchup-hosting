import { z } from 'zod';

/**
 * L5 fix: zod validation for the user-facing appeal endpoint, matching
 * the hand-checks in `submitAppeal` (same accept set, same 2000-char
 * statement cap). Rejects malformed bodies with 400 INVALID_INPUT +
 * per-field details before the service runs, so the controller no
 * longer hand-casts `req.body`.
 *
 * NOTE: the 2000 cap is intentionally duplicated (not imported) from
 * `APPEAL_STATEMENT_MAX` in appeals.service — the schema must stay
 * importable without pulling the service module (and its Firebase
 * imports) into route files and their mocks.
 */
const APPEAL_STATEMENT_MAX = 2000;
export const submitAppealSchema = z.object({
    type: z.enum(
        ['suspension', 'activity_removal', 'account_ban', 'content_removal'],
        'type must be suspension, activity_removal, account_ban, or content_removal',
    ),
    statement: z
        .string()
        .trim()
        .min(1, 'statement is required')
        .max(
            APPEAL_STATEMENT_MAX,
            `statement must be at most ${APPEAL_STATEMENT_MAX} characters`,
        ),
    relatedId: z.string().trim().min(1).optional(),
});

export type SubmitAppealInput = z.infer<typeof submitAppealSchema>;

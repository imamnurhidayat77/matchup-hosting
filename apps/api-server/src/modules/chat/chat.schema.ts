import { z } from 'zod';

/**
 * Pilot per-route zod schema (see `middleware/validate.ts`). Captures the
 * rules the controller previously hand-checked: non-blank ids/text, a
 * closed `type` union defaulting to `'text'`, and a 2000-char cap so one
 * message can never blow the 1 MB body budget or the RTDB node size.
 */
export const sendMessageSchema = z.object({
    activityId: z.string().trim().min(1, 'activityId is required'),
    text: z
        .string()
        .trim()
        .min(1, 'text is required')
        .max(2000, 'text must be at most 2000 characters'),
    type: z.enum(['text', 'system']).optional().default('text'),
});

export type SendMessageInput = z.infer<typeof sendMessageSchema>;

/**
 * Closed emoji set for message reactions. A fixed allowlist (instead of
 * free-form text) keeps reaction keys small, renders consistently
 * across platforms, and doubles as the RTDB key allowlist — emoji
 * contain none of Firebase's forbidden key characters (`. $ # [ ] /`).
 */
export const reactionEmojis = [
    '❤️',
    '😂',
    '👍',
    '👏',
    '🔥',
    '😮',
    '😢',
    '🙏',
    '🎉',
    '💯',
] as const;

export type ReactionEmoji = (typeof reactionEmojis)[number];

export const toggleReactionSchema = z.object({
    emoji: z.enum(reactionEmojis, 'emoji must be one of the supported reactions'),
});

export type ToggleReactionInput = z.infer<typeof toggleReactionSchema>;

/**
 * Group-chat polls ("Play at 4 or 5?"). Single-choice: each
 * member holds at most one vote; voting the same option again
 * retracts it. Stored under `activityChats/{id}/polls` (see rules).
 */
export const createPollSchema = z.object({
    question: z
        .string()
        .trim()
        .min(1, 'question is required')
        .max(200, 'question must be at most 200 characters'),
    options: z
        .array(
            z
                .string()
                .trim()
                .min(1, 'options must not be blank')
                .max(80, 'each option must be at most 80 characters'),
        )
        .min(2, 'at least 2 options are required')
        .max(6, 'at most 6 options are allowed'),
});

export type CreatePollInput = z.infer<typeof createPollSchema>;

export const votePollSchema = z.object({
    optionIndex: z.number().int().min(0, 'optionIndex must be a valid option'),
});

export type VotePollInput = z.infer<typeof votePollSchema>;

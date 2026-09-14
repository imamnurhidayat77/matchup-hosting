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

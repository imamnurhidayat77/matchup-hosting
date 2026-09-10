import { Timestamp } from 'firebase-admin/firestore';
import { firestore } from '../../database/firebase.js';
import { activityDocPath } from '../../database/paths.js';
import { getParticipants } from './activity-participants.service.js';
import { createNotification } from '../notifications/notifications.service.js';

/**
 * Expiry sweeper for activities. An activity is "due" when its end
 * time has passed while `status` is still `open` — this happens
 * whenever the host never taps "Mark as Completed" (or the app was
 * offline at game time).
 *
 * Due activities are flipped to `completed` inside a transaction
 * (guarded against a concurrent manual complete) and every roster
 * member + the host gets an `activity_completed` notification that
 * nudges them to the review screen.
 *
 * Two drivers, belt and suspenders:
 *   1. `startExpirySweeper()` interval in `server.ts` (every 5 min).
 *   2. Fire-and-forget calls at the top of the read paths
 *      (`listActivities`, `listDiscoverActivities`) so expiry is
 *      eventually consistent even if the interval never runs
 *      (e.g. serverless). The sweep never blocks a read — callers
 *      must NOT await it.
 *
 * The scan is intentionally a single `where('status', '==', 'open')`
 * query with the end-time check done in memory: a
 * `where(status) + where(endTime)` pair would need a composite
 * Firestore index, and the codebase policy is zero index ops (see
 * the NOTE in `listActivities`). Bounded to `limit` docs per run.
 */
export async function sweepExpiredActivities(options?: {
    nowMs?: number;
    limit?: number;
}): Promise<{ completed: number }> {
    const nowMs = options?.nowMs ?? Date.now();
    const limit = Math.min(Math.max(options?.limit ?? 50, 1), 100);

    const snap = await firestore
        .collection('activities')
        .where('status', '==', 'open')
        .limit(limit)
        .get();

    let completed = 0;
    for (const doc of snap.docs) {
        const data = doc.data();
        const endMs = resolveEndMs(data);
        if (endMs === null || endMs > nowMs) continue;

        try {
            const flipped = await tryComplete(doc.id);
            if (!flipped) continue;
            completed += 1;
            await notifyCompleted(
                doc.id,
                typeof data.title === 'string' && data.title
                    ? data.title
                    : 'Your activity',
                typeof data.hostId === 'string' ? data.hostId : null,
            );
        } catch {
            // One bad row (malformed doc, torn write) must not abort
            // the sweep — log-free by design (callers own logging),
            // just move on to the next activity.
            continue;
        }
    }

    return { completed };
}

/**
 * Resolves the effective end of an activity in epoch ms. Prefers the
 * stored `endTime`; rows written before that field existed fall back
 * to `startTime + 2h` (the mobile default duration). Returns null
 * when neither is parseable — such rows are never auto-completed.
 */
export function resolveEndMs(
    data: FirebaseFirestore.DocumentData,
): number | null {
    const endRaw = data.endTime;
    if (typeof endRaw === 'string') {
        const ms = Date.parse(endRaw);
        if (!Number.isNaN(ms)) return ms;
    }
    const startRaw = data.startTime;
    if (typeof startRaw === 'string') {
        const ms = Date.parse(startRaw);
        if (!Number.isNaN(ms)) return ms + 2 * 60 * 60 * 1000;
    }
    return null;
}

/**
 * Flips one activity to `completed` iff it is still `open`.
 * Returns true when this call performed the flip (false when a
 * concurrent writer — e.g. the host — got there first).
 */
async function tryComplete(activityId: string): Promise<boolean> {
    let flipped = false;
    await firestore.runTransaction(async (transaction) => {
        const ref = firestore.doc(activityDocPath(activityId));
        const snap = await transaction.get(ref);
        if (!snap.exists) return;
        if (snap.data()?.status !== 'open') return;
        transaction.update(ref, {
            status: 'completed',
            updatedAt: Timestamp.now(),
        });
        flipped = true;
    });
    return flipped;
}

async function notifyCompleted(
    activityId: string,
    title: string,
    hostId: string | null,
): Promise<void> {
    const recipients = new Set<string>();
    try {
        const roster = await getParticipants(activityId);
        for (const p of roster) {
            if (typeof p.uid === 'string' && p.uid) recipients.add(p.uid);
        }
    } catch {
        // Roster read failure degrades to host-only notification
        // rather than dropping the nudge entirely.
    }
    if (hostId) recipients.add(hostId);
    if (recipients.size === 0) return;

    const body = `“${title}” has ended. Tap to rate your game.`;
    await Promise.all(
        [...recipients].map((uid) =>
            createNotification({
                recipientUid: uid,
                type: 'activity_completed',
                title: 'Activity completed',
                body,
                activityId,
            }).catch(() => undefined),
        ),
    );
}

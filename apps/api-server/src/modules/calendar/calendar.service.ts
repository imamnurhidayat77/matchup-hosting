import { listMyActivities } from '../activities/activities.service.js';

export type CalendarEntry = {
    id: string;
    activity_id: string;
    title: string;
    start: string;
    end: string | null;
    location: string;
    synced: boolean;
};

/**
 * In-memory synced flags (`activityId -> synced`). A Firestore field
 * would survive restarts, but per-user calendar state is device-local by
 * design (each phone syncs its own OS calendar) — persisting it
 * server-side would conflate devices. The trade-off: a server restart
 * resets flags to false and clients re-sync idempotently.
 */
const syncedActivityIds = new Set<string>();

/** For tests: reset the in-memory synced set. */
export function clearSyncedActivities(): void {
    syncedActivityIds.clear();
}

export function isActivitySynced(activityId: string): boolean {
    return syncedActivityIds.has(activityId.trim());
}

/**
 * Upcoming personal schedule: the viewer's hosted + joined games with
 * `status != completed` whose start falls inside `[now, now + days]`.
 * Derived live from the activities service — no separate calendar
 * collection to drift out of sync.
 */
export async function listUpcoming(
    uid: string,
    days: number,
    nowMs: number = Date.now(),
): Promise<CalendarEntry[]> {
    const normalizedUid = uid.trim();
    if (!normalizedUid) throw new Error('uid is required');
    if (!Number.isFinite(days) || days <= 0 || days > 90) {
        throw new Error('days must be between 1 and 90');
    }

    const [hosted, joined] = await Promise.all([
        listMyActivities(normalizedUid, 'hosted', 50, 0).catch(() => []),
        listMyActivities(normalizedUid, 'joined', 50, 0).catch(() => []),
    ]);

    const seen = new Map<string, (typeof hosted)[number]>();
    for (const a of [...hosted, ...joined]) {
        if (!seen.has(a.activityId)) seen.set(a.activityId, a);
    }

    const horizonMs = nowMs + days * 24 * 60 * 60 * 1000;
    return [...seen.values()]
        .filter((a) => a.status !== 'completed')
        .filter((a) => {
            const startMs = Date.parse(a.startTime);
            return !Number.isNaN(startMs) && startMs >= nowMs && startMs <= horizonMs;
        })
        .sort((a, b) => Date.parse(a.startTime) - Date.parse(b.startTime))
        .map((a) => ({
            id: a.activityId,
            activity_id: a.activityId,
            title: a.title,
            start: a.startTime,
            end: typeof a.endTime === 'string' ? a.endTime : null,
            location: a.locationName,
            synced: syncedActivityIds.has(a.activityId),
        }));
}

/**
 * Marks activity ids as synced. Trusts the ids (the client only syncs
 * entries it fetched from its own upcoming feed); blank ids are dropped
 * and duplicates collapse — the returned count is unique valid ids.
 */
export async function syncActivities(
    uid: string,
    activityIds: string[],
): Promise<{ synced: number }> {
    const normalizedUid = uid.trim();
    if (!normalizedUid) throw new Error('uid is required');
    const unique = new Set<string>();
    for (const id of activityIds) {
        if (typeof id === 'string' && id.trim()) unique.add(id.trim());
    }
    for (const id of unique) syncedActivityIds.add(id);
    return { synced: unique.size };
}

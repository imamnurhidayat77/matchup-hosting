import { firestore } from '../../database/firebase.js';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import {
    activityDocPath,
    activityJoinRequestDocPath,
    activityParticipantDocPath,
} from '../../database/paths.js';
import {
    getPublicUserProfile,
    type PublicUserProfile,
} from '../users/users.service.js';
import {
    getSwipeDecision,
    type SwipeDecision,
} from '../swipes/swipes.service.js';
import { sweepExpiredActivities } from './activity-lifecycle.service.js';

export type ActivityStatus = 'open' | 'full' | 'cancelled' | 'completed' | 'removed';
export type ActivitySkillLevel = 'beginner' | 'intermediate' | 'advanced' | 'any';

/**
 * How new members get in. `open` keeps the legacy behaviour (instant
 * join); `approval` parks the user in a pending join request the host
 * must approve. Defaults to `open` for documents written before the
 * field existed.
 */
export type ActivityJoinPolicy = 'open' | 'approval';

export function isJoinPolicy(value: unknown): value is ActivityJoinPolicy {
    return value === 'open' || value === 'approval';
}

/**
 * Normalises the paid/free inputs into the stored shape.
 * Free activities never carry a `fee` (it is dropped); paid ones
 * require a positive NZD amount. Throws on invalid input.
 */
export function resolvePaidFee(
    isPaid: boolean | undefined,
    fee: number | undefined,
): { isPaid: boolean; fee?: number } {
    const paid = isPaid ?? false;
    if (typeof paid !== 'boolean') {
        throw new Error('isPaid must be a boolean');
    }
    if (!paid) {
        return { isPaid: false };
    }
    if (fee === undefined || typeof fee !== 'number' || !Number.isFinite(fee) || fee <= 0) {
        throw new Error('fee must be a positive number for paid activities');
    }
    // Cap to cents to keep display + storage consistent.
    return { isPaid: true, fee: Math.round(fee * 100) / 100 };
}

export type ActivityFeeMode = 'fixed' | 'split';

export function isFeeMode(value: unknown): value is ActivityFeeMode {
    return value === 'fixed' || value === 'split';
}

/**
 * Normalises an optional weather snapshot. Returns the storable shape
 * (fields omitted when absent/invalid) — never throws, so a bad
 * snapshot can't fail activity creation.
 */
export function normalizeWeatherSnapshot(input: {
    weatherTemp?: number | null | undefined;
    weatherCode?: number | undefined;
    weatherDesc?: string | undefined;
    weatherRain?: number | undefined;
}): Partial<ActivityRecord> {
    const out: Partial<ActivityRecord> = {};
    if (input.weatherTemp !== undefined && input.weatherTemp !== null) {
        if (typeof input.weatherTemp === 'number' && Number.isFinite(input.weatherTemp)) {
            out.weatherTemp = Math.round(input.weatherTemp * 10) / 10;
        }
    } else if (input.weatherTemp === null) {
        out.weatherTemp = null;
    }
    if (
        input.weatherCode !== undefined &&
        typeof input.weatherCode === 'number' &&
        Number.isInteger(input.weatherCode) &&
        input.weatherCode >= 0 &&
        input.weatherCode <= 99
    ) {
        out.weatherCode = input.weatherCode;
    }
    if (input.weatherDesc !== undefined && typeof input.weatherDesc === 'string') {
        const desc = input.weatherDesc.trim().slice(0, 40);
        if (desc) out.weatherDesc = desc;
    }
    if (
        input.weatherRain !== undefined &&
        typeof input.weatherRain === 'number' &&
        Number.isInteger(input.weatherRain) &&
        input.weatherRain >= 0 &&
        input.weatherRain <= 100
    ) {
        out.weatherRain = input.weatherRain;
    }
    return out;
}

/**
 * Normalises split-cost inputs. `totalCost` must be positive,
 * `minPlayers` (when given) an integer >= 2. Returns the stored shape;
 * both fields are omitted for `fixed` mode.
 */
export function resolveSplitCost(
    feeMode: ActivityFeeMode | undefined,
    totalCost: number | undefined,
    minPlayers: number | undefined,
    capacity: number,
): { feeMode: ActivityFeeMode; totalCost?: number; minPlayers?: number } {
    const mode = feeMode ?? 'fixed';
    if (!isFeeMode(mode)) {
        throw new Error('feeMode must be fixed or split');
    }
    if (mode === 'fixed') {
        return { feeMode: mode };
    }
    if (totalCost === undefined || typeof totalCost !== 'number' || !Number.isFinite(totalCost) || totalCost <= 0) {
        throw new Error('totalCost must be a positive number for split mode');
    }
    if (minPlayers !== undefined &&
        (!Number.isInteger(minPlayers) || minPlayers < 2 || minPlayers > capacity)) {
        throw new Error('minPlayers must be an integer between 2 and capacity');
    }
    return {
        feeMode: mode,
        totalCost: Math.round(totalCost * 100) / 100,
        ...(minPlayers !== undefined ? { minPlayers } : {}),
    };
}

export type CreateActivityInput = {
    hostId: string;
    title: string;
    sportType: string;
    description: string;
    locationName: string;
    address?: string;
    latitude: number;
    longitude: number;
    geohash: string;
    startTime: string;
    endTime?: string;
    skillLevel: ActivitySkillLevel;
    capacity: number;
    coverImageUrl?: string;
    joinPolicy?: ActivityJoinPolicy;
    /**
     * Whether joining costs money. Defaults to `false` (free). When
     * `true`, `fee` must be a positive number (NZD per person).
     */
    isPaid?: boolean;
    /** Entry fee in NZD. Only stored when `isPaid` is true. */
    fee?: number;
    /** Pricing mode: flat per person (`fixed`, default) or shared total (`split`). */
    feeMode?: ActivityFeeMode;
    /** Total cost to split (NZD). Required for `split` mode. */
    totalCost?: number;
    /** Minimum players for split mode. Defaults to full capacity. */
    minPlayers?: number;
    /**
     * Weather snapshot captured at creation (Open-Meteo, best-effort).
     * All optional so old clients keep working; legacy rows omit them.
     */
    weatherTemp?: number | null;
    weatherCode?: number;
    weatherDesc?: string;
    weatherRain?: number;
};

export type UpdateActivityStatusInput = {
    activityId: string;
    hostId: string;
    status: Exclude<ActivityStatus, 'full'>;
};

export type UpdateActivityCoverInput = {
    activityId: string;
    hostId: string;
    coverImagePath: string;
    coverImageUrl: string;
};

export type UpdateActivityInput = {
    activityId: string;
    hostId: string;
    title?: string;
    sportType?: string;
    description?: string;
    locationName?: string;
    address?: string;
    latitude?: number;
    longitude?: number;
    geohash?: string;
    startTime?: string;
    endTime?: string;
    skillLevel?: ActivitySkillLevel;
    capacity?: number;
    coverImageUrl?: string;
    joinPolicy?: ActivityJoinPolicy;
    isPaid?: boolean;
    fee?: number;
    feeMode?: ActivityFeeMode;
    totalCost?: number;
    minPlayers?: number;
    weatherTemp?: number | null;
    weatherCode?: number;
    weatherDesc?: string;
    weatherRain?: number;
};

export type ActivityRecord = {
    hostId: string;
    title: string;
    sportType: string;
    description: string;
    locationName: string;
    address?: string;
    latitude: number;
    longitude: number;
    geohash: string;
    startTime: string;
    endTime?: string;
    skillLevel: ActivitySkillLevel;
    capacity: number;
    participantCount: number;
    /**
     * Denormalized count of `pending` join requests (approval-gated
     * activities). Maintained transactionally by the participants
     * service so reads never fan out; legacy rows without the field
     * read as 0.
     */
    pendingRequestCount: number;
    status: ActivityStatus;
    coverImagePath?: string;
    coverImageUrl?: string;
    joinPolicy?: ActivityJoinPolicy;
    /**
     * Whether joining costs money. Always present on records written
     * after this field existed; legacy rows without it read as `false`
     * (free) so old payloads keep rendering the Free chip.
     */
    isPaid: boolean;
    /**
     * Entry fee in NZD per person. Only present on paid activities;
     * omitted for free ones. For `split` mode this is the worst-case
     * per-person price (`totalCost / minPlayers`).
     */
    fee?: number;
    /**
     * Pricing mode for paid activities (`fixed` = flat per person,
     * `split` = shared total). Present on records written after this
     * field existed; legacy rows without it read as `fixed`.
     */
    feeMode?: ActivityFeeMode;
    /**
     * Total cost to split (NZD). Only present on `split`-mode paid
     * activities.
     */
    totalCost?: number;
    /**
     * Minimum players for `split` mode. Absent means full capacity.
     */
    minPlayers?: number;
    /**
     * Weather snapshot (see [CreateActivityInput]). Absent on legacy rows.
     */
    weatherTemp?: number | null;
    weatherCode?: number;
    weatherDesc?: string;
    weatherRain?: number;
    cancelledAt?: FirebaseFirestore.Timestamp;
    cancelledBy?: string;
    createdAt: FirebaseFirestore.Timestamp;
    updatedAt: FirebaseFirestore.Timestamp;
};
/**
 * One "I want sport X at skill Y" entry from the mobile filter sheet.
 * Bundled into a single query parameter: `sportFilters=Sport:skill`
 * (comma-separated). `skill=any` matches every row for that sport
 * server-side and is a no-op filter.
 */
export type SportSkillFilter = {
    sport: string;
    skill: ActivitySkillLevel | 'any';
};

export type ListActivitiesFilters = {
    status?: ActivityStatus;
    sportType?: string;
    skillLevel?: ActivitySkillLevel;
    limit: number;
    /** When set, ranked by preference match first, then proximity,
     *  then soonest start time, then newest created. */
    discover?: {
        near?: { latitude: number; longitude: number; radiusKm: number };
        /** Inclusive start-time lower bound (ISO). */
        startAfter?: string;
        /** Inclusive start-time upper bound (ISO). */
        startBefore?: string;
        /** Sport+skill entries — empty means no sport filter. */
        sportFilters: SportSkillFilter[];
        /** Set of activityIds the viewer has already swiped on.
         *  Omit to skip the filter (e.g. for "Start over"). */
        excludeActivityIds?: string[];
        /** When true, passed cards are kept in the results while
         *  right-swiped (joined) cards stay excluded — a join is
         *  permanent and the game lives on in My Games. Backs the
         *  mobile "Start over" action. */
        includeSwiped?: boolean;
    };
    /** Authenticated viewer's uid — required whenever `discover` is
     *  set, so the pipeline can resolve `excludeActivityIds` from the
     *  swipes collection if the caller didn't pass them. */
    viewerUid?: string;
};

export type ActivityWithId = ActivityRecord & {
    activityId: string;
    hostProfile: PublicUserProfile | null;
};

export type JoinRequestStatus = 'none' | 'pending' | 'approved' | 'declined';

export type ActivityViewerContext = {
    mySwipeDecision: SwipeDecision | null;
    isParticipant: boolean;
    isHost: boolean;
    /**
     * The viewer's join-request state for approval-gated activities.
     * Always `none` for open activities (or when no request exists) so
     * clients can branch on a single field.
     */
    joinRequestStatus: JoinRequestStatus;
};

export type ActivityWithViewerContext = ActivityWithId & ActivityViewerContext;

export type PublicActivityTeaser = {
    activityId: string;
    title: string;
    sportType: string;
    locationName: string;
    latitude: number;
    longitude: number;
    startTime: string;
    skillLevel: ActivitySkillLevel;
    availableSpots: number;
    coverImageUrl?: string;
};

type ActivityBaseWithId = ActivityRecord & {
    activityId: string;
};

export async function createActivity(input: CreateActivityInput): Promise<{ activityId: string }> {
    const now = Timestamp.now();

    const hostId = input.hostId.trim();
    const title = input.title.trim();
    const sportType = input.sportType.trim();
    const description = input.description.trim();
    const locationName = input.locationName.trim();
    const address = input.address?.trim();
    const latitude = input.latitude;
    const longitude = input.longitude;
    const geohash = input.geohash.trim();
    const startTime = input.startTime.trim();
    const endTime = input.endTime?.trim();
    const skillLevel = input.skillLevel;
    const capacity = input.capacity;
    const coverImageUrl = input.coverImageUrl?.trim();
    const joinPolicy = input.joinPolicy ?? 'open';

    if (!hostId) throw new Error('hostId is required');
    if (!title) throw new Error('title is required');
    if (!sportType) throw new Error('sportType is required');
    if (!description) throw new Error('description is required');
    if (!locationName) throw new Error('locationName is required');
    if (!geohash) throw new Error('geohash is required');
    if (!startTime) throw new Error('startTime is required');

    if (typeof latitude !== 'number' || latitude < -90 || latitude > 90) {
        throw new Error('latitude must be a number between -90 and 90');
    }

    if (typeof longitude !== 'number' || longitude < -180 || longitude > 180) {
        throw new Error('longitude must be a number between -180 and 180');
    }

    if (!['beginner', 'intermediate', 'advanced', 'any'].includes(skillLevel)) {
        throw new Error('skillLevel is invalid');
    }

    if (!isJoinPolicy(joinPolicy)) {
        throw new Error('joinPolicy must be open or approval');
    }

    if (!Number.isInteger(capacity) || capacity <= 0) {
        throw new Error('capacity must be a positive integer');
    }

    const { isPaid, fee } = resolvePaidFee(input.isPaid, input.fee);
    const split = resolveSplitCost(
        input.feeMode,
        input.totalCost,
        input.minPlayers,
        capacity,
    );
    // Split mode without an explicit per-person fee: derive the worst
    // case so old clients (which only read `fee`) still render a price.
    const effectiveFee =
        fee ??
        (isPaid && split.feeMode === 'split' && split.totalCost !== undefined
            ? Math.round(
                    (split.totalCost / (split.minPlayers ?? capacity)) * 100,
                ) / 100
            : undefined);

    // Weather snapshot (best-effort, all optional). Validated lightly —
    // a bad snapshot must never fail activity creation.
    const weather = normalizeWeatherSnapshot({
        weatherTemp: input.weatherTemp,
        weatherCode: input.weatherCode,
        weatherDesc: input.weatherDesc,
        weatherRain: input.weatherRain,
    });

    const activitiesRef = firestore.collection('activities');
    const newActivityRef = activitiesRef.doc();

    await newActivityRef.set({
        hostId,
        title,
        sportType,
        description,
        locationName,
        ...(address ? { address } : {}),
        latitude,
        longitude,
        geohash,
        startTime,
        ...(endTime ? { endTime } : {}),
        skillLevel,
        capacity,
        participantCount: 0,
        pendingRequestCount: 0,
        status: 'open',
        ...(coverImageUrl ? { coverImageUrl } : {}),
        joinPolicy,
        isPaid,
        ...(effectiveFee !== undefined ? { fee: effectiveFee } : {}),
        feeMode: split.feeMode,
        ...(split.totalCost !== undefined ? { totalCost: split.totalCost } : {}),
        ...(split.minPlayers !== undefined ? { minPlayers: split.minPlayers } : {}),
        ...weather,
        createdAt: now,
        updatedAt: now,
    });

    return {
        activityId: newActivityRef.id,
    };
}

export async function getActivityById(activityId: string): Promise<ActivityWithId | null> {
    const normalizedActivityId = activityId.trim();

    if (!normalizedActivityId) {
        throw new Error('activityId is required');
    }

    const activityDoc = await firestore.doc(activityDocPath(normalizedActivityId)).get();

    if (!activityDoc.exists) {
        return null;
    }

    return enrichActivityWithHostProfile(mapActivityDoc(activityDoc));
}

export async function listActivities(
    filters: ListActivitiesFilters,
): Promise<ActivityWithId[]> {
    // Best-effort expiry sweep — fire-and-forget so a slow/stuck
    // sweep never adds latency to the read path. See
    // `activity-lifecycle.service.ts` for the full driver story.
    sweepExpiredActivities().catch(() => undefined);
    let query: FirebaseFirestore.Query = firestore.collection('activities');

    if (filters.status !== undefined) {
        query = query.where('status', '==', filters.status);
    }

    if (filters.sportType !== undefined) {
        query = query.where('sportType', '==', filters.sportType.trim());
    }

    if (filters.skillLevel !== undefined) {
        query = query.where('skillLevel', '==', filters.skillLevel);
    }

    // NOTE: no server-side orderBy here on purpose. `where(status) +
    // orderBy(createdAt)` needs a composite Firestore index; sorting the
    // (already small, limit-capped-at-50) result set in memory keeps the
    // endpoint working with zero index ops. If the collection grows
    // large, create the composite index and restore orderBy+limit.
    const snap = await query.get();

    // Deterministic start gate for joinable listings. The expiry sweep
    // is eventual + fire-and-forget, so just-started `open` rows would
    // otherwise leak into feeds whose join then 409s. Scoped to `open`
    // (the default): history reads (`completed`, `cancelled`, …) must
    // keep returning past games.
    const nowMs = Date.now();
    const gateStart = (filters.status ?? 'open') === 'open';

    const activities = snap.docs
        .map(mapActivityDoc)
        .filter((a) => {
            if (!gateStart) return true;
            const startMs = Date.parse(a.startTime);
            return !Number.isNaN(startMs) && startMs >= nowMs;
        })
        .sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis())
        .slice(0, filters.limit);

    return Promise.all(activities.map(enrichActivityWithHostProfile));
}

/**
 * Paginated "My Games" reads — powers the mobile Hosting / Upcoming tabs
 * without client-side filtering of a capped feed.
 *
 * - `hosted`: `where(hostId == viewer)` — single-field equality, automatic
 *   index, no composite needed.
 * - `joined`: collection-group `participants where uid == viewer` to resolve
 *   activityIds, then fetch those docs (hosted rows excluded — they have
 *   their own tab). Host check runs in memory since a user joins few games.
 *
 * Sorting + paging happen in memory (soonest `startTime` first,
 * `slice(offset, offset+limit)`) for the same reason as {@link listActivities}:
 * avoids the `where + orderBy` composite-index requirement. My Games tabs
 * (Upcoming / Hosting) must read nearest-first so the featured card is the
 * closest game. If My Games grows large, create the composite index and
 * push sort/page into the query.
 *
 * Terminal states (`cancelled`, `completed`, `removed`) are excluded:
 * Upcoming/Hosting are live games (`open`/`full`) only. Cancelled games
 * surface in Past (mobile queries them explicitly with a CANCELLED label),
 * completed ones via the Past `status=completed` read, and removed ones
 * nowhere — an admin-hidden game must not linger in anyone's list.
 */
export async function listMyActivities(
    viewerUid: string,
    kind: 'hosted' | 'joined',
    limit: number,
    offset = 0,
): Promise<ActivityWithId[]> {
    const uid = viewerUid.trim();
    if (!uid) throw new Error('uid is required');
    if (!Number.isInteger(limit) || limit <= 0 || limit > 50) {
        throw new Error('limit must be an integer between 1 and 50');
    }
    if (!Number.isInteger(offset) || offset < 0) {
        throw new Error('offset must be a non-negative integer');
    }

    if (kind === 'hosted') {
        const snap = await firestore
            .collection('activities')
            .where('hostId', '==', uid)
            .get();
        const activities = snap.docs
            .map(mapActivityDoc)
            .filter((a) => !isTerminalStatus(a.status))
            .sort(compareStartTimeAsc)
            .slice(offset, offset + limit);
        return Promise.all(activities.map(enrichActivityWithHostProfile));
    }

    const partSnap = await firestore
        .collectionGroup('participants')
        .where('uid', '==', uid)
        .get();
    const activityIds = [
        ...new Set(
            partSnap.docs
                .map((d) => d.ref.parent.parent?.id)
                .filter((id): id is string => typeof id === 'string' && id.length > 0),
        ),
    ];
    if (activityIds.length === 0) return [];
    const snaps = await Promise.all(
        activityIds.map((id) => firestore.doc(activityDocPath(id)).get()),
    );
    const activities = snaps
        .filter((s) => s.exists)
        .map(mapActivityDoc)
        .filter((a) => a.hostId !== uid)
        .filter((a) => !isTerminalStatus(a.status))
        .sort(compareStartTimeAsc)
        .slice(offset, offset + limit);
    return Promise.all(activities.map(enrichActivityWithHostProfile));
}

/**
 * True for lifecycles that must not appear in Upcoming/Hosting
 * (`cancelled` called off, `completed` finished, `removed` admin-hidden).
 * `full` is NOT terminal — it flips back to `open` when a spot frees up.
 */
function isTerminalStatus(status: ActivityStatus): boolean {
    return status === 'cancelled' || status === 'completed' || status === 'removed';
}

/**
 * Soonest event first (rows without a parseable start go last).
 * Shared by the My Games hosted/joined reads so Upcoming + Hosting
 * always render nearest-first. Sorted in memory — a user joins/hosts
 * few games, and a server-side orderBy would need a composite index.
 */
function compareStartTimeAsc(
    a: { startTime: string },
    b: { startTime: string },
): number {
    const aMs = Date.parse(a.startTime);
    const bMs = Date.parse(b.startTime);
    if (Number.isNaN(aMs)) return Number.isNaN(bMs) ? 0 : 1;
    if (Number.isNaN(bMs)) return -1;
    return aMs - bMs;
}

export async function listPublicActivityTeasers(
    limit = 10,
): Promise<PublicActivityTeaser[]> {
    if (!Number.isInteger(limit) || limit <= 0 || limit > 20) {
        throw new Error('limit must be an integer between 1 and 20');
    }

    // NOTE: same as listActivities — in-memory sort avoids the
    // composite-index requirement for `where(status) +
    // orderBy(createdAt)`.
    const snap = await firestore
        .collection('activities')
        .where('status', '==', 'open')
        .get();

    const activities = snap.docs
        .map(mapActivityDoc)
        .sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis())
        .slice(0, limit);

    return activities.map((activity) => ({
        activityId: activity.activityId,
        title: activity.title,
        sportType: activity.sportType,
        locationName: activity.locationName,
        latitude: activity.latitude,
        longitude: activity.longitude,
        startTime: activity.startTime,
        skillLevel: activity.skillLevel,
        availableSpots: Math.max(activity.capacity - activity.participantCount, 0),
        ...(activity.coverImageUrl !== undefined ? { coverImageUrl: activity.coverImageUrl } : {}),
    }));
}

export async function updateActivityCover(input: UpdateActivityCoverInput): Promise<void> {
    const activityId = input.activityId.trim();
    const hostId = input.hostId.trim();
    const coverImagePath = input.coverImagePath.trim();
    const coverImageUrl = input.coverImageUrl.trim();
    const now = Timestamp.now();

    if (!activityId) {
        throw new Error('activityId is required');
    }

    if (!hostId) {
        throw new Error('hostId is required');
    }

    if (!coverImagePath) {
        throw new Error('coverImagePath is required');
    }

    if (!coverImageUrl) {
        throw new Error('coverImageUrl is required');
    }

    if (!coverImagePath.startsWith(`activities/${activityId}/cover/`)) {
        throw new Error('coverImagePath must belong to the activity');
    }

    const activityRef = firestore.doc(activityDocPath(activityId));

    await firestore.runTransaction(async (transaction) => {
        const activitySnap = await transaction.get(activityRef);

        if (!activitySnap.exists) {
            throw new Error('Activity not found');
        }

        const data = activitySnap.data();

        if (data?.hostId !== hostId) {
            throw new Error('Only the activity host can update this activity');
        }

        transaction.update(activityRef, {
            coverImagePath,
            coverImageUrl,
            updatedAt: now,
        });
    });
}

export async function updateActivityStatus(input: UpdateActivityStatusInput): Promise<void> {
    const activityId = input.activityId.trim();
    const hostId = input.hostId.trim();
    const status = input.status;
    const now = Timestamp.now();

    if (!activityId) {
        throw new Error('activityId is required');
    }

    if (!hostId) {
        throw new Error('hostId is required');
    }

    if (
        status !== 'open' &&
        status !== 'cancelled' &&
        status !== 'completed' &&
        status !== 'removed'
    ) {
        throw new Error('status must be open, cancelled, completed, or removed');
    }

    const activityRef = firestore.doc(activityDocPath(activityId));

    await firestore.runTransaction(async (transaction) => {
        const activitySnap = await transaction.get(activityRef);

        if (!activitySnap.exists) {
            throw new Error('Activity not found');
        }

        const data = activitySnap.data();

        if (data?.hostId !== hostId) {
            throw new Error('Only the activity host can update this activity');
        }

        transaction.update(activityRef, {
            status,
            updatedAt: now,
        });
    });
}

export async function updateActivity(input: UpdateActivityInput): Promise<void> {
    const activityId = input.activityId.trim();
    const hostId = input.hostId.trim();
    const now = Timestamp.now();

    if (!activityId) {
        throw new Error('activityId is required');
    }

    if (!hostId) {
        throw new Error('hostId is required');
    }

    const updates: Partial<ActivityRecord> = {
        updatedAt: now,
    };

    if (input.title !== undefined) updates.title = input.title.trim();
    if (input.sportType !== undefined) updates.sportType = input.sportType.trim();
    if (input.description !== undefined) updates.description = input.description.trim();
    if (input.locationName !== undefined) updates.locationName = input.locationName.trim();
    if (input.address !== undefined) updates.address = input.address.trim();
    if (input.latitude !== undefined) {
        if (typeof input.latitude !== 'number' || input.latitude < -90 || input.latitude > 90) {
            throw new Error('latitude must be a number between -90 and 90');
        }

        updates.latitude = input.latitude;
    }
    if (input.longitude !== undefined) {
        if (typeof input.longitude !== 'number' || input.longitude < -180 || input.longitude > 180) {
            throw new Error('longitude must be a number between -180 and 180');
        }

        updates.longitude = input.longitude;
    }
    if (input.geohash !== undefined) updates.geohash = input.geohash.trim();
    if (input.startTime !== undefined) updates.startTime = input.startTime.trim();
    if (input.endTime !== undefined) updates.endTime = input.endTime.trim();
    if (input.coverImageUrl !== undefined) updates.coverImageUrl = input.coverImageUrl.trim();
    if (input.joinPolicy !== undefined) {
        if (!isJoinPolicy(input.joinPolicy)) {
            throw new Error('joinPolicy must be open or approval');
        }

        updates.joinPolicy = input.joinPolicy;
    }

    Object.assign(
        updates,
        normalizeWeatherSnapshot({
            weatherTemp: input.weatherTemp,
            weatherCode: input.weatherCode,
            weatherDesc: input.weatherDesc,
            weatherRain: input.weatherRain,
        }),
    );

    if (input.skillLevel !== undefined){
        if(
            input.skillLevel !== 'beginner' &&
            input.skillLevel !== 'intermediate' &&
            input.skillLevel !== 'advanced' &&
            input.skillLevel !== 'any'
        ){
            throw new Error('skillLevel must be beginner, intermediate, advanced, or any');
        }

        updates.skillLevel = input.skillLevel;
    }

    if(input.capacity !== undefined){
        if(!Number.isInteger(input.capacity) || input.capacity <= 0){
            throw new Error('capacity must be a positive integer');
        }
        updates.capacity = input.capacity;
    }

    // Paid/free changes are resolved inside the transaction against the
    // current doc: flipping to paid without a fee keeps the existing
    // fee when there is one, otherwise it is a 400. Flipping to free
    // clears any stored fee.
    const wantsPaidChange = input.isPaid !== undefined || input.fee !== undefined;
    if (input.isPaid !== undefined && typeof input.isPaid !== 'boolean') {
        throw new Error('isPaid must be a boolean');
    }
    if (input.fee !== undefined && (typeof input.fee !== 'number' || !Number.isFinite(input.fee) || input.fee <= 0)) {
        throw new Error('fee must be a positive number for paid activities');
    }
    if (input.feeMode !== undefined && !isFeeMode(input.feeMode)) {
        throw new Error('feeMode must be fixed or split');
    }
    if (input.totalCost !== undefined && (typeof input.totalCost !== 'number' || !Number.isFinite(input.totalCost) || input.totalCost <= 0)) {
        throw new Error('totalCost must be a positive number for split mode');
    }
    if (input.minPlayers !== undefined && (!Number.isInteger(input.minPlayers) || input.minPlayers < 2)) {
        throw new Error('minPlayers must be an integer >= 2');
    }
    const stringFields = [
        updates.title,
        updates.sportType,
        updates.description,
        updates.locationName,
        updates.geohash,
        updates.startTime,
    ];

    if(stringFields.some((value) => value !== undefined && !value)){
        throw new Error('updated string fields cannot be blank');
    }

    const activityRef = firestore.doc(activityDocPath(activityId));

    await firestore.runTransaction(async (transaction) =>{
        const activitySnap = await transaction.get(activityRef);
        
        if(!activitySnap.exists){
            throw new Error('Activity not found');
        }

        const data = activitySnap.data();

        if(data?.hostId !== hostId){
            throw new Error('Only the activity host can update this activity');
        }

        if (wantsPaidChange) {
            const currentPaid = data?.isPaid === true;
            const currentFee = typeof data?.fee === 'number' ? (data.fee as number) : undefined;
            const nextPaid = input.isPaid ?? currentPaid;
            const nextFee = input.fee ?? currentFee;
            const resolved = resolvePaidFee(nextPaid, nextFee);
            updates.isPaid = resolved.isPaid;
            if (resolved.fee !== undefined) {
                updates.fee = resolved.fee;
            } else {
                // Clear a stale fee when the activity goes free.
                (updates as Record<string, unknown>).fee = FieldValue.delete();
            }
            // Split-cost fields ride along with paid changes; going free
            // clears them too so stale split data never lingers.
            const nextMode = input.feeMode ??
                (isFeeMode(data?.feeMode) ? data.feeMode as ActivityFeeMode : 'fixed');
            if (!resolved.isPaid) {
                (updates as Record<string, unknown>).feeMode = FieldValue.delete();
                (updates as Record<string, unknown>).totalCost = FieldValue.delete();
                (updates as Record<string, unknown>).minPlayers = FieldValue.delete();
            } else if (nextMode === 'split') {
                const capacity = (updates.capacity as number | undefined) ??
                    (typeof data?.capacity === 'number' ? data.capacity as number : 10);
                const split = resolveSplitCost(
                    nextMode,
                    input.totalCost ?? (typeof data?.totalCost === 'number' ? data.totalCost as number : undefined),
                    input.minPlayers ?? (Number.isInteger(data?.minPlayers) ? data.minPlayers as number : undefined),
                    capacity,
                );
                (updates as Record<string, unknown>).feeMode = split.feeMode;
                if (split.totalCost !== undefined) {
                    (updates as Record<string, unknown>).totalCost = split.totalCost;
                    // Keep `fee` as the worst-case per-person price for old clients.
                    (updates as Record<string, unknown>).fee =
                        Math.round((split.totalCost / (split.minPlayers ?? capacity)) * 100) / 100;
                }
                if (split.minPlayers !== undefined) {
                    (updates as Record<string, unknown>).minPlayers = split.minPlayers;
                }
            } else {
                (updates as Record<string, unknown>).feeMode = 'fixed';
                (updates as Record<string, unknown>).totalCost = FieldValue.delete();
                (updates as Record<string, unknown>).minPlayers = FieldValue.delete();
            }
        }

        transaction.update(activityRef, updates);
    });

}

export async function enrichActivityWithHostProfile(
    activity: ActivityBaseWithId,
): Promise<ActivityWithId> {
    const hostProfile = await getPublicUserProfile(activity.hostId);

    return {
        ...activity,
        hostProfile,
    };
}

export async function getViewerActivityContext(
    activity: ActivityWithId,
    uid: string,
): Promise<ActivityViewerContext> {
    const normalizedUid = uid.trim();

    if (!normalizedUid) {
        throw new Error('uid is required');
    }

    const [swipe, participantSnap, requestSnap] = await Promise.all([
        getSwipeDecision(normalizedUid, activity.activityId),
        firestore.doc(activityParticipantDocPath(activity.activityId, normalizedUid)).get(),
        firestore.doc(activityJoinRequestDocPath(activity.activityId, normalizedUid)).get(),
    ]);

    const requestData = requestSnap.exists ? requestSnap.data() : undefined;
    const joinRequestStatus: JoinRequestStatus =
        requestData?.status === 'pending' ||
        requestData?.status === 'approved' ||
        requestData?.status === 'declined'
            ? requestData.status
            : 'none';

    return {
        mySwipeDecision: swipe?.decision ?? null,
        isParticipant: participantSnap.exists,
        isHost: activity.hostId === normalizedUid,
        joinRequestStatus,
    };
}

export async function attachViewerActivityContext(
    activity: ActivityWithId,
    uid: string,
): Promise<ActivityWithViewerContext> {
    const viewerContext = await getViewerActivityContext(activity, uid);

    return {
        ...activity,
        ...viewerContext,
    };
}

function mapActivityDoc(activityDoc: FirebaseFirestore.DocumentSnapshot): ActivityBaseWithId {
    const data = activityDoc.data();

    if (!data) {
        throw new Error('Invalid activity record: data is missing');
    }

    if (typeof data.hostId !== 'string') {
        throw new Error('Invalid activity record: hostId must be a string');
    }
    if (typeof data.title !== 'string') {
        throw new Error('Invalid activity record: title must be a string');
    }
    if (typeof data.sportType !== 'string') {
        throw new Error('Invalid activity record: sportType must be a string');
    }
    if (typeof data.description !== 'string') {
        throw new Error('Invalid activity record: description must be a string');
    }
    if (typeof data.locationName !== 'string') {
        throw new Error('Invalid activity record: locationName must be a string');
    }
    if (typeof data.geohash !== 'string') {
        throw new Error('Invalid activity record: geohash must be a string');
    }
    if (typeof data.latitude !== 'number') {
        throw new Error('Invalid activity record: latitude must be a number');
    }
    if (typeof data.longitude !== 'number') {
        throw new Error('Invalid activity record: longitude must be a number');
    }
    if (typeof data.startTime !== 'string') {
        throw new Error('Invalid activity record: startTime must be a string');
    }
    if (typeof data.capacity !== 'number') {
        throw new Error('Invalid activity record: capacity must be a number');
    }
    if (typeof data.participantCount !== 'number') {
        throw new Error('Invalid activity record: participantCount must be a number');
    }
    if (typeof data.status !== 'string') {
        throw new Error('Invalid activity record: status must be a string');
    }
    if (!data.createdAt || typeof data.createdAt !== 'object' || !('toDate' in data.createdAt)) {
        throw new Error('Invalid activity record: createdAt must be a Firestore Timestamp');
    }
    if (!data.updatedAt || typeof data.updatedAt !== 'object' || !('toDate' in data.updatedAt)) {
        throw new Error('Invalid activity record: updatedAt must be a Firestore Timestamp');
    }
    if (
        data.cancelledAt !== undefined &&
        (!data.cancelledAt || typeof data.cancelledAt !== 'object' || !('toDate' in data.cancelledAt))
    ) {
        throw new Error('Invalid activity record: cancelledAt must be a Firestore Timestamp');
    }
    if (data.cancelledBy !== undefined && typeof data.cancelledBy !== 'string') {
        throw new Error('Invalid activity record: cancelledBy must be a string');
    }

    return {
        activityId: activityDoc.id,
        hostId: data.hostId,
        title: data.title,
        sportType: data.sportType,
        description: data.description,
        locationName: data.locationName,
        ...(typeof data.address === 'string' ? { address: data.address } : {}),
        latitude: data.latitude,
        longitude: data.longitude,
        geohash: data.geohash,
        startTime: data.startTime,
        ...(typeof data.endTime === 'string' ? { endTime: data.endTime } : {}),
        skillLevel: data.skillLevel as ActivitySkillLevel,
        capacity: data.capacity,
        participantCount: data.participantCount,
        pendingRequestCount:
            typeof data.pendingRequestCount === 'number'
                ? data.pendingRequestCount
                : 0,
        status: data.status as ActivityStatus,
        ...(typeof data.coverImagePath === 'string' ? { coverImagePath: data.coverImagePath } : {}),
        ...(typeof data.coverImageUrl === 'string' ? { coverImageUrl: data.coverImageUrl } : {}),
        joinPolicy: isJoinPolicy(data.joinPolicy) ? data.joinPolicy : 'open',
        isPaid: data.isPaid === true,
        ...(typeof data.fee === 'number' && Number.isFinite(data.fee) && data.fee > 0
            ? { fee: data.fee }
            : {}),
        feeMode: isFeeMode(data.feeMode) ? data.feeMode : 'fixed',
        ...(typeof data.totalCost === 'number' && Number.isFinite(data.totalCost) && data.totalCost > 0
            ? { totalCost: data.totalCost }
            : {}),
        ...(Number.isInteger(data.minPlayers) && (data.minPlayers as number) >= 2
            ? { minPlayers: data.minPlayers as number }
            : {}),
        ...(data.cancelledAt !== undefined
            ? { cancelledAt: data.cancelledAt as FirebaseFirestore.Timestamp }
            : {}),
        ...(typeof data.cancelledBy === 'string' ? { cancelledBy: data.cancelledBy } : {}),
        createdAt: data.createdAt as FirebaseFirestore.Timestamp,
        updatedAt: data.updatedAt as FirebaseFirestore.Timestamp,
    };
}


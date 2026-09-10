import { firestore } from '../../database/firebase.js';
import { Timestamp } from 'firebase-admin/firestore';
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
    status: ActivityStatus;
    coverImagePath?: string;
    coverImageUrl?: string;
    joinPolicy?: ActivityJoinPolicy;
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
        status: 'open',
        ...(coverImageUrl ? { coverImageUrl } : {}),
        joinPolicy,
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

    const activities = snap.docs
        .map(mapActivityDoc)
        .sort((a, b) => b.createdAt.toMillis() - a.createdAt.toMillis())
        .slice(0, filters.limit);

    return Promise.all(activities.map(enrichActivityWithHostProfile));
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
        status: data.status as ActivityStatus,
        ...(typeof data.coverImagePath === 'string' ? { coverImagePath: data.coverImagePath } : {}),
        ...(typeof data.coverImageUrl === 'string' ? { coverImageUrl: data.coverImageUrl } : {}),
        joinPolicy: isJoinPolicy(data.joinPolicy) ? data.joinPolicy : 'open',
        ...(data.cancelledAt !== undefined
            ? { cancelledAt: data.cancelledAt as FirebaseFirestore.Timestamp }
            : {}),
        ...(typeof data.cancelledBy === 'string' ? { cancelledBy: data.cancelledBy } : {}),
        createdAt: data.createdAt as FirebaseFirestore.Timestamp,
        updatedAt: data.updatedAt as FirebaseFirestore.Timestamp,
    };
}


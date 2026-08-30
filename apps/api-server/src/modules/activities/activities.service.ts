import { firestore } from '../../database/firebase.js';
import { Timestamp } from 'firebase-admin/firestore';
import { activityDocPath } from '../../database/paths.js';

export type ActivityStatus = 'open' | 'full' | 'cancelled' | 'completed' | 'removed';
export type ActivitySkillLevel = 'beginner' | 'intermediate' | 'advanced' | 'any';

export type CreateActivityInput = {
    hostId: string;
    title: string;
    sportType: string;
    description: string;
    locationName: string;
    address?: string;
    geohash: string;
    startTime: string;
    endTime?: string;
    skillLevel: ActivitySkillLevel;
    capacity: number;
    coverImageUrl?: string;
};

export type UpdateActivityStatusInput = {
    activityId: string;
    hostId: string;
    status: Exclude<ActivityStatus, 'full'>;
};

export type UpdateActivityInput = {
    activityId: string;
    hostId: string;
    title?: string;
    sportType?: string;
    description?: string;
    locationName?: string;
    address?: string;
    geohash?: string;
    startTime?: string;
    endTime?: string;
    skillLevel?: ActivitySkillLevel;
    capacity?: number;
    coverImageUrl?: string;
};

export type ActivityRecord = {
    hostId: string;
    title: string;
    sportType: string;
    description: string;
    locationName: string;
    address?: string;
    geohash: string;
    startTime: string;
    endTime?: string;
    skillLevel: ActivitySkillLevel;
    capacity: number;
    participantCount: number;
    status: ActivityStatus;
    coverImageUrl?: string;
    createdAt: FirebaseFirestore.Timestamp;
    updatedAt: FirebaseFirestore.Timestamp;
};

export type ListActivitiesFilters = {
    status?: ActivityStatus;
    sportType?: string;
    skillLevel?: ActivitySkillLevel;
    limit: number;
};

export type ActivityWithId = ActivityRecord & {
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
    const geohash = input.geohash.trim();
    const startTime = input.startTime.trim();
    const endTime = input.endTime?.trim();
    const skillLevel = input.skillLevel;
    const capacity = input.capacity;
    const coverImageUrl = input.coverImageUrl?.trim();

    if (!hostId) throw new Error('hostId is required');
    if (!title) throw new Error('title is required');
    if (!sportType) throw new Error('sportType is required');
    if (!description) throw new Error('description is required');
    if (!locationName) throw new Error('locationName is required');
    if (!geohash) throw new Error('geohash is required');
    if (!startTime) throw new Error('startTime is required');

    if (!['beginner', 'intermediate', 'advanced', 'any'].includes(skillLevel)) {
        throw new Error('skillLevel is invalid');
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
        geohash,
        startTime,
        ...(endTime ? { endTime } : {}),
        skillLevel,
        capacity,
        participantCount: 0,
        status: 'open',
        ...(coverImageUrl ? { coverImageUrl } : {}),
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

    return mapActivityDoc(activityDoc);
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

    const snap = await query
        .orderBy('createdAt', 'desc')
        .limit(filters.limit)
        .get();

    return snap.docs.map(mapActivityDoc);
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
    if (input.geohash !== undefined) updates.geohash = input.geohash.trim();
    if (input.startTime !== undefined) updates.startTime = input.startTime.trim();
    if (input.endTime !== undefined) updates.endTime = input.endTime.trim();
    if (input.coverImageUrl !== undefined) updates.coverImageUrl = input.coverImageUrl.trim();

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

function mapActivityDoc(activityDoc: FirebaseFirestore.DocumentSnapshot): ActivityWithId {
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

    return {
        activityId: activityDoc.id,
        hostId: data.hostId,
        title: data.title,
        sportType: data.sportType,
        description: data.description,
        locationName: data.locationName,
        ...(typeof data.address === 'string' ? { address: data.address } : {}),
        geohash: data.geohash,
        startTime: data.startTime,
        ...(typeof data.endTime === 'string' ? { endTime: data.endTime } : {}),
        skillLevel: data.skillLevel as ActivitySkillLevel,
        capacity: data.capacity,
        participantCount: data.participantCount,
        status: data.status as ActivityStatus,
        ...(typeof data.coverImageUrl === 'string' ? { coverImageUrl: data.coverImageUrl } : {}),
        createdAt: data.createdAt as FirebaseFirestore.Timestamp,
        updatedAt: data.updatedAt as FirebaseFirestore.Timestamp,
    };
}


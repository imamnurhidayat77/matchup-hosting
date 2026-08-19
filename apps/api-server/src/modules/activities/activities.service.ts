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
}

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
}

export type ActivityWithId = ActivityRecord & {
    activityId: string;
}

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

    const data = activityDoc.data();

    if (!data) {
        return null;
    }

    if (typeof data.hostId !== 'string') throw new Error('Invalid activity record: hostId must be a string');
    if (typeof data.title !== 'string') throw new Error('Invalid activity record: title must be a string');
    if (typeof data.sportType !== 'string') throw new Error('Invalid activity record: sportType must be a string');
    if (typeof data.description !== 'string') throw new Error('Invalid activity record: description must be a string');
    if (typeof data.locationName !== 'string') throw new Error('Invalid activity record: locationName must be a string');
    if (typeof data.geohash !== 'string') throw new Error('Invalid activity record: geohash must be a string');
    if (typeof data.startTime !== 'string') throw new Error('Invalid activity record: startTime must be a string');
    if (typeof data.capacity !== 'number') throw new Error('Invalid activity record: capacity must be a number');
    if (typeof data.participantCount !== 'number') throw new Error('Invalid activity record: participantCount must be a number');
    if (typeof data.status !== 'string') throw new Error('Invalid activity record: status must be a string');
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
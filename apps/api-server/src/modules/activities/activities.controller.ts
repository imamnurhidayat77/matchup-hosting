import type { Request, Response } from 'express';
import {
    attachViewerActivityContext,
    createActivity,
    getActivityById,
    listPublicActivityTeasers,
    listActivities,
    updateActivity,
    updateActivityStatus,
} from './activities.service.js';

const LIMIT_VALUE = 20;

type UpdateActivityStatusParams = {
    activityId: string;
};

type UpdateActivityParams = {
    activityId: string;
};

type GetActivityParams = {
    activityId: string;
};

export async function createActivityHandler(req: Request, res: Response) {
    try {
        const hostId = req.auth?.uid;
        const {
            title,
            sportType,
            description,
            locationName,
            address,
            latitude,
            longitude,
            geohash,
            startTime,
            endTime,
            skillLevel,
            capacity,
            coverImageUrl,
        } = req.body as {
            title?: unknown;
            sportType?: unknown;
            description?: unknown;
            locationName?: unknown;
            address?: unknown;
            latitude?: unknown;
            longitude?: unknown;
            geohash?: unknown;
            startTime?: unknown;
            endTime?: unknown;
            skillLevel?: unknown;
            capacity?: unknown;
            coverImageUrl?: unknown;
        };

        if (!hostId) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (typeof title !== 'string' ||
            typeof sportType !== 'string' ||
            typeof description !== 'string' ||
            typeof locationName !== 'string' ||
            typeof geohash !== 'string' ||
            typeof startTime !== 'string'
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'title, sportType, description, locationName, geohash, and startTime must be strings',
                },
            });
        }
        if (
            (address !== undefined && typeof address !== 'string') ||
            (endTime !== undefined && typeof endTime !== 'string') ||
            (coverImageUrl !== undefined && typeof coverImageUrl !== 'string')
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'address, endTime, and coverImageUrl must be strings when provided',
                },
            });
        }

        if (
            skillLevel !== 'beginner' &&
            skillLevel !== 'intermediate' &&
            skillLevel !== 'advanced' &&
            skillLevel !== 'any'
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'skillLevel must be beginner, intermediate, advanced, or any',
                },
            });
        }

        if (typeof capacity !== 'number' || !Number.isInteger(capacity) || capacity <= 0) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'capacity must be a positive integer',
                },
            });
        }

        if (typeof latitude !== 'number' || latitude < -90 || latitude > 90) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'latitude must be a number between -90 and 90',
                },
            });
        }

        if (typeof longitude !== 'number' || longitude < -180 || longitude > 180) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'longitude must be a number between -180 and 180',
                },
            });
        }

        if (
            !title.trim() ||
            !sportType.trim() ||
            !description.trim() ||
            !locationName.trim() ||
            !geohash.trim() ||
            !startTime.trim()
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'title, sportType, description, locationName, geohash, and startTime are required',
                },
            });
        }

        const result = await createActivity({
            hostId,
            title,
            sportType,
            description,
            locationName,
            latitude,
            longitude,
            geohash,
            startTime,
            skillLevel,
            capacity,
            ...(typeof address === 'string' ? { address } : {}),
            ...(typeof endTime === 'string' ? { endTime } : {}),
            ...(typeof coverImageUrl === 'string' ? { coverImageUrl } : {}),
        });

        return res.status(201).json({
            ok: true,
            data: {
                activityId: result.activityId,
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        return res.status(500).json({
            ok: false,
            error: {
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}

export async function updateActivityHandler(req: Request<UpdateActivityParams>, res: Response) {
    try {
        const hostId = req.auth?.uid;
        const { activityId } = req.params;
        const {
            title,
            sportType,
            description,
            locationName,
            address,
            latitude,
            longitude,
            geohash,
            startTime,
            endTime,
            skillLevel,
            capacity,
            coverImageUrl,
        } = req.body as {
            title?: unknown;
            sportType?: unknown;
            description?: unknown;
            locationName?: unknown;
            address?: unknown;
            latitude?: unknown;
            longitude?: unknown;
            geohash?: unknown;
            startTime?: unknown;
            endTime?: unknown;
            skillLevel?: unknown;
            capacity?: unknown;
            coverImageUrl?: unknown;
        };

        if (!hostId) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (!activityId.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        }

        const stringFields = {
            title,
            sportType,
            description,
            locationName,
            address,
            geohash,
            startTime,
            endTime,
            coverImageUrl,
        };

        if (Object.values(stringFields).some((value) => value !== undefined && typeof value !== 'string',)) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'updated string fields must be strings',
                },
            });
        }

        if (
            skillLevel !== undefined &&
            skillLevel !== 'beginner' &&
            skillLevel !== 'intermediate' &&
            skillLevel !== 'advanced' &&
            skillLevel !== 'any'
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'skillLevel must be beginner, intermediate, advanced, or any',
                },
            });
        }

        if (capacity !== undefined && (typeof capacity !== 'number' || !Number.isInteger(capacity) || capacity <= 0)) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'capacity must be a positive integer',
                },
            });
        }

        if (latitude !== undefined && (typeof latitude !== 'number' || latitude < -90 || latitude > 90)) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'latitude must be a number between -90 and 90',
                },
            });
        }

        if (longitude !== undefined && (typeof longitude !== 'number' || longitude < -180 || longitude > 180)) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'longitude must be a number between -180 and 180',
                },
            });
        }

        await updateActivity({
            activityId,
            hostId,
            ...(typeof title === 'string' ? { title } : {}),
            ...(typeof sportType === 'string' ? { sportType } : {}),
            ...(typeof description === 'string' ? { description } : {}),
            ...(typeof locationName === 'string' ? { locationName } : {}),
            ...(typeof address === 'string' ? { address } : {}),
            ...(typeof latitude === 'number' ? { latitude } : {}),
            ...(typeof longitude === 'number' ? { longitude } : {}),
            ...(typeof geohash === 'string' ? { geohash } : {}),
            ...(typeof startTime === 'string' ? { startTime } : {}),
            ...(typeof endTime === 'string' ? { endTime } : {}),
            ...(typeof skillLevel === 'string' ? { skillLevel } : {}),
            ...(typeof capacity === 'number' ? { capacity } : {}),
            ...(typeof coverImageUrl === 'string' ? { coverImageUrl } : {}),
        });

        return res.status(200).json({
            ok: true,
            data: {
                activityId,
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Activity not found') {
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message,
                },
            });
        }

        if (message === 'Only the activity host can update this activity') {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message,
                },
            });
        }

        if (message === 'updated string fields cannot be blank') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message,
                },
            });
        }

        return res.status(500).json({
            ok: false,
            error: {
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}

export async function updateActivityStatusHandler(req: Request<UpdateActivityStatusParams>, res: Response) {
    try {
        const hostId = req.auth?.uid;
        const { activityId } = req.params;
        const { status } = req.body as {
            status?: unknown;
        };

        if (!hostId) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (typeof status !== 'string') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'status must be a string',
                },
            });
        }

        if (!activityId.trim() || !status.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId and status are required',
                },
            });
        }

        if (
            status !== 'open' &&
            status !== 'cancelled' &&
            status !== 'completed' &&
            status !== 'removed'
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'status must be open, cancelled, completed, or removed',
                },
            });
        }

        await updateActivityStatus({
            activityId,
            hostId,
            status,
        });

        return res.status(200).json({
            ok: true,
            data: {
                activityId,
                status,
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Activity not found') {
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message,
                },
            });
        }

        if (message === 'Only the activity host can update this activity') {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message,
                },
            });
        }

        return res.status(500).json({
            ok: false,
            error: {
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}

export async function listActivitiesHandler(req: Request, res: Response) {
    try {
        const { status, sportType, skillLevel, limit } = req.query;

        if (status !== undefined &&
            status !== 'open' &&
            status !== 'full' &&
            status !== 'cancelled' &&
            status !== 'completed' &&
            status !== 'removed'
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'status must be open, full, cancelled, completed, or removed',
                },
            });
        }

        if (skillLevel !== undefined &&
            skillLevel !== 'beginner' &&
            skillLevel !== 'intermediate' &&
            skillLevel !== 'advanced' &&
            skillLevel !== 'any'
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'skillLevel must be beginner, intermediate, advanced, or any',
                },
            });
        }

        if (sportType !== undefined && typeof sportType !== 'string') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'sportType must be a string',
                },
            });
        }

        if (sportType !== undefined && !sportType.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'sportType is required when provided',
                },
            });
        }

        if (limit !== undefined && typeof limit !== 'string') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'limit must be an integer between 1 and 50',
                },
            });
        }

        const parsedLimit = limit === undefined ? LIMIT_VALUE : Number(limit);

        if (!Number.isInteger(parsedLimit) || parsedLimit <= 0 || parsedLimit > 50) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'limit must be an integer between 1 and 50',
                },
            });
        }

        const activities = await listActivities({
            status: status === undefined ? 'open' : status,
            ...(sportType !== undefined ? { sportType } : {}),
            ...(skillLevel !== undefined ? { skillLevel } : {}),
            limit: parsedLimit,
        });
        const viewerUid = req.auth?.uid;

        if (!viewerUid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        const data = await Promise.all(
            activities.map((activity) => attachViewerActivityContext(activity, viewerUid)),
        );

        return res.status(200).json({
            ok: true,
            data,
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        return res.status(500).json({
            ok: false,
            error: {
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}

export async function listPublicActivityTeasersHandler(req: Request, res: Response) {
    try {
        const { limit } = req.query;

        if (limit !== undefined && typeof limit !== 'string') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'limit must be an integer between 1 and 20',
                },
            });
        }

        const parsedLimit = limit === undefined ? 10 : Number(limit);

        if (!Number.isInteger(parsedLimit) || parsedLimit <= 0 || parsedLimit > 20) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'limit must be an integer between 1 and 20',
                },
            });
        }

        const activities = await listPublicActivityTeasers(parsedLimit);

        return res.status(200).json({
            ok: true,
            data: activities,
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        return res.status(500).json({
            ok: false,
            error: {
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}

export async function getActivityHandler(
    req: Request<GetActivityParams>,
    res: Response,
) {
    try {
        const { activityId } = req.params;

        if (!activityId.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'activityId is required',
                },
            });
        }

        const activity = await getActivityById(activityId);

        if (!activity) {
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
                    message: 'Activity not found',
                },
            });
        }

        const viewerUid = req.auth?.uid;

        if (!viewerUid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        const data = await attachViewerActivityContext(activity, viewerUid);

        return res.status(200).json({
            ok: true,
            data,
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        return res.status(500).json({
            ok: false,
            error: {
                code: 'INTERNAL_ERROR',
                message,
            },
        });
    }
}

import type { Request, Response } from 'express';
import { createActivity, getActivityById } from './activities.service.js';

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

        return res.status(200).json({
            ok: true,
            data: activity,
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

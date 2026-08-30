import type { Request, Response } from 'express';
import {
    deleteDevice,
    listDevices,
    registerDevice,
} from './devices.service.js';

type DevicesParams = {
    uid: string;
};

type DeleteDeviceParams = {
    uid: string;
    deviceId: string;
};

export async function registerDeviceHandler(req: Request, res: Response) {
    try {
        const uid = req.auth?.uid;
        const { deviceId, fcmToken, platform } = req.body as {
            deviceId?: unknown;
            fcmToken?: unknown;
            platform?: unknown;
        };

        if (!uid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (
            typeof deviceId !== 'string' ||
            typeof fcmToken !== 'string' ||
            typeof platform !== 'string'
        ) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'deviceId, fcmToken, and platform must be strings',
                },
            });
        }

        if (platform !== 'ios' && platform !== 'android' && platform !== 'web') {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'INVALID_INPUT',
                    message: 'platform must be ios, android, or web',
                },
            });
        }

        if (!deviceId.trim() || !fcmToken.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'deviceId and fcmToken are required',
                },
            });
        }

        await registerDevice({
            uid,
            deviceId,
            fcmToken,
            platform,
        });

        return res.status(200).json({
            ok: true,
            data: {
                uid,
                deviceId,
                platform,
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

export async function listDevicesHandler(
    req: Request<DevicesParams>,
    res: Response,
) {
    try {
        const authUid = req.auth?.uid;
        const { uid } = req.params;

        if (!authUid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (!uid.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'uid is required',
                },
            });
        }

        if (authUid !== uid) {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'You can only access your own devices',
                },
            });
        }

        const devices = await listDevices(uid);

        return res.status(200).json({
            ok: true,
            data: devices,
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

export async function deleteDeviceHandler(
    req: Request<DeleteDeviceParams>,
    res: Response,
) {
    try {
        const authUid = req.auth?.uid;
        const { uid, deviceId } = req.params;

        if (!authUid) {
            return res.status(401).json({
                ok: false,
                error: {
                    code: 'UNAUTHORIZED',
                    message: 'Authenticated user is required',
                },
            });
        }

        if (!uid.trim() || !deviceId.trim()) {
            return res.status(400).json({
                ok: false,
                error: {
                    code: 'EMPTY_INPUT',
                    message: 'uid and deviceId are required',
                },
            });
        }

        if (authUid !== uid) {
            return res.status(403).json({
                ok: false,
                error: {
                    code: 'FORBIDDEN',
                    message: 'You can only delete your own devices',
                },
            });
        }

        await deleteDevice(uid, deviceId);

        return res.status(200).json({
            ok: true,
            data: {
                uid,
                deviceId,
            },
        });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';

        if (message === 'Device not found') {
            return res.status(404).json({
                ok: false,
                error: {
                    code: 'NOT_FOUND',
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
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware.js';
import {
    deleteDeviceHandler,
    listDevicesHandler,
    registerDeviceHandler,
} from './devices.controller.js';

export const devicesRouter = Router();

devicesRouter.post('/', requireAuth, registerDeviceHandler);
devicesRouter.get('/:uid', requireAuth, listDevicesHandler);
devicesRouter.delete('/:uid/:deviceId', requireAuth, deleteDeviceHandler);
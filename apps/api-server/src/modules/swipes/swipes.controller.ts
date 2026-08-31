import type { Request, Response } from 'express';
import {
  getSwipeDecision,
  listSwipeDecisions,
  saveSwipeDecision,
} from './swipes.service.js';
import { getActivityById } from '../activities/activities.service.js';
import { createNotification } from '../notifications/notifications.service.js';

type GetSwipeParams = {
  uid: string;
  activityId: string;
};

type ListSwipeDecisionsParams = {
  uid: string;
};

export async function saveSwipeDecisionHandler(req: Request, res: Response) {
  try {
    const uid = req.auth?.uid;
    const { activityId, decision } = req.body as {
      activityId?: unknown;
      decision?: unknown;
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

    if (typeof activityId !== 'string') {
      return res.status(400).json({
        ok: false,
        error: {
          code: 'INVALID_INPUT',
          message: 'activityId must be a string',
        },
      });
    }

    if (decision !== 'pass' && decision !== 'join') {
      return res.status(400).json({
        ok: false,
        error: {
          code: 'INVALID_INPUT',
          message: 'decision must be pass or join',
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

    await saveSwipeDecision({
      uid,
      activityId,
      decision,
    });

    if (decision === 'join') {
      const activity = await getActivityById(activityId);

      if (activity && activity.hostId !== uid) {
        await createNotification({
          recipientUid: activity.hostId,
          type: 'activity_interest',
          title: 'New activity interest',
          body: 'Someone is interested in your activity',
          activityId,
          senderUid: uid,
        });
      }
    }

    return res.status(200).json({
      ok: true,
      data: {
        uid,
        activityId,
        decision,
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

    return res.status(500).json({
      ok: false,
      error: {
        code: 'INTERNAL_ERROR',
        message,
      },
    });
  }
}

export async function getSwipeDecisionHandler(
  req: Request<GetSwipeParams>,
  res: Response,
) {
  try {
    const { uid, activityId } = req.params;

    if (!uid.trim() || !activityId.trim()) {
      return res.status(400).json({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'uid and activityId are required',
        },
      });
    }

    if (req.auth?.uid !== uid) {
      return res.status(403).json({
        ok: false,
        error: {
          code: 'FORBIDDEN',
          message: 'You can only access your own swipe decisions',
        },
      });
    }

    const swipe = await getSwipeDecision(uid, activityId);

    if (!swipe) {
      return res.status(404).json({
        ok: false,
        error: {
          code: 'NOT_FOUND',
          message: 'Swipe decision not found',
        },
      });
    }

    return res.status(200).json({
      ok: true,
      data: swipe,
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

export async function listSwipeDecisionsHandler(
  req: Request<ListSwipeDecisionsParams>,
  res: Response,
) {
  try {
    const { uid } = req.params;

    if (!uid.trim()) {
      return res.status(400).json({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'uid is required',
        },
      });
    }

    if (req.auth?.uid !== uid) {
      return res.status(403).json({
        ok: false,
        error: {
          code: 'FORBIDDEN',
          message: 'You can only access your own swipe decisions',
        },
      });
    }

    const swipes = await listSwipeDecisions(uid);

    return res.status(200).json({
      ok: true,
      data: swipes,
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

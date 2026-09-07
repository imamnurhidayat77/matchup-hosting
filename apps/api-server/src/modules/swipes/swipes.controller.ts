import type { Request, Response } from 'express';
import {
  getSwipeDecision,
  listSwipeDecisions,
  saveSwipeDecision,
} from './swipes.service.js';
import { getActivityById } from '../activities/activities.service.js';
import { createNotification } from '../notifications/notifications.service.js';

type GetMySwipeParams = {
  activityId: string;
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

export async function getMySwipeDecisionHandler(
  req: Request<GetMySwipeParams>,
  res: Response,
) {
  try {
    const uid = req.auth?.uid;
    const { activityId } = req.params;

    if (!uid) {
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

export async function listMySwipeDecisionsHandler(req: Request, res: Response) {
  try {
    const uid = req.auth?.uid;

    if (!uid) {
      return res.status(401).json({
        ok: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'Authenticated user is required',
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

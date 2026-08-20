import type { Request, Response } from 'express';
import {
  getSwipeDecision,
  listSwipeDecisions,
  saveSwipeDecision,
} from './swipes.service.js';

type GetSwipeParams = {
  uid: string;
  activityId: string;
};

type ListSwipeDecisionsParams = {
  uid: string;
};

export async function saveSwipeDecisionHandler(req: Request, res: Response) {
  try {
    const { uid, activityId, decision } = req.body as {
      uid?: unknown;
      activityId?: unknown;
      decision?: unknown;
    };

    if (
      typeof uid !== 'string' || typeof activityId !== 'string') {
      return res.status(400).json({
        ok: false,
        error: {
          code: 'INVALID_INPUT',
          message: 'uid and activityId must be strings',
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

    if (!uid.trim() || !activityId.trim()) {
      return res.status(400).json({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'uid and activityId are required',
        },
      });
    }

    await saveSwipeDecision({
      uid,
      activityId,
      decision,
    });

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
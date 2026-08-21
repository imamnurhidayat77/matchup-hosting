import type { Request, Response } from 'express';
import { createUser, getUserByAuthUid } from './users.service.js';

type GetUserParams = {
  authUid: string;
};

export async function createUserHandler(req: Request, res: Response) {
  try {
    const { authUid, email } = req.body as {
      authUid?: string;
      email?: string;
    };

    if (typeof authUid !== 'string' || typeof email !== 'string') {
      return res.status(400).json({
        ok: false,
        error: {
          code: 'INVALID_INPUT',
          message: 'authUid and email must be strings',
        },
      });
    }

    if (!authUid.trim() || !email.trim()) {
      return res.status(400).json({
        ok: false,
        error: {
          code: 'EMPTY_INPUT',
          message: 'authUid and email are required',
        },
      });
    }

    await createUser({ authUid, email });

    return res.status(201).json({
      ok: true,
      data: {
        authUid: authUid.trim(),
        email: email.trim().toLowerCase(),
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';

    if (message === 'User already exists' || message === 'Email already in use') {
      return res.status(409).json({
        ok: false,
        error: {
          code: 'CONFLICT',
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

export async function getUserHandler(req: Request<GetUserParams>, res: Response) {
  try {
    const { authUid } = req.params;

    if (!authUid) {
      return res.status(400).json({
        ok: false,
        error: {
          code: 'INVALID_INPUT',
          message: 'authUid is required',
        },
      });
    }

    const user = await getUserByAuthUid(authUid);

    if (!user) {
      return res.status(404).json({
        ok: false,
        error: {
          code: 'NOT_FOUND',
          message: 'User not found',
        },
      });
    }

    return res.status(200).json({
      ok: true,
      data: user,
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
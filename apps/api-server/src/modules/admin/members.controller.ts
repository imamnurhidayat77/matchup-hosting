import type { Request, Response } from 'express';
import {
    ADMIN_MEMBERS_PAGE_LIMIT_DEFAULT,
    deleteMember,
    getMemberDetail,
    listMembers,
    setMemberStatus,
} from './members.service.js';

export async function listMembersHandler(req: Request, res: Response) {
    try {
        const rawLimit = req.query.limit;
        const limit =
            rawLimit === undefined
                ? ADMIN_MEMBERS_PAGE_LIMIT_DEFAULT
                : Number(rawLimit);
        const rows = await listMembers(limit);
        return res.status(200).json({ ok: true, data: rows });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        if (message.startsWith('limit must be between')) {
            return res.status(400).json({
                ok: false,
                error: { code: 'INVALID_INPUT', message },
            });
        }
        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

export async function getMemberHandler(
    req: Request<{ uid: string }>,
    res: Response,
) {
    try {
        const row = await getMemberDetail(req.params.uid);
        return res.status(200).json({ ok: true, data: row });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        if (message === 'uid is required') {
            return res.status(400).json({
                ok: false,
                error: { code: 'EMPTY_INPUT', message },
            });
        }
        if (message === 'User not found') {
            return res.status(404).json({
                ok: false,
                error: { code: 'NOT_FOUND', message },
            });
        }
        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

export async function setMemberStatusHandler(
    req: Request<{ uid: string }>,
    res: Response,
) {
    try {
        const body = req.body as { status?: unknown };
        const row = await setMemberStatus(req.params.uid, body?.status);
        return res.status(200).json({ ok: true, data: row });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        if (message === 'uid is required') {
            return res.status(400).json({
                ok: false,
                error: { code: 'EMPTY_INPUT', message },
            });
        }
        if (
            message === 'status must be active or suspended' ||
            message === 'status is required'
        ) {
            return res.status(400).json({
                ok: false,
                error: { code: 'INVALID_INPUT', message },
            });
        }
        if (message === 'User not found') {
            return res.status(404).json({
                ok: false,
                error: { code: 'NOT_FOUND', message },
            });
        }
        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

export async function deleteMemberHandler(
    req: Request<{ uid: string }>,
    res: Response,
) {
    try {
        await deleteMember(req.params.uid);
        return res.status(200).json({ ok: true, data: { uid: req.params.uid } });
    } catch (error) {
        const message = error instanceof Error ? error.message : 'Unknown error';
        if (message === 'uid is required') {
            return res.status(400).json({
                ok: false,
                error: { code: 'EMPTY_INPUT', message },
            });
        }
        if (message === 'User not found') {
            return res.status(404).json({
                ok: false,
                error: { code: 'NOT_FOUND', message },
            });
        }
        return res.status(500).json({
            ok: false,
            error: { code: 'INTERNAL_ERROR', message },
        });
    }
}

import { Timestamp } from 'firebase-admin/firestore';
import { firestore } from '../../database/firebase.js';
import { activityDocPath, userDocPath } from '../../database/paths.js';

export type ReportTargetType = 'user' | 'activity';

export type ReportStatus = 'pending';

export type SubmitReportInput = {
    reporterId: string;
    targetId: string;
    targetType: ReportTargetType;
    reason: string;
    details?: string;
};

export type SubmitReportResult = {
    reportId: string;
};

export type ReportRecord = {
    reporterId: string;
    targetId: string;
    targetType: ReportTargetType;
    reason: string;
    details?: string;
    status: ReportStatus;
    createdAt: FirebaseFirestore.Timestamp;
};

const MAX_REASON_LENGTH = 200;
const MAX_DETAILS_LENGTH = 2000;

export function isReportTargetType(value: unknown): value is ReportTargetType {
    return value === 'user' || value === 'activity';
}

export async function submitReport(input: SubmitReportInput): Promise<SubmitReportResult> {
    const reporterId = input.reporterId.trim();
    const targetId = input.targetId.trim();
    const reason = input.reason.trim();
    const details = input.details?.trim() || undefined;

    if (!reporterId) throw new Error('reporterId is required');
    if (!targetId) throw new Error('targetId is required');
    if (!isReportTargetType(input.targetType)) throw new Error('targetType must be user or activity');
    if (!reason) throw new Error('reason is required');

    if (reason.length > MAX_REASON_LENGTH) {
        throw new Error(`reason must be at most ${MAX_REASON_LENGTH} characters`);
    }

    if (details !== undefined && details.length > MAX_DETAILS_LENGTH) {
        throw new Error(`details must be at most ${MAX_DETAILS_LENGTH} characters`);
    }

    if (reporterId === targetId) {
        throw new Error('cannot report yourself');
    }

    const targetPath =
        input.targetType === 'user' ? userDocPath(targetId) : activityDocPath(targetId);
    const targetSnap = await firestore.doc(targetPath).get();

    if (!targetSnap.exists) {
        throw new Error('Target not found');
    }

    const record: ReportRecord = {
        reporterId,
        targetId,
        targetType: input.targetType,
        reason,
        status: 'pending',
        createdAt: Timestamp.now(),
    };

    if (details !== undefined) {
        record.details = details;
    }

    const ref = await firestore.collection('reports').add(record);

    return { reportId: ref.id };
}

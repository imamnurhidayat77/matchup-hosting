import { Timestamp } from 'firebase-admin/firestore';
import { firestore } from '../../database/firebase.js';
import {
    userNotificationDocPath,
    userNotificationsCollectionPath,
} from '../../database/paths.js';

export type NotificationType =
    | 'activity_reminder'
    | 'activity_interest'
    | 'activity_joined'
    | 'activity_left'
    | 'participant_removed'
    | 'chat_message'
    | 'system';

export type CreateNotificationInput = {
    recipientUid: string;
    type: NotificationType;
    title: string;
    body: string;
    activityId?: string;
    senderUid?: string;
};

export type NotificationRecord = {
    recipientUid: string;
    type: NotificationType;
    title: string;
    body: string;
    isRead: boolean;
    createdAt: FirebaseFirestore.Timestamp;
    readAt?: FirebaseFirestore.Timestamp;
    activityId?: string;
    senderUid?: string;
};

export type NotificationWithId = NotificationRecord & {
    notificationId: string;
};

function assertNotificationType(type: unknown): asserts type is NotificationType {
    if (type !== 'activity_reminder' &&
        type !== 'activity_interest' &&
        type !== 'activity_joined' &&
        type !== 'activity_left' &&
        type !== 'participant_removed' &&
        type !== 'chat_message' &&
        type !== 'system'
    ) {
        throw new Error('type must be activity_reminder, activity_interest, activity_joined, activity_left, participant_removed, chat_message, or system');
    }
}

function mapNotificationDoc(
    doc: FirebaseFirestore.QueryDocumentSnapshot,
): NotificationWithId {
    const data = doc.data();

    if (typeof data.recipientUid !== 'string') {
        throw new Error('Invalid notification record: recipientUid must be a string');
    }

    assertNotificationType(data.type);

    if (typeof data.title !== 'string') {
        throw new Error('Invalid notification record: title must be a string');
    }

    if (typeof data.body !== 'string') {
        throw new Error('Invalid notification record: body must be a string');
    }

    if (typeof data.isRead !== 'boolean') {
        throw new Error('Invalid notification record: isRead must be a boolean');
    }

    if (!data.createdAt || typeof data.createdAt !== 'object' || !('toDate' in data.createdAt)) {
        throw new Error('Invalid notification record: createdAt must be a Firestore Timestamp');
    }

    if (
        data.readAt !== undefined &&
        (!data.readAt || typeof data.readAt !== 'object' || !('toDate' in data.readAt))
    ) {
        throw new Error('Invalid notification record: readAt must be a Firestore Timestamp');
    }

    if (data.activityId !== undefined && typeof data.activityId !== 'string') {
        throw new Error('Invalid notification record: activityId must be a string');
    }

    if (data.senderUid !== undefined && typeof data.senderUid !== 'string') {
        throw new Error('Invalid notification record: senderUid must be a string');
    }

    return {
        notificationId: doc.id,
        recipientUid: data.recipientUid,
        type: data.type,
        title: data.title,
        body: data.body,
        isRead: data.isRead,
        createdAt: data.createdAt as FirebaseFirestore.Timestamp,
        ...(data.readAt !== undefined
            ? { readAt: data.readAt as FirebaseFirestore.Timestamp }
            : {}),
        ...(typeof data.activityId === 'string' ? { activityId: data.activityId } : {}),
        ...(typeof data.senderUid === 'string' ? { senderUid: data.senderUid } : {}),
    };
}

export async function createNotification(
    input: CreateNotificationInput,
): Promise<{ notificationId: string }> {
    const recipientUid = input.recipientUid.trim();
    const title = input.title.trim();
    const body = input.body.trim();
    const type = input.type;

    if (!recipientUid) {
        throw new Error('recipientUid is required');
    }

    assertNotificationType(type);

    if (!title) {
        throw new Error('title is required');
    }

    if (!body) {
        throw new Error('body is required');
    }

    const notificationRef = firestore
        .collection(userNotificationsCollectionPath(recipientUid))
        .doc();

    const record: NotificationRecord = {
        recipientUid,
        type,
        title,
        body,
        isRead: false,
        createdAt: Timestamp.now(),
        ...(typeof input.activityId === 'string' && input.activityId.trim()
            ? { activityId: input.activityId.trim() }
            : {}),
        ...(typeof input.senderUid === 'string' && input.senderUid.trim()
            ? { senderUid: input.senderUid.trim() }
            : {}),
    };

    await notificationRef.set(record);

    return {
        notificationId: notificationRef.id,
    };
}

export async function listNotifications(
    uid: string,
): Promise<NotificationWithId[]> {
    const normalizedUid = uid.trim();

    if (!normalizedUid) {
        throw new Error('uid is required');
    }

    const snap = await firestore
        .collection(userNotificationsCollectionPath(normalizedUid))
        .orderBy('createdAt', 'desc')
        .get();

    return snap.docs.map(mapNotificationDoc);
}

export async function markNotificationRead(
    uid: string,
    notificationId: string,
): Promise<void> {
    const normalizedUid = uid.trim();
    const normalizedNotificationId = notificationId.trim();

    if (!normalizedUid) {
        throw new Error('uid is required');
    }

    if (!normalizedNotificationId) {
        throw new Error('notificationId is required');
    }

    const notificationRef = firestore.doc(
        userNotificationDocPath(normalizedUid, normalizedNotificationId),
    );

    await firestore.runTransaction(async (transaction) => {
        const snap = await transaction.get(notificationRef);

        if (!snap.exists) {
            throw new Error('Notification not found');
        }

        transaction.update(notificationRef, {
            isRead: true,
            readAt: Timestamp.now(),
        });
    });
}

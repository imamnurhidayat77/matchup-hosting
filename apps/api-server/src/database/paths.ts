export const COLLECTIONS = {
    users: 'users',
    activities: 'activities',
    swipes: 'swipes',
    reports: 'reports',
    adminActions: 'adminActions',
    mediaAssets: 'mediaAssets',
} as const;

export const SUBCOLLECTIONS = {
    devices : 'devices',
    participants: 'participants',
    decisions: 'decisions',
    notifications: 'notifications'
} as const;

export const RTDB_PATHS = {
    activityChats: 'activityChats',
    typing: 'typing',
    presence: 'presence'
} as const;

export function userDocPath(uid: string): string {
    return `${COLLECTIONS.users}/${uid}`;
}

export function userDevicesCollectionPath(uid: string): string {
    return `${userDocPath(uid)}/${SUBCOLLECTIONS.devices}`;
}

export function userDeviceDocPath(uid: string, deviceId: string): string {
    return `${userDevicesCollectionPath(uid)}/${deviceId}`;
}

export function userNotificationsCollectionPath(uid: string): string {
    return `${userDocPath(uid)}/${SUBCOLLECTIONS.notifications}`;
}

export function userNotificationDocPath(uid: string, notificationId: string): string {
    return `${userNotificationsCollectionPath(uid)}/${notificationId}`;
}

export function activityDocPath(activityId: string): string {
    return `${COLLECTIONS.activities}/${activityId}`;
}

export function activityParticipantsCollectionPath(activityId: string): string {
    return `${activityDocPath(activityId)}/${SUBCOLLECTIONS.participants}`;
}

export function activityParticipantDocPath (activityId: string, uid: string): string {
    return `${activityParticipantsCollectionPath(activityId)}/${uid}`;
}

export function swipeDecisionsCollectionPath(uid: string): string {
    return `${COLLECTIONS.swipes}/${uid}/${SUBCOLLECTIONS.decisions}`;
}

export function swipeDecisionDocPath (uid: string, activityId: string): string {
    return `${swipeDecisionsCollectionPath(uid)}/${activityId}`
}

export function reportDocPath(reportId: string): string {
  return `${COLLECTIONS.reports}/${reportId}`;
}

export function adminActionDocPath(actionId: string): string {
  return `${COLLECTIONS.adminActions}/${actionId}`;
}

export function mediaAssetDocPath(assetId: string): string {
  return `${COLLECTIONS.mediaAssets}/${assetId}`;
}

export function activityChatPath(activityId: string): string {
  return `${RTDB_PATHS.activityChats}/${activityId}`;
}

export function activityMessagesPath(activityId: string): string {
  return `${activityChatPath(activityId)}/messages`;
}

export function activityMessagePath(activityId: string, messageId: string): string {
  return `${activityMessagesPath(activityId)}/${messageId}`;
}

export function typingPath(activityId: string, uid: string): string {
  return `${RTDB_PATHS.typing}/${activityId}/${uid}`;
}

export function presencePath(uid: string): string {
  return `${RTDB_PATHS.presence}/${uid}`;
}
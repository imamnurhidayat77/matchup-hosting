# MatchUp API Contract

Last updated: Monday, August 31, 2026 (NZ local time)

## Scope

This document describes the current backend HTTP contract for the `apps/api-server` service. As the development progressing, this document is in effect of change.

Current implemented domains:

- health
- users
- presence
- typing
- chat
- activities
- activity participants
- swipes
- notifications
- devices

## Base URL

Intended API base path:

```text
/api
```

Examples:

```text
GET /api/health
POST /api/users
GET /api/activities/:activityId
```

## Response Envelope

Successful responses:

```json
{
  "ok": true,
  "data": {}
}
```

Error responses:

```json
{
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  }
}
```

## Common Error Codes

- `INVALID_INPUT`
- `EMPTY_INPUT`
- `NOT_FOUND`
- `CONFLICT`
- `INTERNAL_ERROR`
- `DB_UNAVAILABLE`
- `INVALID_STATE`
- `UNAUTHORIZED`
- `FORBIDDEN`

---

## Health

### `GET /api/health`

Checks whether the API server is alive and Firestore is reachable.

Success `200`:

```json
{
  "ok": true,
  "data": {
    "status": "ok",
    "service": "api-server",
    "database": "connected"
  }
}
```

Failure `503`:

```json
{
  "ok": false,
  "error": {
    "code": "DB_UNAVAILABLE",
    "message": "Firestore unreachable"
  }
}
```

---

## Users

### `POST /api/users`

Creates a user document.

Request body:

```json
{
  "authUid": "firebase-auth-uid",
  "email": "user@example.com"
}
```

Success `201`:

```json
{
  "ok": true,
  "data": {
    "authUid": "firebase-auth-uid",
    "email": "user@example.com"
  }
}
```

Errors:

- `400 INVALID_INPUT` if `authUid` or `email` are not strings
- `400 EMPTY_INPUT` if `authUid` or `email` are blank
- `409 CONFLICT` if user already exists
- `409 CONFLICT` if email already in use

### `GET /api/users/:authUid`

Gets a user by Firebase Auth UID.

Success `200`:

```json
{
  "ok": true,
  "data": {
    "authUid": "firebase-auth-uid",
    "email": "user@example.com",
    "createdAt": {
      "_seconds": 0,
      "_nanoseconds": 0
    }
  }
}
```

Errors:

- `400 INVALID_INPUT` if `authUid` is missing
- `404 NOT_FOUND` if user does not exist

---

## Presence

### `POST /api/presence`

Sets user presence.

Request body:

```json
{
  "state": "online"
}
```

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

Allowed `state` values:

- `online`
- `offline`

Success `200`:

```json
{
  "ok": true,
  "data": {
    "uid": "firebase-auth-uid",
    "state": "online"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 INVALID_STATE` if `state` is not `online` or `offline`

### `GET /api/presence/:uid`

Gets presence for one user.

Success `200`:

```json
{
  "ok": true,
  "data": {
    "state": "online",
    "lastChanged": 1787000000000
  }
}
```

Errors:

- `400 EMPTY_INPUT` if `uid` is blank
- `404 NOT_FOUND` if presence record does not exist

---

## Typing

### `POST /api/typing`

Sets typing status for a user in an activity.

Request body:

```json
{
  "activityId": "activity-id",
  "isTyping": true
}
```

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

Success `200`:

```json
{
  "ok": true,
  "data": {
    "activityId": "activity-id",
    "uid": "firebase-auth-uid",
    "isTyping": true
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 INVALID_INPUT` if `activityId` is not a string
- `400 INVALID_INPUT` if `isTyping` is not a boolean
- `400 EMPTY_INPUT` if `activityId` is blank

### `GET /api/typing/:activityId/:uid`

Gets typing status for one user in one activity.

Success `200`:

```json
{
  "ok": true,
  "data": {
    "isTyping": true,
    "updatedAt": 1787000000000
  }
}
```

Errors:

- `400 EMPTY_INPUT` if `activityId` is blank
- `400 EMPTY_INPUT` if `uid` is blank
- `404 NOT_FOUND` if typing status does not exist

---

## Chat

### `POST /api/chat/messages`

Creates a chat message in an activity chat room.

Request body:

```json
{
  "activityId": "activity-id",
  "text": "Hello",
  "type": "text"
}
```

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `senderId` is derived from the verified Firebase Auth user

Allowed `type` values:

- `text`
- `system`

Default `type`:

- `text`

Success `201`:

```json
{
  "ok": true,
  "data": {
    "messageId": "generated-message-id"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 INVALID_INPUT` if `activityId` or `text` are not strings
- `400 INVALID_INPUT` if `type` is invalid
- `400 EMPTY_INPUT` if `activityId` or `text` are blank

### `GET /api/chat/:activityId/messages`

Lists chat messages for one activity.

Success `200`:

```json
{
  "ok": true,
  "data": [
    {
      "messageId": "generated-message-id",
      "senderId": "firebase-auth-uid",
      "text": "Hello",
      "type": "text",
      "timestamp": 1787000000000
    }
  ]
}
```

Errors:

- `400 EMPTY_INPUT` if `activityId` is blank

---

## Activities

### `POST /api/activities`

Creates an activity.

Request body:

```json
{
  "title": "Evening Futsal",
  "sportType": "futsal",
  "description": "Casual 5v5 session",
  "locationName": "Auckland Domain",
  "address": "Optional address",
  "geohash": "rckq2m",
  "startTime": "2026-08-20T18:30:00+12:00",
  "endTime": "2026-08-20T20:00:00+12:00",
  "skillLevel": "any",
  "capacity": 10,
  "coverImageUrl": "https://example.com/cover.jpg"
}
```

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `hostId` is derived from the verified Firebase Auth user

Allowed `skillLevel` values:

- `beginner`
- `intermediate`
- `advanced`
- `any`

Success `201`:

```json
{
  "ok": true,
  "data": {
    "activityId": "generated-activity-id"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 INVALID_INPUT` if required string fields are not strings
- `400 INVALID_INPUT` if optional string fields are provided with wrong type
- `400 INVALID_INPUT` if `skillLevel` is invalid
- `400 INVALID_INPUT` if `capacity` is not a positive integer
- `400 EMPTY_INPUT` if required string fields are blank

### `GET /api/activities`

Lists activities for discovery/feed views.

Query parameters:

```text
status=open
sportType=futsal
skillLevel=any
limit=20
```

Defaults:

- `status` defaults to `open`
- `limit` defaults to `20`

Limits:

- `limit` must be an integer between `1` and `50`

Allowed `status` values:

- `open`
- `full`
- `cancelled`
- `completed`
- `removed`

Allowed `skillLevel` values:

- `beginner`
- `intermediate`
- `advanced`
- `any`

Success `200`:

```json
{
  "ok": true,
  "data": [
    {
      "activityId": "generated-activity-id",
      "hostId": "firebase-auth-uid",
      "title": "Evening Futsal",
      "sportType": "futsal",
      "description": "Casual 5v5 session",
      "locationName": "Auckland Domain",
      "geohash": "rckq2m",
      "startTime": "2026-08-20T18:30:00+12:00",
      "skillLevel": "any",
      "capacity": 10,
      "participantCount": 0,
      "status": "open",
      "createdAt": {
        "_seconds": 0,
        "_nanoseconds": 0
      },
      "updatedAt": {
        "_seconds": 0,
        "_nanoseconds": 0
      }
    }
  ]
}
```

Errors:

- `400 INVALID_INPUT` if `status` is invalid
- `400 INVALID_INPUT` if `skillLevel` is invalid
- `400 INVALID_INPUT` if `sportType` is not a string
- `400 INVALID_INPUT` if `limit` is not an integer between `1` and `50`
- `400 EMPTY_INPUT` if `sportType` is blank when provided

### `PATCH /api/activities/:activityId`

Updates editable activity details. Only the activity host can update an activity.

Request body:

```json
{
  "title": "Updated Futsal",
  "sportType": "futsal",
  "description": "Updated activity description",
  "locationName": "Auckland Domain",
  "address": "Optional updated address",
  "geohash": "rckq2m",
  "startTime": "2026-08-20T18:30:00+12:00",
  "endTime": "2026-08-20T20:00:00+12:00",
  "skillLevel": "intermediate",
  "capacity": 12,
  "coverImageUrl": "https://example.com/updated-cover.jpg"
}
```

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user must be the activity host

Notes:

- All request body fields are optional.
- `status` is not updated through this endpoint. Use `PATCH /api/activities/:activityId/status`.

Success `200`:

```json
{
  "ok": true,
  "data": {
    "activityId": "generated-activity-id"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 INVALID_INPUT` if an updated string field is not a string
- `400 INVALID_INPUT` if `skillLevel` is invalid
- `400 INVALID_INPUT` if `capacity` is not a positive integer
- `400 EMPTY_INPUT` if `activityId` is blank
- `400 EMPTY_INPUT` if an updated string field is blank
- `403 FORBIDDEN` if the authenticated user is not the activity host
- `404 NOT_FOUND` if activity does not exist

### `PATCH /api/activities/:activityId/status`

Updates an activity status. Only the activity host can update status.

Request body:

```json
{
  "status": "cancelled"
}
```

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user must be the activity host

Allowed `status` values:

- `open`
- `cancelled`
- `completed`
- `removed`

Note:

- `full` is not manually set through this endpoint. It should be derived from capacity and participant count.

Success `200`:

```json
{
  "ok": true,
  "data": {
    "activityId": "generated-activity-id",
    "status": "cancelled"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 INVALID_INPUT` if `status` is not a string
- `400 INVALID_INPUT` if `status` is not `open`, `cancelled`, `completed`, or `removed`
- `400 EMPTY_INPUT` if `activityId` or `status` are blank
- `403 FORBIDDEN` if the authenticated user is not the activity host
- `404 NOT_FOUND` if activity does not exist

### `GET /api/activities/:activityId`

Gets one activity by id.

Success `200`:

```json
{
  "ok": true,
  "data": {
    "activityId": "generated-activity-id",
    "hostId": "firebase-auth-uid",
    "title": "Evening Futsal",
    "sportType": "futsal",
    "description": "Casual 5v5 session",
    "locationName": "Auckland Domain",
    "address": "Optional address",
    "geohash": "rckq2m",
    "startTime": "2026-08-20T18:30:00+12:00",
    "endTime": "2026-08-20T20:00:00+12:00",
    "skillLevel": "any",
    "capacity": 10,
    "participantCount": 0,
    "status": "open",
    "coverImageUrl": "https://example.com/cover.jpg",
    "createdAt": {
      "_seconds": 0,
      "_nanoseconds": 0
    },
    "updatedAt": {
      "_seconds": 0,
      "_nanoseconds": 0
    }
  }
}
```

Errors:

- `400 EMPTY_INPUT` if `activityId` is blank
- `404 NOT_FOUND` if activity does not exist

---

## Activity Participants

### `POST /api/activities/:activityId/participants`

Joins a user to an activity.

Side effects:

- Creates an `activity_joined` notification for the activity host when the joining user is not the host.

Request body:

```json
{}
```

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

Success `200`:

```json
{
  "ok": true,
  "data": {
    "activityId": "generated-activity-id",
    "uid": "firebase-auth-uid"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `activityId` is blank
- `404 NOT_FOUND` if activity does not exist
- `409 CONFLICT` if activity is not open
- `409 CONFLICT` if activity is full
- `409 CONFLICT` if user already joined

### `GET /api/activities/:activityId/participants`

Lists participants for an activity.

Success `200`:

```json
{
  "ok": true,
  "data": [
    {
      "participantId": "firebase-auth-uid",
      "uid": "firebase-auth-uid",
      "joinedAt": {
        "_seconds": 0,
        "_nanoseconds": 0
      }
    }
  ]
}
```

Errors:

- `400 EMPTY_INPUT` if `activityId` is blank

### `DELETE /api/activities/:activityId/participants/:uid`

Removes a participant from an activity.

Side effects:

- Creates an `activity_left` notification for the activity host when a participant removes themselves and the participant is not the host.
- Creates a `participant_removed` notification for the removed participant when the activity host removes another participant.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user can remove themselves
- The activity host can remove any participant from their own activity

Success `200`:

```json
{
  "ok": true,
  "data": {
    "activityId": "generated-activity-id",
    "uid": "firebase-auth-uid"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `activityId` is blank
- `403 FORBIDDEN` if the authenticated user is neither the target participant nor the activity host
- `404 NOT_FOUND` if activity does not exist
- `404 NOT_FOUND` if participant does not exist

---

## Swipes

### `POST /api/swipes`

Creates or updates a swipe decision for a user on an activity.

Side effects:

- Creates an `activity_interest` notification for the activity host when `decision` is `join` and the swiping user is not the host.
- Does not create a notification when `decision` is `pass`.

Request body:

```json
{
  "activityId": "generated-activity-id",
  "decision": "join"
}
```

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

Allowed `decision` values:

- `pass`
- `join`

Success `200`:

```json
{
  "ok": true,
  "data": {
    "uid": "firebase-auth-uid",
    "activityId": "generated-activity-id",
    "decision": "join"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 INVALID_INPUT` if `activityId` is not a string
- `400 INVALID_INPUT` if `decision` is invalid
- `400 EMPTY_INPUT` if `activityId` is blank
- `404 NOT_FOUND` if activity does not exist

### `GET /api/swipes/:uid`

Lists swipe decisions for a user.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user can only access their own swipe decisions

Success `200`:

```json
{
  "ok": true,
  "data": [
    {
      "swipeId": "generated-activity-id",
      "uid": "firebase-auth-uid",
      "activityId": "generated-activity-id",
      "decision": "join",
      "createdAt": {
        "_seconds": 0,
        "_nanoseconds": 0
      },
      "updatedAt": {
        "_seconds": 0,
        "_nanoseconds": 0
      }
    }
  ]
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `uid` is blank
- `403 FORBIDDEN` if the authenticated user does not own the requested swipe decisions

### `GET /api/swipes/:uid/:activityId`

Gets one swipe decision for a user and activity.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user can only access their own swipe decision

Success `200`:

```json
{
  "ok": true,
  "data": {
    "swipeId": "generated-activity-id",
    "uid": "firebase-auth-uid",
    "activityId": "generated-activity-id",
    "decision": "join",
    "createdAt": {
      "_seconds": 0,
      "_nanoseconds": 0
    },
    "updatedAt": {
      "_seconds": 0,
      "_nanoseconds": 0
    }
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `uid` or `activityId` are blank
- `403 FORBIDDEN` if the authenticated user does not own the requested swipe decision
- `404 NOT_FOUND` if swipe decision does not exist

---

## Notifications

Current delivery behavior:

- Notifications are persisted as in-app notification records under the recipient user's notification collection.
- The backend does not send Firebase Cloud Messaging push notifications yet.
- The frontend should fetch notifications with `GET /api/notifications/me` or later attach a listener if realtime notification UX is required.
- Event-generated notifications currently include activity join, participant self-leave, and host participant removal.

### `POST /api/notifications`

Creates a notification for a target user.

Request body:

```json
{
  "recipientUid": "firebase-auth-uid",
  "type": "activity_joined",
  "title": "New participant",
  "body": "A user joined your activity",
  "activityId": "generated-activity-id",
  "senderUid": "firebase-auth-uid"
}
```

Allowed `type` values:

- `activity_reminder`
- `activity_interest`
- `activity_joined`
- `activity_left`
- `participant_removed`
- `chat_message`
- `system`

Success `201`:

```json
{
  "ok": true,
  "data": {
    "notificationId": "generated-notification-id"
  }
}
```

Errors:

- `400 INVALID_INPUT` if `recipientUid`, `type`, `title`, or `body` are not strings
- `400 INVALID_INPUT` if `activityId` or `senderUid` are provided with the wrong type
- `400 INVALID_INPUT` if `type` is invalid
- `400 EMPTY_INPUT` if `recipientUid`, `title`, or `body` are blank

### `GET /api/notifications/me`

Lists notifications for the authenticated user.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

Success `200`:

```json
{
  "ok": true,
  "data": [
    {
      "notificationId": "generated-notification-id",
      "recipientUid": "firebase-auth-uid",
      "type": "activity_joined",
      "title": "New participant",
      "body": "A user joined your activity",
      "isRead": false,
      "createdAt": {
        "_seconds": 0,
        "_nanoseconds": 0
      },
      "activityId": "generated-activity-id",
      "senderUid": "firebase-auth-uid"
    }
  ]
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid

### `GET /api/notifications/:uid`

Lists notifications for one user.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user can only access their own notifications

Success `200`:

```json
{
  "ok": true,
  "data": [
    {
      "notificationId": "generated-notification-id",
      "recipientUid": "firebase-auth-uid",
      "type": "activity_joined",
      "title": "New participant",
      "body": "A user joined your activity",
      "isRead": false,
      "createdAt": {
        "_seconds": 0,
        "_nanoseconds": 0
      },
      "activityId": "generated-activity-id",
      "senderUid": "firebase-auth-uid"
    }
  ]
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `uid` is blank
- `403 FORBIDDEN` if the authenticated user tries to access another user's notifications

### `PATCH /api/notifications/me/:notificationId/read`

Marks one notification as read for the authenticated user.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

Success `200`:

```json
{
  "ok": true,
  "data": {
    "uid": "firebase-auth-uid",
    "notificationId": "generated-notification-id",
    "isRead": true
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `notificationId` is blank
- `404 NOT_FOUND` if notification does not exist

### `PATCH /api/notifications/:uid/:notificationId/read`

Marks one notification as read.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user can only update their own notifications

Success `200`:

```json
{
  "ok": true,
  "data": {
    "uid": "firebase-auth-uid",
    "notificationId": "generated-notification-id",
    "isRead": true
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `uid` or `notificationId` are blank
- `403 FORBIDDEN` if the authenticated user tries to update another user's notification
- `404 NOT_FOUND` if notification does not exist

---

## Devices

### `POST /api/devices`

Registers or updates a device for the authenticated user.

Request body:

```json
{
  "deviceId": "device-1",
  "fcmToken": "firebase-cloud-messaging-token",
  "platform": "android"
}
```

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

Allowed `platform` values:

- `ios`
- `android`
- `web`

Success `200`:

```json
{
  "ok": true,
  "data": {
    "uid": "firebase-auth-uid",
    "deviceId": "device-1",
    "platform": "android"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 INVALID_INPUT` if `deviceId`, `fcmToken`, or `platform` are not strings
- `400 INVALID_INPUT` if `platform` is invalid
- `400 EMPTY_INPUT` if `deviceId` or `fcmToken` are blank

### `GET /api/devices/:uid`

Lists registered devices for one user.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user can only access their own devices

Success `200`:

```json
{
  "ok": true,
  "data": [
    {
      "deviceId": "device-1",
      "uid": "firebase-auth-uid",
      "fcmToken": "firebase-cloud-messaging-token",
      "platform": "android",
      "createdAt": {
        "_seconds": 0,
        "_nanoseconds": 0
      },
      "updatedAt": {
        "_seconds": 0,
        "_nanoseconds": 0
      }
    }
  ]
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `uid` is blank
- `403 FORBIDDEN` if the authenticated user tries to access another user's devices

### `DELETE /api/devices/:uid/:deviceId`

Deletes one registered device.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user can only delete their own devices

Success `200`:

```json
{
  "ok": true,
  "data": {
    "uid": "firebase-auth-uid",
    "deviceId": "device-1"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `uid` or `deviceId` are blank
- `403 FORBIDDEN` if the authenticated user tries to delete another user's device
- `404 NOT_FOUND` if device does not exist

---

## Notes For Future Revisions

- User-owned write routes derive identity from verified Firebase Auth instead of trusting request body values.
- User-owned read routes still accept `uid` from route params and may need authorization rules later.
- `POST /api/notifications` is currently available as a server/admin-style creation route and should not be exposed as a normal client write route without additional authorization.
- `swipeId` currently equals `activityId` because swipe documents use `activityId` as the Firestore document id under `swipes/{uid}/decisions/{activityId}`.

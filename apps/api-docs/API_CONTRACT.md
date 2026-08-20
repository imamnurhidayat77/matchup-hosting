# MatchUp API Contract

Last updated: August 20, 2026

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
  "uid": "firebase-auth-uid",
  "state": "online"
}
```

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

- `400 INVALID_INPUT` if `uid` is not a string
- `400 INVALID_STATE` if `state` is not `online` or `offline`
- `400 EMPTY_INPUT` if `uid` is blank

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
  "uid": "firebase-auth-uid",
  "isTyping": true
}
```

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

- `400 INVALID_INPUT` if `activityId` or `uid` are not strings
- `400 INVALID_INPUT` if `isTyping` is not a boolean
- `400 EMPTY_INPUT` if `activityId` or `uid` are blank

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
  "senderId": "firebase-auth-uid",
  "text": "Hello",
  "type": "text"
}
```

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

- `400 INVALID_INPUT` if `activityId`, `senderId`, or `text` are not strings
- `400 INVALID_INPUT` if `type` is invalid
- `400 EMPTY_INPUT` if `activityId`, `senderId`, or `text` are blank

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
  "coverImageUrl": "https://example.com/cover.jpg"
}
```

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

- `400 INVALID_INPUT` if required string fields are not strings
- `400 INVALID_INPUT` if optional string fields are provided with wrong type
- `400 INVALID_INPUT` if `skillLevel` is invalid
- `400 INVALID_INPUT` if `capacity` is not a positive integer
- `400 EMPTY_INPUT` if required string fields are blank

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

Request body:

```json
{
  "uid": "firebase-auth-uid"
}
```

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

- `400 INVALID_INPUT` if `uid` is not a string
- `400 EMPTY_INPUT` if `activityId` or `uid` are blank
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

- `400 EMPTY_INPUT` if `activityId` or `uid` are blank
- `404 NOT_FOUND` if activity does not exist
- `404 NOT_FOUND` if participant does not exist

---

## Swipes

### `POST /api/swipes`

Creates or updates a swipe decision for a user on an activity.

Request body:

```json
{
  "uid": "firebase-auth-uid",
  "activityId": "generated-activity-id",
  "decision": "join"
}
```

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

- `400 INVALID_INPUT` if `uid` or `activityId` are not strings
- `400 INVALID_INPUT` if `decision` is invalid
- `400 EMPTY_INPUT` if `uid` or `activityId` are blank
- `404 NOT_FOUND` if activity does not exist

### `GET /api/swipes/:uid`

Lists swipe decisions for a user.

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

- `400 EMPTY_INPUT` if `uid` is blank

### `GET /api/swipes/:uid/:activityId`

Gets one swipe decision for a user and activity.

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

- `400 EMPTY_INPUT` if `uid` or `activityId` are blank
- `404 NOT_FOUND` if swipe decision does not exist

---

## Notes For Future Revisions

- Current user-owned routes still accept `uid` from request body or path params.
- Production auth middleware should later replace that with verified Firebase Auth identity.
- `swipeId` currently equals `activityId` because swipe documents use `activityId` as the Firestore document id under `swipes/{uid}/decisions/{activityId}`.

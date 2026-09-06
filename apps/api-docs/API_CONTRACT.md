# MatchUp API Contract

Last updated: Sunday, September 6, 2026 (NZ local time)

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
POST /api/users/me
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

Frontend auth flow:

- Register and sign-in should be handled by Firebase Auth on the frontend.
- After Firebase Auth returns an ID token, the frontend should call `POST /api/users/me` to create or load the backend user profile.

### `POST /api/users/me`

Bootstraps the authenticated user's Firestore profile after Firebase Auth sign-in. This route is idempotent: it creates the profile if missing and returns the existing profile if already created.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `authUid` is derived from the verified Firebase Auth user
- If the Firebase ID token contains an email, the backend uses the token email before the request body email

Request body:

```json
{
  "email": "user@example.com"
}
```

Success `201` when created:

```json
{
  "ok": true,
  "data": {
    "authUid": "firebase-auth-uid",
    "email": "user@example.com",
    "created": true
  }
}
```

Success `200` when already exists:

```json
{
  "ok": true,
  "data": {
    "authUid": "firebase-auth-uid",
    "email": "user@example.com",
    "created": false
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 INVALID_INPUT` if `email` is not a string and no token email is available
- `400 EMPTY_INPUT` if `email` is blank and no token email is available
- `409 CONFLICT` if email already in use by another user

### `GET /api/users/me`

Gets the authenticated user's profile.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `authUid` is derived from the verified Firebase Auth user

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

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `404 NOT_FOUND` if user profile does not exist

### `PATCH /api/users/me`

Updates editable profile fields for the authenticated user.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `authUid` is derived from the verified Firebase Auth user

Editable fields:

- `displayName`
- `bio`
- `gender`
- `dateOfBirth`
- `skillLevel`
- `preferredSports`
- `preferredLocations`

Non-editable through this route:

- `authUid`
- `email`
- `photoPath`
- `photoUrl`
- `createdAt`

Request body:

```json
{
  "displayName": "Test User",
  "bio": "Weekend futsal player",
  "gender": "male",
  "dateOfBirth": "2000-01-01",
  "skillLevel": "intermediate",
  "preferredSports": ["futsal", "badminton"],
  "preferredLocations": ["Auckland"]
}
```

Allowed `skillLevel` values:

- `beginner`
- `intermediate`
- `advanced`
- `any`

Success `200`:

```json
{
  "ok": true,
  "data": {
    "authUid": "firebase-auth-uid",
    "email": "user@example.com",
    "displayName": "Test User",
    "bio": "Weekend futsal player",
    "skillLevel": "intermediate",
    "preferredSports": ["futsal", "badminton"],
    "preferredLocations": ["Auckland"],
    "profileCompleted": true,
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
- `400 EMPTY_INPUT` if no editable profile field is provided
- `400 INVALID_INPUT` if the body contains unsupported fields
- `400 INVALID_INPUT` if string fields are not strings
- `400 INVALID_INPUT` if `skillLevel` is invalid
- `400 INVALID_INPUT` if `preferredSports` or `preferredLocations` are not string arrays
- `404 NOT_FOUND` if user profile does not exist

### `PATCH /api/users/me/photo`

Stores the authenticated user's Firebase Storage profile photo metadata after frontend upload.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `authUid` is derived from the verified Firebase Auth user

Storage path:

- `photoPath` must start with `users/{authUid}/profile/`
- Example: `users/firebase-auth-uid/profile/avatar-1787200000000.jpg`

Firebase Storage upload constraints:

- The frontend uploads directly to Firebase Storage before calling this route.
- The authenticated Firebase user can only upload under their own `users/{authUid}/profile/` folder.
- Allowed content types: `image/jpeg`, `image/png`, `image/webp`.
- Maximum file size: `5MB`.
- Firebase Storage Rules enforce these constraints; the backend stores only `photoPath` and `photoUrl` metadata.

Request body:

```json
{
  "photoPath": "users/firebase-auth-uid/profile/avatar-1787200000000.jpg",
  "photoUrl": "https://storage.googleapis.com/bucket/users/firebase-auth-uid/profile/avatar-1787200000000.jpg"
}
```

Success `200`:

```json
{
  "ok": true,
  "data": {
    "authUid": "firebase-auth-uid",
    "email": "user@example.com",
    "photoPath": "users/firebase-auth-uid/profile/avatar-1787200000000.jpg",
    "photoUrl": "https://storage.googleapis.com/bucket/users/firebase-auth-uid/profile/avatar-1787200000000.jpg",
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
- `400 INVALID_INPUT` if `photoPath` or `photoUrl` are not strings
- `400 EMPTY_INPUT` if `photoPath` or `photoUrl` are blank
- `403 FORBIDDEN` if `photoPath` does not belong to the authenticated user
- `404 NOT_FOUND` if user profile does not exist

### `GET /api/users/:uid/profile`

Gets a safe public profile for another user. This route does not expose private fields such as `email`, devices, or notifications.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`

Success `200`:

```json
{
  "ok": true,
  "data": {
    "authUid": "firebase-auth-uid",
    "displayName": "Test User",
    "photoUrl": "https://example.com/avatar.png",
    "bio": "Weekend futsal player",
    "skillLevel": "intermediate",
    "preferredSports": ["futsal"],
    "preferredLocations": ["Auckland"],
    "profileCompleted": true
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `uid` is blank
- `404 NOT_FOUND` if user profile does not exist

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

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- Any authenticated app user can read another user's presence
- This route is not owner-restricted

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

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
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

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- Any authenticated app user can read another user's typing status for a visible activity/chat context
- This route is not owner-restricted

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

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
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
- The authenticated user must be the activity host or an activity participant

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
- `403 FORBIDDEN` if the authenticated user is not the activity host or a participant
- `404 NOT_FOUND` if activity does not exist

### `GET /api/chat/:activityId/messages`

Lists chat messages for one activity.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user must be the activity host or an activity participant

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

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `activityId` is blank
- `403 FORBIDDEN` if the authenticated user is not the activity host or a participant
- `404 NOT_FOUND` if activity does not exist

---

## Activities

### `GET /api/public/activities`

Lists limited public activity teaser data for non-authenticated discovery surfaces.

Authentication:

- Not required

Query parameters:

```text
limit=10
```

Defaults:

- `limit` defaults to `10`

Limits:

- `limit` must be an integer between `1` and `20`

Success `200`:

```json
{
  "ok": true,
  "data": [
    {
      "activityId": "generated-activity-id",
      "title": "Evening Futsal",
      "sportType": "futsal",
      "locationName": "Auckland Domain",
      "latitude": -36.8585,
      "longitude": 174.775,
      "startTime": "2026-08-20T18:30:00+12:00",
      "skillLevel": "any",
      "availableSpots": 4,
      "coverImageUrl": "https://example.com/cover.jpg"
    }
  ]
}
```

Errors:

- `400 INVALID_INPUT` if `limit` is not an integer between `1` and `20`
- `500 INTERNAL_ERROR` if the public activity feed cannot be loaded

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
  "latitude": -36.8585,
  "longitude": 174.775,
  "geohash": "rckq2m",
  "startTime": "2026-08-20T18:30:00+12:00",
  "endTime": "2026-08-20T20:00:00+12:00",
  "skillLevel": "any",
  "capacity": 10
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
- `400 INVALID_INPUT` if `latitude` is not a number between `-90` and `90`
- `400 INVALID_INPUT` if `longitude` is not a number between `-180` and `180`
- `400 INVALID_INPUT` if `skillLevel` is invalid
- `400 INVALID_INPUT` if `capacity` is not a positive integer
- `400 EMPTY_INPUT` if required string fields are blank

### `GET /api/activities`

Lists activities for discovery/feed views.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- Each activity includes viewer-specific fields for the authenticated user

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
      "latitude": -36.8585,
      "longitude": 174.775,
      "geohash": "rckq2m",
      "startTime": "2026-08-20T18:30:00+12:00",
      "skillLevel": "any",
      "capacity": 10,
      "participantCount": 0,
      "status": "open",
      "hostProfile": {
        "authUid": "firebase-auth-uid",
        "displayName": "Test User",
        "photoUrl": "https://example.com/avatar.png"
      },
      "mySwipeDecision": "join",
      "isParticipant": true,
      "isHost": false,
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
  "latitude": -36.8585,
  "longitude": 174.775,
  "geohash": "rckq2m",
  "startTime": "2026-08-20T18:30:00+12:00",
  "endTime": "2026-08-20T20:00:00+12:00",
  "skillLevel": "intermediate",
  "capacity": 12
}
```

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user must be the activity host

Notes:

- All request body fields are optional.
- `status` is not updated through this endpoint. Use `PATCH /api/activities/:activityId/status`.
- Cover image metadata is not updated through this endpoint. Use `PATCH /api/activities/:activityId/cover`.

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
- `400 INVALID_INPUT` if `latitude` is not a number between `-90` and `90`
- `400 INVALID_INPUT` if `longitude` is not a number between `-180` and `180`
- `400 INVALID_INPUT` if `skillLevel` is invalid
- `400 INVALID_INPUT` if `capacity` is not a positive integer
- `400 EMPTY_INPUT` if `activityId` is blank
- `400 EMPTY_INPUT` if an updated string field is blank
- `403 FORBIDDEN` if the authenticated user is not the activity host
- `404 NOT_FOUND` if activity does not exist

### `PATCH /api/activities/:activityId/cover`

Stores an activity cover image's Firebase Storage metadata after frontend upload. Only the activity host can save cover metadata.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The authenticated user must be the activity host

Storage path:

- `coverImagePath` must start with `activities/{activityId}/cover/`
- Example: `activities/generated-activity-id/cover/cover-1787200000000.jpg`

Firebase Storage upload constraints:

- The frontend uploads directly to Firebase Storage before calling this route.
- Allowed content types: `image/jpeg`, `image/png`, `image/webp`.
- Maximum file size: `8MB`.
- Firebase Storage Rules enforce content type and size. The backend enforces activity host ownership before storing metadata.

Request body:

```json
{
  "coverImagePath": "activities/generated-activity-id/cover/cover-1787200000000.jpg",
  "coverImageUrl": "https://storage.googleapis.com/bucket/activities/generated-activity-id/cover/cover-1787200000000.jpg"
}
```

Success `200`:

```json
{
  "ok": true,
  "data": {
    "activityId": "generated-activity-id",
    "coverImagePath": "activities/generated-activity-id/cover/cover-1787200000000.jpg",
    "coverImageUrl": "https://storage.googleapis.com/bucket/activities/generated-activity-id/cover/cover-1787200000000.jpg"
  }
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `activityId` is blank
- `400 INVALID_INPUT` if `coverImagePath` or `coverImageUrl` are not strings
- `400 EMPTY_INPUT` if `coverImagePath` or `coverImageUrl` are blank
- `403 FORBIDDEN` if `coverImagePath` does not belong to the activity
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

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- The response includes viewer-specific fields for the authenticated user

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
    "latitude": -36.8585,
    "longitude": 174.775,
    "geohash": "rckq2m",
    "startTime": "2026-08-20T18:30:00+12:00",
    "endTime": "2026-08-20T20:00:00+12:00",
    "skillLevel": "any",
    "capacity": 10,
    "participantCount": 0,
    "status": "open",
    "coverImageUrl": "https://example.com/cover.jpg",
    "hostProfile": {
      "authUid": "firebase-auth-uid",
      "displayName": "Test User",
      "photoUrl": "https://example.com/avatar.png"
    },
    "mySwipeDecision": "join",
    "isParticipant": true,
    "isHost": false,
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

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`

Success `200`:

```json
{
  "ok": true,
  "data": [
    {
      "participantId": "firebase-auth-uid",
      "uid": "firebase-auth-uid",
      "profile": {
        "authUid": "firebase-auth-uid",
        "displayName": "Test User",
        "photoUrl": "https://example.com/avatar.png"
      },
      "joinedAt": {
        "_seconds": 0,
        "_nanoseconds": 0
      }
    }
  ]
}
```

Errors:

- `401 UNAUTHORIZED` if the Firebase ID token is missing or invalid
- `400 EMPTY_INPUT` if `activityId` is blank

### `DELETE /api/activities/:activityId/participants/:uid`

Removes a participant from an activity.

Side effects:

- Creates an `activity_left` notification for the activity host when a participant removes themselves and the participant is not the host.
- Creates a `participant_removed` notification for the removed participant when the activity host removes another participant.
- If the activity host removes themselves, the activity is marked `cancelled`, `cancelledAt` and `cancelledBy` are stored, and all non-host participants receive an `activity_cancelled` notification.

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

### `GET /api/swipes/me`

Lists swipe decisions for the authenticated user.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

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

### `GET /api/swipes/me/:activityId`

Gets one swipe decision for the authenticated user and activity.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

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
- `400 EMPTY_INPUT` if `activityId` is blank
- `404 NOT_FOUND` if swipe decision does not exist

---

## Notifications

Current delivery behavior:

- Notifications are persisted as in-app notification records under the recipient user's notification collection.
- The backend does not send Firebase Cloud Messaging push notifications yet.
- The frontend should fetch notifications with `GET /api/notifications/me` or later attach a listener if realtime notification UX is required.
- Notification records are created internally by backend services; there is no public client route for creating notifications.
- Event-generated notifications currently include activity interest, activity join, activity cancellation, participant self-leave, and host participant removal.

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

---

## Devices

Device routes derive `uid` from the verified Firebase ID token.

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

### `GET /api/devices/me`

Lists registered devices for the authenticated user.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

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

### `DELETE /api/devices/me/:deviceId`

Deletes one registered device for the authenticated user.

Authentication:

- Requires `Authorization: Bearer <firebase-id-token>`
- `uid` is derived from the verified Firebase Auth user

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
- `400 EMPTY_INPUT` if `deviceId` is blank
- `404 NOT_FOUND` if device does not exist

---

## Notes For Future Revisions

- User-owned write routes derive identity from verified Firebase Auth instead of trusting request body values.
- User-owned read routes use `/me` and derive identity from verified Firebase Auth.
- `swipeId` currently equals `activityId` because swipe documents use `activityId` as the Firestore document id under `swipes/{uid}/decisions/{activityId}`.

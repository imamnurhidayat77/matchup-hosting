# Mobile ↔ API Contract (gap analysis)

Generated from code inspection (mobile `main` + `mobile/use-backend-service`,
api-server `main`). Purpose: single checklist for the backend team on what
still needs building/changing before `USE_REMOTE_API=true` works end-to-end.

## Transport

- Base URL: `{Env.apiBaseUrl}/api` (mobile `ApiClient`: `baseUrl =
  '${Env.apiBaseUrl}/api'`). No `/v1` segment — the `/api/v1/...` paths
  mentioned in some mobile comments do not exist.
- Auth: `Authorization: Bearer <Firebase ID token>` (mobile injects via
  `_AuthInterceptor`, refreshes on 401). Backend `requireAuth` verifies with
  Firebase Admin and exposes `req.auth.uid`. Host/user identity comes from
  the token, not the body.

## Headline issue: naming convention mismatch

Mobile parses **snake_case** everywhere (`sport_type`, `date_time`,
`participant_count`, `sender_id`, `created_at`, …). The backend speaks
**camelCase** (`sportType`, `startTime`, `participantCount`, …) — e.g.
`POST /api/activities` reads `sportType/locationName/startTime/capacity`
from the body while mobile sends
`title/sport_type/location/date_time/max_participants/skill_level/fee/duration_minutes`.
Even the endpoints that "exist" are wire-incompatible. **Decision needed:
pick one convention (recommendation: snake_case, matching mobile + the
`{ratee_uid, stars}` / `{target_id, target_type}` shapes already defined
for ratings/reports) and align both sides.**

Legend: ✅ exists & compatible · ⚠️ exists but wire-incompatible ·
❌ missing (mobile falls back to local impl).

## Activities (`/api/activities`)

| Method & path | Mobile caller | Status |
|---|---|---|
| `GET /activities?limit&offset` | `feed()` | ⚠️ route exists, response shape unverified vs `ActivityModel.fromJson` (snake_case keys: `sport_type`, `distance_km`, `date_time`, `skill_level`, `participant_count`, `host_name`, `cover_image_url`, `duration_minutes`, `status` as **name string**) |
| `GET /activities/:id` | `byId()` | ⚠️ returns camelCase Firestore doc (`activityId`, `sportType`, `locationName`, `startTime`, …) — mobile expects snake_case |
| `POST /activities` | `create()` | ⚠️ body mismatch (see above). Mobile sends: `title`, `sport_type`, `location`, `date_time` (ISO), `max_participants`, `skill_level`, `fee`, `duration_minutes`. Backend reads: `title`, `sportType`, `description`, `locationName`, `address`, `geohash`, `startTime`, `endTime`, `skillLevel`, `capacity`, `coverImageUrl` |
| `GET /activities/search?sport&skill&max_km` | `search()` | ❌ no route |
| `POST /activities/:id/join` | `join()` | ❌ no route |
| `POST /activities/:id/leave` | `leave()` | ❌ no route |
| `POST /activities/:id/cancel` | `cancel()` | ❌ no route |
| `GET /activities/:id/participants` | `participants()` | ❌ no route. Mobile expects list of `{user_id, name, avatar_asset, skill_level, joined_at, is_organizer}` |

## Users (`/api/users`)

| Method & path | Mobile caller | Status |
|---|---|---|
| `POST /users {authUid, email}` | `register()` (after Firebase sign-up) | ✅ compatible (`createUser({authUid, email})`) |
| `GET /users/:uid` | `me()`, `byId()` | ⚠️ route is `GET /:authUid` — exists, but response shape vs mobile `_parse` unverified |
| `PATCH /users/me` | `updateProfile()` | ❌ no route. Mobile sends: `display_name`, `bio`, `location`, `email`, `phone`, `date_of_birth` (ISO), `height_cm`, `weight_kg`, `goal`, `sports[]` |
| `GET /users/:uid/joined-activities` | `joinedByUser()` | ❌ no route (response: activity list, same shape as feed) |
| `GET /users/:uid/hosted-activities` | `hostedByUser()` | ❌ no route (same shape) |
| `GET /users/:uid/past-activities` | `pastByUser()` | ❌ no route (same shape) |

## Ratings — ❌ whole module missing

Mobile (`RemoteRatingsRepository`, base `/api`):

- `POST /activities/{activityId}/ratings`
  ```json
  {
    "sport_type": "Volleyball",
    "comment": "Great game!",
    "participant_ratings": [{ "ratee_uid": "p1", "stars": 5 }]
  }
  ```
  Expected: 2xx = accepted. Mobile reads `remoteError` on non-2xx.
  On failure mobile silently falls back to the in-memory repo.
- `GET /activities/{activityId}/my-rating` → mobile expects
  `{ "has_rated": true|false }`.

## Reports — ❌ HTTP route missing (Firestore path exists)

Backend already has `reports` collection + `reportDocPath()` in
`database/paths.ts`, but no route. Mobile (`RemoteReportRepository`):

- `POST /reports`
  ```json
  {
    "target_id": "user-or-activity-id",
    "target_type": "user",
    "reason": "Harassment",
    "details": "optional free text"
  }
  ```
  (`target_type`: `"user"` \| `"activity"`.) On any error mobile falls
  back to the dummy repo (always succeeds).

## Chat (`/api/chat`)

Backend has `POST /messages` + `GET /:activityId/messages` mounted at
`/api/chat` (i.e. `/api/chat/messages`, `/api/chat/:activityId/messages`),
but mobile calls:

| Mobile call | Status |
|---|---|
| `GET /activities/:id/messages` → list of `{id, sender_id, sender_name, sender_avatar?, text, sent_at, is_mine, image_path?, latitude?, longitude?}` | ❌ path mismatch (`/api/chat/...` ≠ `/api/activities/...`) |
| `POST /activities/:id/messages {text}` | ❌ same |
| `POST /activities/:id/messages/image` (multipart `image`) | ❌ same |
| `POST /activities/:id/messages/location {latitude, longitude}` | ❌ same |
| `GET /conversations` → list of `{id, name, …}` | ❌ no route |

**Decision needed:** either move chat routes under `/api/activities/:id/messages`
or update mobile `_base` to `/api/chat`. Former is less mobile churn.

## Notifications (`/api/notifications`)

Backend: `POST /`, `GET /:uid`, `PATCH /:uid/:notificationId/read`.
Mobile calls:

| Mobile call | Status |
|---|---|
| `GET /notifications` → list of `{id, title, body?, created_at, type: chat\|activity\|request\|moderation\|system, unread}` | ❌ no uid-less route (mobile sends no uid; backend could derive uid from token) |
| `GET /notifications/unread` | ❌ no route |
| `POST /notifications/:id/read` | ❌ method/path mismatch (backend: `PATCH /:uid/:notificationId/read`) |
| `POST /notifications/read-all` | ❌ no route |

Recommendation: uid-less routes deriving the user from `req.auth.uid`
matches the mobile contract and the token-based auth already in place.

## Calendar — ❌ whole module missing

- `GET /calendar/upcoming?days=30` → list of `{id, activity_id, title, start, end, location, synced}`
- `POST /calendar/sync` with the same object (mobile's "sync to device
  calendar" currently degrades to the local no-op).

## Auth

Handled mobile-side via Firebase REST (`signInWithPassword`, `signUp`,
`sendOobCode`) + `POST /users` for the Firestore profile — no backend
work needed, except: verify `requireAuth` protects all new routes above.

## Suggested build order for backend

1. Decide snake_case vs camelCase (blocks everything else).
2. Align `POST/GET /api/activities` + `GET /api/users/:uid` shapes.
3. Add activity member routes: `participants`, `join/leave/cancel`, `search`.
4. Add user activity lists: `joined/hosted/past-activities` + `PATCH /users/me`.
5. Add ratings module (2 endpoints) and reports route (collection exists).
6. Resolve chat mount path; add `image`/`location`/conversations.
7. Notifications uid-less routes; calendar module.

Mobile note: every remote repo already falls back to a local impl, so
remote mode degrades gracefully — but fallbacks mask 404s. Keep an eye
on `[Remote*]` debug logs when testing against a live backend.

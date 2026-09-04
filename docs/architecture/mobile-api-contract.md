# Client ↔ API Contract (gap analysis)

Generated from code inspection (mobile `main` + `mobile/use-backend-service`,
admin-web `main`, api-server `main`). Purpose: single checklist for the
backend team on what still needs building/changing before the clients can
run against the real API (`USE_REMOTE_API=true` on mobile,
`VITE_USE_MOCK_API=false` on admin-web).

## Transport

- Base URL: mobile `{Env.apiBaseUrl}/api` (`ApiClient`); admin-web
  `{VITE_API_BASE_URL}` + absolute paths below (default
  `http://localhost:4000`). neither uses a `/v1` segment today — but
  **admin-web expects every path under `/api/v1/...`** while mobile uses
  `/api/...` and the backend mounts `/api/...`. See "prefix decision".
- Auth:
  - Mobile: `Authorization: Bearer <Firebase ID token>` (injected +
    refreshed by `_AuthInterceptor`). Backend `requireAuth` verifies with
    Firebase Admin → `req.auth.uid`.
  - Admin-web: token-based session (`{token, user, expiresAt}`, 8h / 30d
    remember-me) stored in local/session storage. Real implementation
    (header injection, refresh) is still TODO in `services/api.ts` —
    currently only `Content-Type: application/json` is sent. Backend must
    define the admin auth scheme (Firebase custom claims? separate
    admin secret?) and the middleware that enforces it.
  - Admin-web currently runs on `VITE_USE_MOCK_API=true` with visible demo
    credentials (`admin@matchup.app` / `Admin@2026` in `authService.ts`).
    Remove before any production deploy.
- Envelope: admin-web expects `{ok: true, data}` /
  `{ok: false, error: {code, message, details?}}` — matches the backend's
  existing error shape. New endpoints should follow it.

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
2. Decide URL prefix: `/api/...` everywhere, or `/api/v1/...`? (Mobile
   uses the former, admin-web the latter, backend mounts the former.
   Recommendation: keep `/api/...` and update admin-web service paths —
   one-line change per service file.)
3. Decide admin auth scheme + middleware (blocks the whole admin namespace).
4. Align `POST/GET /api/activities` + `GET /api/users/:uid` shapes.
5. Add activity member routes: `participants`, `join/leave/cancel`, `search`.
6. Add user activity lists: `joined/hosted/past-activities` + `PATCH /users/me`.
7. Add ratings module (2 endpoints) and reports route (collection exists).
8. Resolve chat mount path; add `image`/`location`/conversations.
9. Notifications uid-less routes; calendar module.
10. Admin namespace (section below), in this order: auth → dashboard →
    members/activities → reports/moderation → broadcasts → analytics.

Mobile note: every remote repo already falls back to a local impl, so
remote mode degrades gracefully — but fallbacks mask 404s. Keep an eye
on `[Remote*]` debug logs when testing against a live backend.

---

## Admin web — ❌ entire `/api/v1` namespace missing

Admin-web (`apps/admin-web/src/services/`) runs fully mocked
(`VITE_USE_MOCK_API` defaults to `'true'`). Every endpoint below is
expected by real (non-mock) code paths; none exists on the backend.
Shapes are taken from the TS interfaces + dummy data the UI renders.

### Admin auth (`/api/v1/auth/admin/...`)

- `POST /api/v1/auth/admin/sign-in {email, password}` →
  `{token: string, user: AdminUser}` where
  `AdminUser = {id, name, email, role, avatarSeed}`.
  Session expiry is client-side (`expiresAt`); backend should still
  define token lifetime/validation.
- `POST /api/v1/auth/admin/sign-out` → void (fire-and-forget).
- `GET /api/v1/auth/admin/me` → `AdminUser`.

### Dashboard & moderation

- `GET /api/v1/admin/dashboard` → `DashboardData`:
  ```json
  {
    "kpis": [{"title": "", "value": "", "rawValue": 0, "change": "", "dir": "up", "sparkBars": [], "sparkColor": ""}],
    "trend": [{"day": "Mon", "activities": 0, "signups": 0}],
    "moderationQueue": [{"id": "", "reporter": "", "target": "", "targetType": "user", "reason": "", "activityTitle": "", "sport": "", "createdAt": ""}],
    "activities": [{"id": "", "name": "", "matchId": "", "sport": "", "host": "", "hostAvatarSeed": "", "participants": 0, "capacity": 0, "status": "Active", "scheduledDate": ""}]
  }
  ```
  (`MatchStatus`: `Active | Full | Completed | Flagged`.)
- `GET /api/v1/admin/moderation` → `ModerationItem[]` (same item shape).
- `POST /api/v1/admin/moderation/:id/resolve {note?}` → void.
- `POST /api/v1/admin/moderation/:id/dismiss {note?}` → void.

### Activities admin

- `GET /api/v1/admin/activities` → `AdminActivity[]`:
  `{id, name, matchId, sport, skillLevel, host, hostAvatarSeed,
  hostRating, hostGamesCount, location, addressLine?, scheduledDate
  (human-readable), startTime/endTime (e.g. "7:00 PM"), durationMinutes,
  participants, capacity, status: Active|Full|Completed|Cancelled|Flagged,
  description, isPaid, fee?, vibeTags[], distanceKm?}`.
- `PATCH /api/v1/admin/activities/:id/status {status}` → void.
- `DELETE /api/v1/admin/activities/:id` → void.

### Members admin

- `GET /api/v1/admin/members` → `Member[]`; `GET /api/v1/admin/members/:id`
  → `Member`:
  `{id, name, username, email, phone?, role: Player|Host|Moderator,
  status: Active|Inactive|Suspended|Pending, sports: [{sport, level}][],
  bio?, location?, joinedDate, activitiesJoined, activitiesHosted, rating,
  avatarSeed, dateOfBirth? (ISO), heightCm?, weightKg?, goal?}`.
  (Sports shape intentionally matches mobile `UserModel`.)
- `PATCH /api/v1/admin/members/:id/status {status}` → void.
- `DELETE /api/v1/admin/members/:id` → void.

### Reports admin

- `GET /api/v1/admin/reports` → `Report[]`:
  `{id, reporter, reporterAvatarSeed, target, targetType: user|activity,
  reason, category: Harassment|Spam|Policy Breach|Fraud|
  Inappropriate Content|Other, activityTitle, sport,
  status: Pending|Resolved|Dismissed, createdAt (ISO), adminNote?,
  resolvedAt?}`.
- `POST /api/v1/admin/reports/:id/resolve {note?}` → void.
- `POST /api/v1/admin/reports/:id/dismiss {note?}` → void.

### Broadcasts admin

- `GET /api/v1/admin/broadcasts` → `Broadcast[]`.
- `POST /api/v1/admin/broadcasts {title, message, audience, scheduledAt? (ISO)}`
  → `Broadcast` (creates; sends immediately unless `scheduledAt` set).
- `PATCH /api/v1/admin/broadcasts/:id` → `Broadcast` (update draft).
- `DELETE /api/v1/admin/broadcasts/:id` → void.

### Analytics admin

- `GET /api/v1/admin/analytics?range=7d|30d|90d` → `AnalyticsData`:
  ```json
  {
    "kpis": [{"label": "", "value": "", "change": ""}],
    "weekly": [{"day": "Mon", "signups": 0, "activities": 0, "reports": 0}],
    "topSports": [{"sport": "", "activities": 0, "pct": 0}],
    "retention": [{"label": "Week 1", "value": 100}],
    "health": [{"label": "", "value": 0, "color": ""}]
  }
  ```

## Cross-client reconciliations (decide once, implement everywhere)

1. **Report model differs per client.** Mobile submits
   `{target_id, target_type, reason, details?}` to `POST /reports`;
   admin reads a richer `Report` (reporter, category, activityTitle,
   sport, status, adminNote) from `GET /api/v1/admin/reports` and resolves
   via `.../:id/resolve|dismiss`. Define one canonical report record
   (recommendation: admin's shape, with mobile's submission mapped into
   it: `details` → reporter context, category defaulting).
2. **Moderation queue vs reports overlap.** Admin has both
   `/admin/moderation` (resolve/dismiss) and `/admin/reports`
   (resolve/dismiss) with near-identical actions but different item
   shapes. Merge into one queue or document the split (e.g. moderation =
   live triage, reports = full record).
3. **Prefix + casing** (see Transport/headline): `/api` vs `/api/v1`,
   snake_case vs camelCase. Both clients and backend must converge.
4. **Admin activity/member shapes are display-oriented** (human-readable
   dates like `"Oct 25, 2026"`, `"7:00 PM"`). Prefer ISO timestamps from
   the API and format client-side — otherwise sorting/filtering breaks.

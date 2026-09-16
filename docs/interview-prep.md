# MatchUp — Complete Project Interview Guide (COMPSCI 734)

> 15-minute 1-on-1. No internet, no AI in the room. Bring your laptop with
> this repo, `docs/architecture/`, and this file open.
> **Fluency priorities:** §1 (pitch) → §5 (decisions) → §9 (extension Q&A).
> Everything else is reference so you can answer "where is X?" precisely.

**Contents**

1. The 60-Second Pitch + Personal Contributions
2. What MatchUp Is (product, users, user journeys)
3. Monorepo Map
4. Mobile App Deep Dive (every feature + core + routing + state)
5. API Server Deep Dive (every module, middleware, database)
6. Admin Web Deep Dive
7. Firebase Security Model
8. Design Decisions — Why + Alternatives
9. End-to-End Data Flows (worked examples)
10. Testing Inventory
11. UI/UX Decisions
12. Extension Question Bank (with model answers)
13. Teamwork
14. Laptop Checklist + "Show Me" Cheat Sheet

Conventions: mobile paths are relative to `apps/mobile/`, API paths to
`apps/api-server/`, admin paths to `apps/admin-web/`.

---

## 1. The 60-Second Pitch (memorise this)

"MatchUp is an **activity-based matchmaking platform** — think Tinder-style
swiping, but for finding sports games to join or host instead of dating.
Three apps in one monorepo: a **Flutter mobile app** (our main client), a
**React + Tailwind admin dashboard** for moderation, and a **Node.js +
Express API** backed by **Firebase** (Auth, Firestore, Realtime Database,
FCM push, Storage).

Core loop: onboard → get-to-know preferences → swipe the Discover deck →
join instantly or request approval → chat with the group → track everything
in My Games. Around that we built realtime chat with typing indicators and
presence, push notifications with deep links, a first-run coach-mark tour,
reporting with suspension/appeals moderation, post-game ratings, device
calendar sync, and full dark-mode theming."

### Personal contributions (FILL IN — pick 2–3, know the files cold)

- [ ] Example: first-run tour readiness gate — `lib/features/tour/
      presentation/tour_controller.dart` (`discoveryContentReadyProvider`),
      `lib/features/discovery/presentation/discovery_screen.dart` (sets the
      gate), `tour_host.dart` (overlay mounts only when the feed is ready).
- [ ] Example: session-scoped repositories so logout/login as a different
      user can't leak the previous user's data — `lib/core/providers/
      repository_providers.dart` (`_scopeToUser`), `lib/features/activities/
      presentation/my_activities_screen.dart` (`myGamesUidProvider` watches
      the auth uid). Regression test:
      `test/providers/session_scope_test.dart`.
- [ ] Example: create-flow price UX — placeholder-only amount field plus the
      `_PriceCard` redesign (32 px amount, mode pill, focus ring) in
      `lib/features/activities/presentation/
      create_activity_screen.dart`.
- [ ] Your backend/admin-web work: name the module + endpoint + test file.

For each: **what → why → exact file → how you verified it (test/analyser).**

---

## 2. What MatchUp Is

**Product:** connects people through shared sports activities. Two roles:
**players** (discover, join, chat, rate) and **hosts** (create, approve
requests, manage roster, check-in). **Admins** (via admin-web) moderate
members, activities, reports, appeals, sports catalogue, broadcasts,
notification templates, and view analytics.

**User journeys (know these cold):**

1. **First run:** Splash (session check) → Onboarding pager (3 illustrations)
   → Welcome (collage, email sign-up; Apple/Google disabled coming-soon) →
   Register → Get-to-Know 1 (join reason) → 2 (sports + skill + distance) →
   3 (height/weight/DOB) → first-run tour on Discovery.
2. **Returning user:** Splash → biometric-or-token resume → last route
   restored (`RouteStore`) → Discovery.
3. **Discover → play:** set filters (sport/skill/date/distance) → swipe deck
   (right = keen, left = pass, tap = details) or header buttons → instant
   join (open games) → match celebration → group chat; or join request
   (approval games) → pending screen → approved/declined notification.
4. **Host:** Create wizard (setup → rules → preview) with venue
   autocomplete, cover photo, pricing (free / fixed / split-cost), draft
   autosave → publish → manage roster/requests → check-in → post-game
   ratings from participants.
5. **Moderation:** any user reports a user/activity → admin triages in
   admin-web → suspend member → member sees suspended interstitial → files
   appeal → admin approves (auto-reactivate) or rejects.
6. **Re-engagement:** FCM push (chat message, join request, approval,
   reminders, broadcasts) → tap deep-links to the exact screen.

---

## 3. Monorepo Map

```
matchup/
├── apps/
│   ├── mobile/        # Flutter (Dart 3, Material 3) — main client
│   ├── admin-web/     # React 19 + Vite + Tailwind — moderation cockpit
│   └── api-server/    # Express 5 + TypeScript — /api, Firebase Admin SDK
├── packages/
│   ├── shared-types/  # Role/Status enums, ApiSuccess/ApiFailure envelope
│   ├── shared-config/ # tsconfig/eslint/prettier bases
│   └── shared-utils/  # slugify, truncate, toIsoDate, timeAgo
├── infra/
│   ├── firebase/      # database.rules.json, firestore.indexes.json, README
│   ├── database/      # (boilerplate-era Postgres notes)
│   ├── ci/            # CI references
│   ├── perf/          # k6 auth-flow script
│   └── scripts/       # setup-secrets.sh
├── docs/              # architecture, setup, conventions, security
├── firestore.rules    # default-deny ALL clients (root)
├── storage.rules      # owner/host-scoped, type+size capped (root)
├── firebase.json / .firebaserc  # project matchup-cs734
├── run.sh             # unified dev runner (api :4000, web :5173, mobile)
└── .github/workflows/ci.yml + dependabot.yml
```

---

## 4. Mobile App Deep Dive (`apps/mobile/`)

Feature folders follow `data / domain / presentation` (with documented
exceptions: `preferences/` is presentation-only, `sports/` is data+domain,
`report/` has no domain, `auth/` uses `data/presentation/recovery`).

### 4.1 Auth (`features/auth/`)

- `data/auth_repository.dart` — `AuthRepository` contract + `AuthResult
  (accessToken, refreshToken, userId)` + `AuthException(userMessage, code)`.
  **There is no in-app OTP** — recovery is Firebase email-link based.
- `data/remote_auth_repository.dart` — Firebase REST
  (`signInWithPassword/signUp/update/sendOobCode`), parses
  `idToken/refreshToken/localId`, self-heals backend profile via idempotent
  `POST /users/me` + `PATCH displayName`, maps Firebase codes
  (`EMAIL_NOT_FOUND`, `WEAK_PASSWORD`…) to friendly messages.
- `data/auth_repository_impl.dart` — `LocalAuthRepository` stub that always
  throws `NO_BACKEND` (honest failure, never a lie).
- `presentation/splash_screen.dart` — brand animation; routes after
  `max(checkSession(), 800ms)`; `gtk_done` + `RouteStore` resume logic.
- `presentation/onboarding_screen.dart` — 3-page illustration pager.
- `presentation/welcome_screen.dart` — collage + email sign-up.
- `presentation/login_screen.dart` — email/password + biometric resume
  (`BiometricService` → `checkSession()`).
- `presentation/register_screen.dart` — on success `signIn()` +
  `gtk_done=false` → `/get-to-know-1`.
- `recovery/` — forgot-password email form → reset-link-sent screen
  (60 s resend cooldown, `NavGuard.onceFor` so the push survives process
  death).

### 4.2 Preferences / onboarding (`features/preferences/`, presentation-only)

- `get_to_know_1_screen.dart` — join reason (5 options), persisted via
  `updateProfile(joinReason:)` **before** advancing (partial progress survives).
- `get_to_know_2_screen.dart` — sports + skill (12 sports × 3 levels) +
  distance; writes backend first, then local providers.
- `get_to_know_3_screen.dart` — height/weight/DOB wheels (13+ gate, Feb-day
  clamp); `updateProfile` → `gtk_done=true` → arms `first_run` tour →
  `/discovery`.
- `preferences_screen.dart` — post-onboarding editor reusing the same
  providers; `widgets/` holds `preference_types.dart` (`SkillLevel`,
  `PricePreference`, `SportOption`) + sport grid, skill sheet, distance and
  price cards, hero summary.

### 4.3 Discovery (`features/discovery/`)

- `domain/discovery_filter.dart` — `DiscoveryFilter(sportSkills, datePreset,
  startAfter/startBefore, maxDistanceKm, includeSwiped)` with query-param
  encoding, `describe()`, JSON round-trip (**excluding** session-only
  `includeSwiped`), value equality.
- `data/remote_activity_repository.dart` — live `/api/activities`; derives
  joined/hosted/past from viewer flags (`isParticipant/isHost`); owns
  `FeedCache` (feed/detail/roster, short TTL) with `_invalidateDetails()` on
  every write; `isFeedFresh` (render instantly) / `invalidateFeed` (after
  swipe) / `strict` flag (render `ErrorRetry` instead of fail-soft).
- `data/*swipes*`, `data/public_activity_repository.dart` — `POST
  /api/swipes` (left = pass, right = join); no-auth teasers for pre-login.
- `presentation/discovery_screen.dart` — deck owner: session-lived
  `discoveryFilterProvider` + `_includeSwipedProvider` (kept alive because
  `ShellRoute` destroys Discover `State` on tab switch), `SharedPreferences`
  `discovery_filter_v1` seed/persist, cache-first `_load()` + silent
  background refresh, sets `discoveryContentReadyProvider` (tour gate).
- `presentation/filter_screen.dart` — sport/skill/date/distance editor;
  sports list from `sportsConfigProvider` with bundled fallback.
- `presentation/activity_detail_screen.dart` — outside-shell detail (no tab
  bar); `byId` + `participants`; join/request/share/report/venue map.
- `presentation/widgets/swipe_deck.dart` — 60 Hz-cheap drag deck
  (`ValueNotifier<Offset>`, 3 prebuilt cards, LIKE/NOPE stamps, spring-back).
- `presentation/widgets/discovery_card.dart` (`DiscoveryCard` hero +
  chips + spots bar), `discovery_actions.dart` (pass/detail/join),
  `venue_map_card.dart`.

### 4.4 Activities (`features/activities/`)

- `domain/activity_model.dart` — canonical entity (host, roster, joinPolicy,
  pricing); `activity_participant.dart`; `place_suggestion.dart`.
- `data/remote_places_repository.dart` — `GET /api/places` autocomplete
  proxy; offline degrades to free text. `places_ranker.dart` ranks results.
- `presentation/create_activity_screen.dart` — 3-step wizard shell
  (setup → rules → preview). `create/providers/form_data_provider.dart`
  (`ActivityFormData` immutable + Hive `wizard_draft` persistence),
  `create/providers/image_upload_provider.dart` (upload state machine),
  `create/services/form_validator.dart` (title/location/future-date/
  2–50 players/paid-price/split-min rules),
  `create/services/image_processor.dart` (compression), venue field +
  picker sheet.
- `presentation/my_activities_screen.dart` — My Games host; keepAlive
  `myGamesUidProvider` → `joined/hosted/past/pendingGamesProvider`;
  15-item pagination; mutations invalidate the relevant tab. Joined/hosted
  are **derived from the feed's viewer flags** — no dedicated backend route.
- Detail/management: `joined_activity_detail_screen.dart` (participant
  view), `activity_full_screen.dart`, `activity_participants_screen.dart`,
  `manage_activity_screen.dart` + `edit_activity_screen.dart` (host),
  `match_screen.dart` (instant-join confetti, offline fallback),
  `join_request_sent_screen.dart` + `pending_request_detail_screen.dart`
  (approval flow), `check_in_screen.dart` (QR/location),
  `past_activity_review_screen.dart` (1–5 ratings via ratings repo).

### 4.5 Chat (`features/chat/`)

- `data/chat_repository.dart` + `chat_repository_impl.dart`
  (`RemoteChatRepository`: RTDB `activityChats/{id}/messages` + 3 s HTTP
  polling fallback; `LocalChatRepository` honestly throws offline).
- `data/dm_repository.dart` (`RemoteDmRepository`, always remote):
  `dmThreadId(uidA,uidB)` sorts uids so both directions resolve identically;
  RTDB `dmChats/{thread}/messages` + `/api/dm/:uid/...`.
- `data/typing_repository.dart` (+ local/remote) — "X is typing…" via
  `/api/typing`.
- `domain/` — `chat_message.dart` (text default; `imagePath/imageUrl` =
  photo, `lat/lng` = location; backend photo travels as URL inside `text`),
  `chat_poll.dart` (single-choice), `chat_reaction.dart`
  (`messageId → emoji → uids`), `typing_record.dart`.
- `presentation/chat_screen.dart` — group chat; `StreamProvider.autoDispose.
  family` for messages/reactions/polls (auto-release RTDB subscriptions);
  composer (photo/location), mute (`muted_chats`), report, moments link.
- `presentation/dm_screen.dart`, `messages_screen.dart` (Group
  `FutureProvider` keepAlive + DM `StreamProvider` keepAlive so badges stay
  live across tabs + search), `photo_moments_screen.dart`
  (`/chat/:id/moments` album), `chat_attachment_sheet.dart`,
  `poll_create_sheet.dart` (2–6 options).

### 4.6 Notifications (`features/notifications/`)

- `data/` — notification/device/presence repositories with remote (live)
  vs local (in-memory/empty) flavours.
- `domain/app_notification.dart` (`chat/activity/system/request/
  moderation` types + `backendType`), `device_record.dart`,
  `presence_state.dart`.
- `presentation/notifications_screen.dart` (type-tinted feed, tap routing,
  unread handling), `notification_settings_screen.dart` (push toggles).
- `services/push_notification_service.dart` — FCM wrapper: permission,
  stable `push_notification_device_id` (SharedPrefs + `Random.secure`),
  backend register, `onTokenRefresh`, foreground banners, opened-app/initial
  message, `unregister + deleteToken` on logout; all fail-soft.
- `services/push_routing.dart` — pure `PushPayload` parse + `routeForPush()`
  table reused by feed taps so tray == feed.
- `services/presence_tracker.dart` — `WidgetsBindingObserver`: resumed →
  online, paused/detached/hidden → offline (skips inactive), auth-guarded.

### 4.7 Profile / ratings / report / sports / calendar / appeals

- **Profile** (`features/profile/`): `RemoteUserRepository` (`me/byId/
  updateProfile` + `_meCache`) vs local; `UserModel` (sports, skill,
  `ratingBySport`, goal…); `profile_screen.dart` (`myProfileProvider`,
  tour replay via `reset`, theme switch, sign-out with presence-offline +
  push-unregister); `edit_profile_screen.dart`; `player_profile_screen.dart`
  (by name or uid, DM entry, report).
- **Ratings** (`features/ratings/`, data+domain; UI in past-review screen):
  `POST /api/activities/{id}/ratings`, stars 1–5, aggregates to
  `ratingBySport{average,count}`.
- **Report** (`features/report/`, data+presentation): modal sheets (not
  routes — avoids double-tap `keyReservation` crash); user/activity targets;
  local impl throws offline.
- **Sports** (`features/sports/`, data+domain): `SportConfig` +
  `pickSportNames(configs, select, fallback)` so pickers never render empty
  offline; remote `GET /public/sports`, unavailable impl throws catchable
  `ApiException`.
- **Calendar** (`features/calendar/`): `RemoteCalendarRepository` derives
  from activity feed; month grid + upcoming list; optional device-calendar
  write (`CalendarService`).
- **Appeals** (`features/appeals/`): `RemoteAppealRepository` is
  **remote-only by design** (a queued appeal that never reaches triage would
  be a lie); `suspended_screen.dart` is the only screen suspended users can
  reach — keeps tokens, one-pending-appeal rule (409), "Check again" probe,
  draft in `appeal_draft`.

### 4.8 Tour (`features/tour/`)

- `domain/tour_step.dart` — `TourAnchorId` (none/swipeDeck/actionRow/
  filterButton/tabMyGames/tabCreate/tabChat/tabProfile),
  `TourSpotlightShape`, `TourStep`.
- `domain/tour_state.dart` — immutable `(steps, index, isActive)` +
  `current/isLast/progress`.
- `data/prefs_tour_store.dart` — `tour_seen_v1_{id}` in SharedPreferences.
- `presentation/tour_controller.dart` — **widget-free** `StateNotifier`
  (unit-testable): `maybeStart/start/next/skipUnavailableStep/back/skip/
  complete`, TOCTOU guard, skipped-tips disclosure; plus
  `discoveryContentReadyProvider` gate.
- `presentation/tour_steps.dart` — `kFirstRunTourId='first_run'` + final
  6-step copy; `tour_anchors.dart` — singleton `GlobalKey` registry
  (Discover keys on deck/action/filter; tab keys in `AppShell`, mounted
  once so never duplicated).
- `presentation/tour_host.dart` — lives in `AppShell.body`; owns the
  `OverlayEntry` lifecycle; shows only on `/discovery` **and** feed-ready;
  handles already-active-on-mount + tab-switch hide; missing anchor →
  auto-skip step.
- `widgets/spotlight_overlay.dart` + `spotlight_painter.dart` (scrim +
  cut-out; scrim-tap skips, hole-tap swallowed) +
  `tour_callout_card.dart` (title/body/n-of-6/Skip/Next-Done/Back, 320 px
  max, live-region semantics). Replay from Profile via `reset` + `start`.

### 4.9 Core (`lib/core/` + `lib/app/`)

- **Providers** (`core/providers/`): `auth_state_provider.dart` (session
  source of truth: `unknown/authenticated/unauthenticated/suspended`);
  `repository_providers.dart` (repo factory + `_scopeToUser` session
  scoping); `preferences_provider.dart` (sport/distance/price prefs,
  SharedPrefs-backed, corrupt-tolerant); `profile_providers.dart`
  (`myProfileProvider` autoDispose — refetch on every open).
  keepAlive = session truth (auth, repos, filters, inbox, My Games);
  autoDispose = ephemeral detail/stream (releases RTDB subscriptions).
- **Network** (`core/network/api_client.dart`): singleton Dio (`/api`,
  12 s timeouts); `AuthInterceptor` (proactive JWT-expiry refresh with
  5-min skew, single-flight 401 retry-once, 403-suspension event, dead
  session → clear + event, 60 s failure cooldown); `{ok,data} /
  {ok:false,error:{code,message}}` envelope helpers; `ApiException`
  mapping (timeouts/400/401/403/404/429/5xx + Firebase fallback);
  logging redacts tokens.
- **Storage**: `secure_token_store.dart` (Keychain/Keystore tokens + PII,
  `hasValidSession`, `clearAll`) vs `local_storage.dart` (SharedPrefs
  wrapper: route, prefs, drafts) vs `route_store.dart` (last-route resume
  with allow-list).
- **Services**: `rtdb_auth_service.dart` (`POST /users/custom-token` →
  `signInWithCustomToken` so RTDB runs as the real user; REST auth alone
  leaves the SDK anonymous), `storage_service.dart` (validated upload
  paths), `location_service.dart` (4 s GPS timeout → retry-vs-permission
  logic), `biometric_service.dart` (detailed cancel/failed result),
  `calendar_service.dart`, `session_events.dart` (broadcast decoupling
  Dio ↔ Riverpod).
- **Theme** (`core/theme/`): Figma tokens in `app_colors.dart` (light);
  `dark_colors.dart` (`DarkPalette` + `AppColorTokens` ThemeExtension +
  `context.colors` with test fallback); `theme_controller.dart`
  (persisted `theme_mode`); `app_typography.dart` (Plus Jakarta Sans,
  display vs reading line-heights); `app_spacing.dart`
  (`AppRadius/AppDurations/AppShadows`); `app/app.dart` builds light/dark
  `ThemeData` + `DefaultTextHeightBehavior` matching Figma.
- **Widgets** (`core/widgets/`, 22 files): `app_scaffold`,
  `home_header`, `app_tab_bar`, `skeleton`, `empty_state`, `error_retry`
  (calm copy, never "Oops!"), `app_snackbar` (with action),
  `pressable_scale`/`app_tappable`, `asset_image` (asset-or-URL),
  `date_picker_sheet`, `app_avatar`, `notification_icon_button`, etc.
- **Utils**: `geo.dart` (haversine), `geohash.dart`, `nav_guard.dart`
  (600 ms anti-double-push), `secure_screen.dart` (anti-screenshot on
  auth), `share_helper.dart`, `logger.dart`.
- **Routing** (`app/router.dart`, `app/app_shell.dart`): single cached
  `GoRouter`; shared slide+fade `appPage` for pushes; public paths
  (splash/onboarding/welcome/login/register/recovery); redirect order:
  persist route → unknown pins splash → suspended locks `/suspended` →
  unauthenticated gates to `/welcome` → authenticated bounces public to
  `/discovery`. `ShellRoute` hosts 5 tabs (Discover/My Games/Create/Chat/
  Profile) with hand-drawn Lucide-style painters; detail/chat/management
  screens are pushes; `/match/:id` and `/request-sent/:id` are go-only
  reveals; report flows are modal sheets, not routes.

---

## 5. API Server Deep Dive (`apps/api-server/`)

Structure: `src/modules/<feature>/{routes,controller,service}` +
`src/middleware/*` + `src/database/*`. Express 5 + helmet/cors/morgan,
1 MB JSON cap, per-IP rate limiting, zod env (refuses to boot when
invalid). 41 `*.test.ts` suites (vitest + supertest, hermetic in-memory
fakes, coverage floors 55/45). `server.ts` also runs a 5-min
`sweepExpiredActivities()` (open → completed + review nudges).

### 5.1 Endpoints by module

**Activities** (`activities/`): `POST /api/activities/` (host = caller) ·
`GET /api/activities/?status&sportType&skillLevel&limit(1–50)&offset&mine=
hosted|joined` (My Games path) + discover filters (dates, geo) ·
`PATCH /:id/status|/cover|/:id` · `GET /:id` (detail + viewer context) ·
`POST /:id/participants` (instant join) · `GET /:id/participants` ·
`DELETE /:id/participants/:uid` (leave/remove) ·
`POST /:id/join-requests` + `GET` (host lists) +
`POST /:id/join-requests/:uid/approve|decline` ·
`GET /api/activities/join-requests/me` (own outgoing; registered before
`:id` routes) · `POST /:id/check-in {lat,lng}` (membership-gated) +
`GET /:id/check-in/me` · `GET /api/public/activities` (no auth teasers).
Join policies: `open` (instant) vs `approval` (pending + host decision).
Pricing: `isPaid + fee` with `fixed | split (totalCost + minPlayers)`.

**Chat** (`chat/`, zod-validated, `canAccessActivityChat` host-or-
participant gate): `POST /api/chat/messages {activityId,text,type}` ·
`GET /api/chat/:id/messages` (history) · reactions toggle/get ·
polls create/list/vote. Archive rule: writes stop but reads continue when
cancelled/removed, completed past 7-day grace, or stale-open past end.

**DM** (`dm/`): `GET /api/dm/conversations` (newest first) ·
`GET /api/dm/:uid/thread` (canonical id) · `GET /api/dm/:uid/messages` ·
`POST /api/dm/:uid/messages` (+ notify) · `POST /api/dm/:uid/read`.

**Swipes** (`swipes/`, stored `swipes/{uid}/decisions/{activityId}`):
`POST /api/swipes/ {activityId, decision: pass|join}` (join may notify
host `activity_interest`) · `GET /api/swipes/me[/:activityId]`.

**Users** (`users/`): `POST /api/users/me` (bootstrap/upsert + welcome
notify) · `POST /api/users/custom-token` (RTDB token) · `GET /api/users/me`
· `PATCH /api/users/me` (allow-listed fields only, unknown rejected) ·
`PATCH /api/users/me/photo` · `GET /api/users/:uid/profile` (public).

**Ratings** (mounted under activities): `POST /api/activities/:id/ratings`
(participants only, after end, 7-day window; aggregates
`ratingBySport{average,count}`) · `GET .../my-rating`.

**Reports** (`reports/`): `POST /api/reports/` →
`GET /api/reports/?status&limit` (admin triage pending/resolved/dismissed)
→ `POST /:id/resolve|dismiss {note?}` (+ notify reporter).

**Appeals** (`appeals/`, sole user of `requireAuthAllowSuspended`):
`POST /api/appeals/` · `GET /api/appeals/me` (one pending per type, 409).

**Admin** (`admin/`, `requireAuth + requireAdmin` per route):
`GET /api/admin/me` (login gate) · `dashboard` (KPIs) ·
`members` list/get/`PATCH :uid/status` (suspend/reactivate)/`DELETE` ·
`activities` list/`PATCH :id/status`/`DELETE` · `sports` get/replace/
patch + public `GET /api/public/sports` · `broadcasts` CRUD +
`POST :id/send` (audience-capped fan-out) · `templates` get/patch
(`{{vars}}`, hardcoded fallback) · `analytics?range=7d|30d|90d` ·
`appeals` list + `POST :id/approve|reject` (auto-reactivate + notify).

**Devices / notifications / presence / typing / places**:
`POST|GET /api/devices/me...` (FCM registry, dead-token prune) ·
`GET /api/notifications/me` + `PATCH .../:id/read` (persist-first, then
fire-and-forget `deliverPush`; `registration-token-not-registered` prunes)
· `POST /api/presence/` + `GET /:uid` (RTDB mirror) ·
`POST /api/typing/` + `GET /:activityId/:uid` (burst-capped) ·
`GET /api/places/autocomplete` (Nominatim proxy, **no auth** for pre-login
wizard, 5-min cache, 60/min cap, `PLACES_UNAVAILABLE` on failure).

### 5.2 Middleware & envelope

- `requireAuth`: `Bearer` Firebase ID token → `verifyIdToken` →
  `req.auth={uid,token}`; suspension check (`users/{uid}.status`,
  missing = active for back-compat, lookup failure **fails open**).
  `requireAuthAllowSuspended` = verify only (appeals).
  `requireAdmin` (after `requireAuth`): `ADMIN_UIDS` env **or**
  `admins/{uid}` doc; lookup failure **fails closed**.
- Rate limits: global 1200/15 min (skips health), typing 120/min,
  autocomplete 60/min; `MemoryRateLimitStore` behind a `RateLimitStore`
  seam (Redis-ready); `RateLimit-*/Retry-After` headers, 429 envelope.
- Envelope: `{ok:true,data}` / `{ok:false,error:{code,message,details?}}`
  (`UNAUTHORIZED/FORBIDDEN/ACCOUNT_SUSPENDED/NOT_FOUND/INVALID_INPUT/
  PAYLOAD_TOO_LARGE/RATE_LIMITED/…`); unknown `/api/*` → 404 envelope
  (mobile client requires envelope, never HTML); stacks server-side only.
- Validation: pilot zod `validateBody` (chat routes) + manual
  type/trim/enum/range checks elsewhere.

### 5.3 Data layer

- **Access**: Admin SDK singletons (`auth/firestore/rtdb/messaging/
  storage`); PEM-validated private key; `paths.ts` centralises every
  collection/document/RTDB path constant.
- **Firestore**: `users/{uid}` (profile + `devices/`, `notifications/`
  subcollections) · `userEmails/{email}` unique index ·
  `activities/{id}` (+ `participants/`, `joinRequests/`, `ratings/`,
  `attendance/` subcollections) · `swipes/{uid}/decisions/` · `reports/` ·
  `appeals/` · `admins/{uid}` · `sports/` · `notificationTemplates/` ·
  `broadcasts/`.
- **RTDB**: `activityChats/{id}/messages|reactions|polls`,
  `dmChats/{a_b}/messages`, `userDMs/{uid}/{peer}` inbox,
  `typing/{activity}/{uid}`, `presence/{uid}`.
- **FCM**: multicast per-device tokens with dead-token pruning; Firestore
  record is source of truth, push is best-effort.
- **Notable service logic**: discover = single `status==open` query +
  in-memory haversine/rank (zero-composite-index policy; `+1M`
  preferred-sport score, soonest-first); lifecycle sweep dual-driven
  (interval + fire-and-forget on reads); templates render with safe
  fallback; `TtlCache` (in-flight dedup, no failure caching) fronts hot
  reads like public sports.
- **Scripts**: `seed.ts` (idempotent: 5 demo users, 6 activities incl.
  full/split/completed, swipes, notifications, RTDB chats, ratings via the
  real service, 15 sports, 13 templates) · `seed-auckland-100.ts`
  (destructive re-seed: 100 deterministic Auckland activities across 40
  venues × 9 sports) · `load-smoke.ts` (p95 latency gate).

---

## 6. Admin Web Deep Dive (`apps/admin-web/`)

React 19 + Vite + Tailwind, `react-router-dom`; **no global store** —
three contexts (`AuthContext` with TTL + cross-tab logout, `ToastContext`,
`ThemeContext`) + per-page `useReducer` with optimistic updates.

- **Routes** (all but `/login` behind `RequireAuth` + `DashboardShell`):
  `/` dashboard (KPIs, 7-day trend, moderation queue, recent activities) ·
  `/members[/:id]` (search, suspend/reactivate/delete, CSV export) ·
  `/activities[/:id]` (force status, delete; `removed⇄Flagged`,
  `Full` computed live) · `/reports` (Pending/Resolved/Dismissed/All,
  bulk actions) · `/broadcasts` (Draft/Scheduled/Sent, send-now vs
  schedule) · `/appeals` (type filter, approve/reject + note) ·
  `/sports` (flag toggles + atomic `PUT` publish) · `/analytics`
  (7d/30d/90d; retention/health empty — no backing events) ·
  `/notification-templates` (edit title/body, enable toggle).
- **API layer** (`services/api.ts`): `VITE_API_BASE_URL`, same envelope,
  `admin_id_token` (localStorage) → `Authorization` header, 401 pub/sub
  auto-logout. One service + hook + types file per domain
  (`membersService`/`useMembers`, …); `dashboardService` fans out 4 calls
  into one `DashboardData`.
- **Auth**: Firebase email/password → `GET /api/admin/me` gate (403 =
  not admin); remember-me (localStorage 30 d) vs session (8 h).

---

## 7. Firebase Security Model (high-yield for "how is it secure?")

| Layer | Rule | File |
|---|---|---|
| Firestore | **Default-deny ALL clients** (`allow read,write: if false`); every read/write via API Admin SDK | `firestore.rules` |
| RTDB reads | `auth != null` on chats/typing/presence/DM threads; `.write: false` everywhere **except** `presence/{uid}` (self-only, schema-validated) | `infra/firebase/database.rules.json` |
| Storage | Owner/host-scoped paths, image MIME + size caps (profile ≤5 MB, cover ≤8 MB, chat ≤8 MB, covers public-read) | `storage.rules` |
| API auth | Per-request `verifyIdToken`; admin = env allowlist **or** `admins/{uid}` doc; suspended blocked except appeals | `middleware/auth.middleware.ts` |
| Transport/secrets | HTTPS enforced outside local (`assertHttpsOutsideLocal`, NSC/ATS); tokens in Keychain/Keystore; secrets gitignored + CI secret-guard | `Env`, CI `security-guard` |
| Abuse | Global + burst rate limits; 1 MB JSON cap; Nominatim via server proxy (key kept server-side) | `middleware/rate-limit.ts` |

Known gaps (say honestly if asked — mapped in `docs/security/owasp-top-10.md`):
no certificate pinning, no alerting on logs, retention/health analytics empty,
per-instance (non-distributed) limiter until Redis.

---

## 8. Design Decisions — Why + Alternatives

| Decision | Why | Alternative | Trade-off |
|---|---|---|---|
| Riverpod | Compile-safe, widget-free testable logic (`TourController`), `select` rebuilds | Bloc (boilerplate), GetX (type-unsafe) | Provider-graph discipline |
| `go_router` ShellRoute | Declarative deep links (push routing), persistent tabs | Navigator 1.0 | Must survive tab-switch disposal (session-lived providers) |
| Firestore + RTDB split | Queries vs cheap websocket fan-out | All-one-store (cost/latency or query pain) | Two rule sets |
| Short-TTL feed cache + silent refresh | No HTTP+GPS replay on every tab return | No cache (jank) / infinite (stale) | Every mutation must invalidate |
| Repos scoped to auth uid | Fixed real cross-account leak (Benjamin→Lisa) | Manual invalidate per logout path (misses session-expiry) | Rebuild on uid change (cheap) |
| Tour gated on feed readiness | Fixed popup-over-skeleton | Fixed timer (flaky) | Needs readiness signal |
| Local fallback repos | Offline/demo + hermetic tests | Crash/empty offline | Dual impls; honest-throw variants where lying is worse (chat, appeals, auth) |
| Dio interceptors + SessionEvents | Single 401-refresh / 403-suspend path | Per-call handling | Interceptor complexity |
| Monorepo + shared-types | One contract, visible to all | Separate repos (drift) | Additive-only type evolution |
| FCM device roster | Per-device targeting; unregister on logout | Topics only | Lifecycle maintenance |
| TourHost owns OverlayEntry | Lifecycle vs rendering separation, testable | All-in-one overlay | More files |
| Admin React, no store | Contexts + reducers suffice for CRUD cockpit | Redux (overkill) | — |
| Zod env + fail-fast boot | Never run misconfigured | Silent defaults | — |
| Fail-open suspension lookup, fail-closed admin | Availability vs enforcement priority | Uniform policy | Documented split |
| Zero-composite-index discover | No index ops; ranking in memory | Composite indexes per filter combo | Scan cost; geo-cells future noted |

---

## 9. End-to-End Data Flows (say these step by step)

**Sign-in:** login form → `RemoteAuthRepository.signIn` (Firebase REST) →
tokens to `SecureTokenStore` → `AuthState.authenticated` → router bounces
to `/discovery` → splash-style probes (`GET /users/me`) → `RtdbAuthService`
custom-token sign-in → RTDB works as the user.

**Swipe → join:** deck drag → `onSwiped` → `POST /api/swipes` (persist) →
open policy: `POST /activities/:id/participants` → `go /match/:id`
(confetti) → group chat available; approval policy: `POST .../join-requests`
→ `/request-sent/:id` → host approves in manage screen → `activity_joined`
push → `go /match/:id`. Deck invalidates feed cache so swiped cards never
re-deal; joined cards never return even on "Start over".

**Chat message:** composer → `POST /api/chat/messages` (membership gate,
archive gate) → RTDB write under `activityChats/{id}` → participant
listeners fire (~instant) → offline clients get FCM with
`data:{type:chat_message, activityId}` → tap routes `/chat/:id`. Photos:
`StorageService` upload → URL-in-text. No-SDK environments fall back to
3 s HTTP polling.

**Suspend → appeal:** admin `PATCH members/:uid/status=suspended` →
user's next authed call 403s → `SessionEvents` → locked `/suspended`
(tokens kept) → `POST /api/appeals` (suspension-safe) → admin approves →
auto-reactivate + `appeal_approved` notification → "Check again"
(`GET /users/me` 200) returns to app.

**Push:** backend event → `createNotification` (Firestore first) →
`deliverPush` multicast (dead tokens pruned) → foreground banner with View
action / killed-state `getInitialMessage` → `routeForPush` table → exact
screen; muted chats skipped; unauthenticated taps land on `/welcome`.

---

## 10. Testing Inventory

- **Mobile (~70 suites):** provider tests (tour, session-scope logout
  regression, form draft, auth states) · integration (`discovery_feed`) ·
  ~50 widget tests (every screen: deck, wizard, tabs, chat/DM, tour,
  notifications routing, recovery, reports, dark-mode smoke) · unit
  (interceptor/refresh, envelope errors, feed cache TTL, filter codec,
  geo, push table, ranker, validator, image processor, message/poll
  parsing, appeal/suspend flows) · golden pixel tests (core widgets, chat
  headers; Flutter pinned 3.44.8 in CI; lcov lines ≥ 65%).
- **API (41 suites):** supertest route tests (auth stubbed via `req.auth`)
  + service tests over mocked Firestore/RTDB/FCM + in-memory Map RTDB;
  injectable clocks; coverage floors 55/45; `perf:smoke` p95 gate; k6
  script (5→20 VUs, p95 < 800 ms, err < 1%).
- **Admin/CI:** lint + build + `npm audit --omit=dev --audit-level=high`;
  secret-guard blocks `.env`/keys; Dependabot weekly.

---

## 11. UI/UX Decisions

Material 3 + `context.colors` tokens (zero hard-coded colors; dark palette
+ lerp-able `ThemeExtension`); skeleton-first loading everywhere; once-per-
install coach tour (replayable, back-button-safe); choice-card language
(icon+title+subtitle, tinted selection) reused for skill/entry/policy;
placeholder-only price input with snackbar validation + live split-cost
estimate; calm `ErrorRetry` copy; `EmptyState` CTAs that navigate (`→
/create`); modal sheets (not routes) for reports; honest offline states;
remote-only actions declare themselves (appeals).

---

## 12. Extension Question Bank (practise out loud)

1. **In-app payments** → new `payments` module (Stripe intent endpoint +
   webhook, `payments` collection, idempotency keys); mobile checkout sheet
   reusing the price step + `paymentStatus` on participants; admin refunds.
2. **New sport** → admin sports curation → `GET /api/public/sports`;
   mobile `pickSportNames` fallback means no forced client release.
3. **Offline create** → extend Hive draft infra with an outbox queue; sync
   on reconnect, server-wins conflicts + user notice.
4. **10k-member chat** → paginate history, cap listener scope, shard
   `messages/{activityId}`; typing/presence already burst-capped; FCM
   topics past ~10k DAU (per scalability.md runbook: replicas → Redis
   limiter → read cache → topics → re-run smoke).
5. **i18n incl. te reo Māori** → ARB + `flutter_localizations`; backend
   message keys instead of literals; locale on broadcasts.
6. **Prove logout is safe** → `session_scope_test.dart` + mechanism
   (providers watch `authState.select(userId)`); push unregister +
   presence-offline on sign-out.
7. **Refactor with more time** → one honest item (e.g. unify keepAlive
   My Games providers into one paginated provider; collapse dual repos
   behind generated fakes; composite-index discover if scan grows).

---

## 13. Teamwork (prepare 2 min, honest + specific)

- **Went well:** feature-folder ownership cut merge conflicts; API
  contracts let mobile/backend parallelise; CI + analyser kept green;
  shared design language kept UI coherent across authors.
- **Improve:** integrate against the real backend earlier (viewer-context
  bugs surfaced late); smaller stacked PRs for reviewability; keep demo
  seed accounts in sync across members.
- **Concerns:** state factually + briefly + what you did about it. No
  blame; show ownership.

---

## 14. Laptop Checklist + "Show Me" Cheat Sheet

Open: this file · `docs/architecture/overview.md` ·
`mobile-api-contract.md` · `adr-001-protocols.md` · your 2–3 contribution
files (know line numbers) · `test/providers/session_scope_test.dart`
(runnable live) · emulator running Discover → Create → My Games → Chat →
dark mode · `git log --oneline -15` (attribution).

| If asked… | Open… |
|---|---|
| Auth / session | `core/providers/auth_state_provider.ts…` → `auth_state_provider.dart`, `api: middleware/auth.middleware.ts` |
| Discover feed | mobile `discovery/.../remote_activity_repository.dart` + api `modules/activities/discover.service.ts` |
| Join / approve | mobile `discovery_screen.dart` `_joinAndShowMatch`, api `activity-participants.service.ts` |
| Chat realtime | mobile `chat/data/chat_repository_impl.dart`, api `modules/chat/`, `infra/firebase/database.rules.json` |
| Push deep link | mobile `push_routing.dart`, api `notifications.service.ts deliverPush` |
| Tour | `tour/presentation/tour_{controller,host,steps}.dart` |
| Moderation | `appeals/` both sides + `suspended_screen.dart` + admin Appeals page |
| Pricing/split | mobile `create_activity_screen.dart` `_PriceCard` + api `resolvePaidFee/resolveSplitCost` |
| Security | `firestore.rules`, `storage.rules`, `docs/security/owasp-top-10.md` |
| Tests | `test/providers/session_scope_test.dart`, `feed_cache_test`, api `discover.service.test.ts` |

Good luck — speak in files and reasons, not adjectives.

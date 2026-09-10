# Firebase setup (Realtime Database rules + client config)

Chat realtime works like this:

- **Writes always go through the backend.** The mobile app sends
  `POST /api/chat/messages`; `apps/api-server` checks
  `canAccessActivityChat` (host or participant only) and writes to
  `activityChats/{activityId}/messages/{pushId}` via the Admin SDK.
- **Reads are realtime from the client.** The chat screen subscribes
  to `activityChats/{activityId}/messages` with `firebase_database`
  (`onValue`); when Firebase isn't configured it falls back to
  HTTP polling every 3 seconds.
- **The SDK must be signed in as the real user.** The app
  authenticates via Firebase REST, so after every sign-in / session
  restore it exchanges a backend-minted custom token
  (`POST /api/users/custom-token`) via `RtdbAuthService` and calls
  `FirebaseAuth.signInWithCustomToken`. Without this step the RTDB
  listener is anonymous and gets `permission-denied`.

## 1. Publish the RTDB rules

Rules live in [`database.rules.json`](./database.rules.json). Publish
them from the Firebase console (Realtime Database → Rules) or with
the CLI:

```bash
firebase deploy --only database
```

What they enforce:

- `.read: auth != null` on `activityChats`, `typing`, `presence` —
  any signed-in user can subscribe.
- `.write: false` everywhere — clients can never write directly;
  all writes go through the backend, where membership is checked.
  (The Admin SDK bypasses rules, so backend writes are unaffected.)

Trade-off, stated openly: RTDB rules cannot query Firestore, so
read access is "any authenticated user", not "participants only".
Per-activity authorisation is enforced on every write and on the
`GET messages` history endpoint. Chat content between activity
members is low-sensitivity, so this is acceptable for this project.

## 2. Configure the mobile client (`flutterfire configure`)

Realtime chat needs the native Firebase config files, which are
**not** committed (they identify your Firebase project):

```bash
cd apps/mobile
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` plus
`android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist`, and sets the Realtime
Database URL. Without these files `Firebase.initializeApp()`
fails at startup and chat silently uses HTTP polling — messages
still send and load, but arrive up to 3 seconds late.

Also set `FIREBASE_DATABASE_URL` in `apps/api-server/.env` (see
`docs/setup/environment-variables.md`) — the backend needs it to
reach the same database.

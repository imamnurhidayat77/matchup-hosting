# Local Development Guide

This guide walks a new developer from a clean machine to all three apps running locally.

## 1. Prerequisites

| Tool       | Version  | Why                                |
| ---------- | -------- | ---------------------------------- |
| Node.js    | ≥ 20     | API + admin web                    |
| npm        | ≥ 10     | package manager                    |
| Flutter    | ≥ 3.44   | Mobile app                         |
| Git        | any      | source control                     |
| PostgreSQL | ≥ 14     | API database (optional for now)    |

macOS developers can install Postgres via Homebrew:

```bash
brew install postgresql@16
brew services start postgresql@16
createuser -s matchup
createdb -O matchup matchup
```

See [`infra/database/README.md`](../../infra/database/README.md) for the full database setup, including a Docker Compose alternative.

## 2. Clone the repository

```bash
git clone https://github.com/UOA-CS734-S2-2026/project-implementation-nimble-takahe.git
cd project-implementation-nimble-takahe
```

## 3. Configure environment variables

```bash
cp .env.example .env
```

The default values are fine for local development. Edit at minimum:

- `AUTH_SECRET` — any long random string (≥ 16 chars)
- `DATABASE_URL` — only required if you intend to run migrations locally

For per-app overrides, copy each app's `.env.example`:

```bash
cp apps/api/.env.example      apps/api/.env
cp apps/admin-web/.env.example apps/admin-web/.env
cp apps/mobile/.env.example   apps/mobile/.env
```

## 4. Install dependencies

```bash
# API
(cd apps/api && npm install)

# Admin web
(cd apps/admin-web && npm install)

# Mobile
(cd apps/mobile && flutter pub get)
```

## 5. Run the apps

### One-command option

The repo includes a helper script that starts the API and admin web together and streams their logs:

```bash
./run.sh
```

To also launch the mobile app on a connected device or emulator:

```bash
./run.sh mobile
```

Stop everything:

```bash
./run.sh stop
```

### Manual option

Open three terminals.

```bash
# Terminal A — API
cd apps/api
npm run dev
# → http://localhost:4000/health
```

```bash
# Terminal B — admin web
cd apps/admin-web
npm run dev
# → http://localhost:5173
```

```bash
# Terminal C — mobile (requires an emulator or connected device)
cd apps/mobile
flutter run
```

## 6. Verify the setup

- API health: `curl http://localhost:4000/health` should return `{"ok":true,"data":{"status":"ok","service":"matchup-api"}}`.
- Admin web: open http://localhost:5173 — the dashboard shell should render with a "Discover" sidebar (placeholder pages).
- Mobile: the Flutter app should launch in your emulator with the bottom navigation shell.

## Common issues

### `flutter: command not found`

Install Flutter following the official guide: https://docs.flutter.dev/get-started/install.

### `npm install` fails with ERESOLVE on the API

The API is currently using `--legacy-peer-deps` for a peer-dependency mismatch between `@eslint/js` and `@typescript-eslint/*`. Use:

```bash
cd apps/api && npm install --legacy-peer-deps
```

### Port 4000 or 5173 already in use

Override `PORT` in `apps/api/.env` or pass `--port` to Vite:

```bash
cd apps/admin-web && npm run dev -- --port 5174
```

### API starts but `/health` reports `Offline`

The admin web dashboard calls `/health` via the browser. If you see "Offline", check that the API is running and that `VITE_API_BASE_URL` matches the API's actual port.

## Next steps

- Read [`docs/conventions/coding-standards.md`](../conventions/coding-standards.md)
- Read [`docs/architecture/overview.md`](../architecture/overview.md)
- Pick an MVP feature and create a feature branch: `git checkout -b feature/<name>`
# Environment Variables

All environment variables used across the MatchUp apps, grouped by app.

## Root `.env.example`

The root file at `.env.example` is the canonical reference. Per-app `.env.example` files document only the variables that app actually consumes.

### API (`apps/api`)

| Variable        | Required | Default                  | Description                                                                |
| --------------- | -------- | ------------------------ | -------------------------------------------------------------------------- |
| `PORT`          | no       | `4000`                   | Port the Express server listens on.                                        |
| `DATABASE_URL`  | yes      | —                        | PostgreSQL connection string. Format: `postgres://USER:PASS@HOST:PORT/DB`. |
| `CORS_ORIGIN`   | no       | `http://localhost:5173`  | Comma-separated list of allowed origins for browser requests.              |
| `NODE_ENV`      | no       | `development`            | One of `development`, `test`, `production`.                                |
| `LOG_LEVEL`     | no       | `info`                   | One of `trace`, `debug`, `info`, `warn`, `error`, `fatal`.                  |

### Admin web (`apps/admin-web`)

| Variable             | Required | Default                 | Description                                                       |
| -------------------- | -------- | ----------------------- | ----------------------------------------------------------------- |
| `VITE_API_BASE_URL`  | no       | `http://localhost:4000` | Base URL the admin web uses when calling the API.                 |

### Mobile (`apps/mobile`)

| Variable        | Required | Default                 | Description                                                       |
| --------------- | -------- | ----------------------- | ----------------------------------------------------------------- |
| `API_BASE_URL`  | no       | `http://localhost:4000` | Base URL the Flutter app uses when calling the API.               |
| `APP_ENV`       | no       | `local`                 | Environment label, useful for analytics / feature flags.          |

## How variables are loaded

- **API** — `dotenv` reads `apps/api/.env` (or the root `.env`) at boot. Validation is performed in `src/config/env.ts` using Zod; the process exits with a clear error if any required variable is missing.
- **Admin web** — Vite injects variables prefixed with `VITE_` at build time. They are accessed via `import.meta.env.VITE_*`.
- **Mobile** — `flutter_dotenv` loads `apps/mobile/.env` at startup. The `Env` class in `lib/core/config/env.dart` exposes typed accessors.

## Environments

The repo assumes three deployment environments:

- `local` — developer laptops
- `staging` — pre-production
- `production` — live users

For the boilerplate phase, only `local` is exercised. `staging` and `production` configuration will be added with the deployment plan in the MVP phase.
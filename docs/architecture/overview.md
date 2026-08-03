# Architecture Overview

MatchUp is a single-repository monorepo containing three applications that share typed contracts via local `packages/`.

## Applications

```
┌─────────────────────────────────────────────────────────┐
│                         Clients                          │
├──────────────────────────┬──────────────────────────────┤
│   Mobile (Flutter)       │   Admin web (React + Tailwind)│
│   apps/mobile            │   apps/admin-web               │
└────────────┬─────────────┴────────────┬──────────────────┘
             │ HTTPS (REST/JSON)        │
             ▼                          ▼
┌─────────────────────────────────────────────────────────┐
│             API (Node.js + Express + TypeScript)         │
│                       apps/api                          │
└────────────┬─────────────────────────────────────────────┘
             │ pg
             ▼
┌─────────────────────────────────────────────────────────┐
│                  PostgreSQL database                     │
└─────────────────────────────────────────────────────────┘
```

### Mobile (`apps/mobile`)

- **Framework:** Flutter (Dart 3, Material 3).
- **State:** `flutter_riverpod` (placeholder; can be replaced).
- **Routing:** `go_router` with a bottom-nav shell.
- **HTTP:** `dio` configured with `API_BASE_URL`.
- **Local storage:** `shared_preferences` wrapped in `LocalStorage`.

### Admin web (`apps/admin-web`)

- **Framework:** React 19 + Vite 5.
- **Routing:** `react-router-dom` v6.
- **Styling:** Tailwind CSS 3 with a small set of design tokens defined in `tailwind.config.js` and `src/styles/index.css`.
- **HTTP:** native `fetch` wrapped in `services/api.ts`.
- **Forms / validation:** planned for the MVP phase.

### API (`apps/api`)

- **Runtime:** Node.js 20+, TypeScript 5.6.
- **Framework:** Express 4 with `helmet`, `cors`, `morgan` middleware.
- **Validation:** `zod` for env config; per-route validation added in MVP.
- **Database:** `pg` driver against PostgreSQL. Migrations via the in-tree runner in `src/database/migrate.ts`.
- **Logging:** `pino` (pretty-printed in development).
- **Auth:** placeholder middleware in `src/middleware/auth.ts` — real auth arrives in MVP.

## Shared packages

```
packages/
├── shared-types/    # enums, DTOs, common response types
├── shared-config/   # prettier / tsconfig / eslint base
└── shared-utils/    # small reusable helpers (string, date)
```

Apps import from these packages via relative paths. If the project later moves to a real workspace tool (npm workspaces, pnpm), the relative paths can be replaced with bare specifiers without changing the public surface.

## Boundary rules

- **Clients never talk to the database directly.** All persistence is through API endpoints.
- **The API never trusts client-asserted identities.** Auth middleware will validate signed tokens (MVP phase).
- **Shared types are additive.** Removing or renaming a type requires a coordinated change in every consumer; prefer adding new types and deprecating old ones.

## What is intentionally NOT here yet

The **boilerplate phase is complete**. The following are in place:

- Single-repo structure with `apps/`, `packages/`, `infra/`, and `docs/`
- Local development environment for mobile, admin web, and API
- Health endpoint and modular route skeleton in the API
- PostgreSQL connection and migration runner baseline
- Shared config, shared types, and shared utils packages
- ESLint / Prettier for TypeScript apps and `flutter analyze` for mobile
- GitHub Actions CI running install → lint → test → build for each app
- Onboarding docs: README, local development guide, environment variables, coding standards

The following still land in the MVP implementation phase — see the recommendation in [`docs/initial-plan.md`](../initial-plan.md):

- Real authentication
- Activity discovery / matchmaking
- Reporting & moderation
- Push notifications, chat, analytics
- Production schema design (only `000_init.sql` baseline exists)
- Deploy scripts / production CI
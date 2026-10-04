# MatchUp — Database Setup (retired)

> **This PostgreSQL setup is retired and no longer used.** The project moved
> off PostgreSQL/Prisma during the MVP phase. There is no `DATABASE_URL`,
> no Prisma schema, and no `npm run migrate` — do not install Postgres for
> this repo.

## Current data plane: Firebase (project `matchup-cs734`)

| Store | Used for |
|-------|----------|
| Firestore | profiles, activities, swipes, reports, moderation (`apps/api-server` via Admin SDK) |
| Realtime Database | chat messages, typing indicators, presence (authorised writes via API, realtime reads from clients) |
| Storage | avatars, activity covers, chat attachments, report evidence |
| FCM | per-device push with dead-token pruning |

Rules live in [`firestore.rules`](../../firestore.rules),
[`storage.rules`](../../storage.rules) and
[`infra/firebase/database.rules.json`](../firebase/database.rules.json).

## Setup

No local database to install. Configure Firebase credentials instead:

1. Create a service account (Firebase Console → Project settings → Service accounts).
2. Put its fields into `apps/api-server/.env` (see `apps/api-server/.env.example`).
3. Start the API and verify: `curl http://localhost:4000/api/health` should
   report `"database":"connected"`.

Client config, RTDB rules publishing and the offline/polling fallback are
documented in [`infra/firebase/README.md`](../firebase/README.md). The
checked-in Firestore index is
[`infra/firebase/firestore.indexes.json`](../firebase/firestore.indexes.json).

## History

This folder previously held PostgreSQL/Homebrew/Docker/Prisma notes from the
boilerplate phase (see [`docs/initial-plan.md`](../../docs/initial-plan.md)).
It is kept as a pointer so old links don't rot.

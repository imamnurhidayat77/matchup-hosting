# MatchUp

> Activity-based matchmaking platform for connecting people through shared interests.

This repository contains the **source code** for the MatchUp platform — mobile app (Flutter), admin web (React + Tailwind), and backend API (Node.js + Express + TypeScript), backed by PostgreSQL. It is the team project for **COMPSCI 734 — Mobile, Web & Enterprise Computing** (Semester 2, 2026).

## Team — Nimble Takahe

- Aidil Muslim (`amus790`)
- Manu R (`msri874`)
- Armanda Darmara (`adar521`)
- Imam Nurhidayat (`inur448`)


## Repository Structure

```
matchup/
├── apps/
│   ├── mobile/                  # Flutter mobile app
│   ├── admin-web/               # React + Tailwind admin dashboard
│   └── api/                     # Node.js + Express backend
├── packages/
│   ├── shared-types/            # shared enums, DTO placeholders, constants
│   ├── shared-config/           # eslint, prettier, tsconfig, conventions
│   └── shared-utils/            # common helpers
├── infra/
│   ├── database/                # local Postgres setup notes
│   └── ci/                      # CI references
├── docs/
│   ├── architecture/            # high-level architecture docs
│   ├── setup/                   # local development guides
│   ├── conventions/             # coding & folder conventions
│   └── initial-plan.md          # boilerplate plan
├── .github/workflows/           # CI workflows
├── .env.example                 # root environment variables
├── run.sh                       # unified local development runner
└── README.md
```

## Installation

### 1. Prerequisites

| Tool        | Version   | Purpose                         |
|-------------|-----------|---------------------------------|
| Node.js     | ≥ 20      | API + admin web runtime         |
| npm         | ≥ 10      | Node package manager            |
| Flutter     | ≥ 3.44    | Mobile app                      |
| Dart        | ≥ 3.12    | Bundled with Flutter            |
| Git         | any       | Version control                 |
| PostgreSQL  | ≥ 14      | API database                    |

Install Flutter from the [official guide](https://docs.flutter.dev/get-started/install).

#### macOS

Use Homebrew:

```bash
brew install node postgresql@16 git
```

#### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y nodejs npm postgresql postgresql-contrib git
```

Start PostgreSQL:

```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### Windows

1. Download and install [Node.js LTS](https://nodejs.org/)
2. Download and install [Git for Windows](https://git-scm.com/download/win)
3. Install PostgreSQL with [the official installer](https://www.postgresql.org/download/windows/) or via [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/):

   ```powershell
   winget install PostgreSQL.PostgreSQL.16
   ```

4. Install Flutter by following the [Windows install guide](https://docs.flutter.dev/get-started/install/windows)

> **Note:** `run.sh` is a Bash script. On Windows use Git Bash, WSL, or run the commands from the script manually in separate PowerShell terminals.

### 2. Clone the repository

```bash
git clone https://github.com/UOA-CS734-S2-2026/project-implementation-nimble-takahe.git
cd project-implementation-nimble-takahe
```

### 3. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and set at minimum:

- `AUTH_SECRET` — any long random string (≥ 16 characters)
- `DATABASE_URL` — your PostgreSQL connection string

Default for local PostgreSQL with the `postgres` user:

```env
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/matchup
```

Per-app overrides can also be set by copying each app's `.env.example`:

```bash
cp apps/api/.env.example apps/api/.env
cp apps/admin-web/.env.example apps/admin-web/.env
cp apps/mobile/.env.example apps/mobile/.env
```

### 4. Install dependencies

```bash
# API
(cd apps/api && npm install --legacy-peer-deps)

# Admin web
(cd apps/admin-web && npm install --legacy-peer-deps)

# Mobile
(cd apps/mobile && flutter pub get)
```

> **Note:** The API currently requires `--legacy-peer-deps` due to a peer-dependency mismatch between ESLint packages.

### 5. Set up the database

Make sure PostgreSQL is running and the `matchup` database exists.

#### macOS

```bash
brew services start postgresql@16
psql postgres -c "CREATE DATABASE matchup;"
```

#### Ubuntu / Debian

```bash
sudo systemctl start postgresql
sudo -u postgres psql -c "CREATE DATABASE matchup;"
```

#### Windows

Start the PostgreSQL service from Services (`services.msc`) or PowerShell (admin):

```powershell
Start-Service postgresql-x64-16
```

Then create the database with pgAdmin or psql:

```bash
psql -U postgres -c "CREATE DATABASE matchup;"
```

#### Apply migrations

```bash
cd apps/api
npm run migrate
```

Generate the Prisma Client:

```bash
npx prisma generate
```

### 6. Run the apps

The easiest way is the provided helper script (works on macOS, Ubuntu, WSL, and Git Bash):

```bash
./run.sh
```

This starts the API and admin web in the background and streams their logs. To also launch the mobile app when an Android/iOS device or emulator is available:

```bash
./run.sh mobile
```

To stop everything:

```bash
./run.sh stop
```

Alternatively, run each app in its own terminal:

```bash
# Terminal A — API
cd apps/api && npm run dev
# → http://localhost:4000/health

# Terminal B — admin web
cd apps/admin-web && npm run dev
# → http://localhost:5173

# Terminal C — mobile (requires emulator or device)
cd apps/mobile && flutter run
```

### 7. Verify the setup

- API: `curl http://localhost:4000/health` should return `{"ok":true,"data":{"status":"ok","service":"matchup-api","database":"connected"}}`
- Admin web: open http://localhost:5173
- Mobile: launches in your emulator/device

## Common issues

### `flutter: command not found`

Make sure Flutter is installed and on your `PATH`. Verify with:

```bash
flutter doctor
```

### `npm install` fails with ERESOLVE on the API

Use `--legacy-peer-deps`:

```bash
cd apps/api && npm install --legacy-peer-deps
```

### Port 4000 or 5173 already in use

Stop any running services:

```bash
./run.sh stop
```

Or override ports in `apps/api/.env` and `apps/admin-web/.env`.

### API health returns `DB_UNAVAILABLE`

Check that PostgreSQL is running and that `DATABASE_URL` points to a valid database with the correct credentials.


## Scripts by App

| App              | Dev                | Build              | Lint / Analyze              |
|------------------|--------------------|--------------------|-----------------------------|
| `apps/api`       | `npm run dev`      | `npm run build`    | `npm run lint`              |
| `apps/admin-web` | `npm run dev`      | `npm run build`    | `npm run lint`              |
| `apps/mobile`    | `flutter run`      | `flutter build`    | `flutter analyze`           |

### Useful Prisma commands

```bash
cd apps/api
npm run migrate          # apply pending migrations
npx prisma migrate dev   # create a new migration from schema changes
npx prisma generate      # regenerate Prisma Client
npx prisma studio        # open Prisma Studio
```

## Documentation

- [Boilerplate plan](docs/initial-plan.md) — what this phase delivers
- [Local development guide](docs/setup/local-development.md)
- [Environment variables](docs/setup/environment-variables.md)
- [Database setup](infra/database/README.md)
- [Coding standards](docs/conventions/coding-standards.md)
- [Architecture overview](docs/architecture/overview.md)


# SoTreina

Personal fitness hub aggregating multiple training domains into a single analytics platform: **running** (synced from Strava, with stream reconstruction, workout classification and a manual lap editor), **strength training** (exercise library, saved routines, live workout logging) and **diet** (food database, barcode scanning, configurable meals, daily macro goals). Every entity carries a `userId` from day one, so cross-domain correlation is possible as the hub grows.

> **Status:** Live in production at [sotreina.vercel.app](https://sotreina.vercel.app) (custom domain `sotreina.com` migration in progress). All three modules — Run, Gym and Diet — are deployed and in use. Login works via email/password **or** Strava OAuth, with Strava as an optional connection rather than the only way in. Mobile-responsive layout, pt/en i18n and light/dark/auto theming apply across the whole app. `Run > Analysis` is temporarily hidden behind a nav flag while it's being tuned. The legacy Python pipeline is retained as a numerical validation oracle.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Environment Variables](#environment-variables)
  - [Running the App](#running-the-app)
- [Deployment](#deployment)
- [API Endpoints](#api-endpoints)
- [Data Model](#data-model)
- [Testing](#testing)
- [Tooling & Conventions](#tooling--conventions)
- [Known Limitations](#known-limitations)
- [Roadmap](#roadmap)

---

## Overview

A NestJS + PostgreSQL backend exposes a REST API consumed by a React SPA. The app started as a running-analytics tool on top of the Strava API and has since grown into a three-module hub, with a shared session/auth layer, shared design tokens and a shared navigation shell.

### Authentication & accounts

- **Two ways in, one account model:** email/password (`POST /auth/register` / `/auth/login`, argon2 hashing) or Strava OAuth (`GET /strava/auth`, find-or-create on `stravaAthleteId` — Strava never returns an email).
- **Strava is an optional connection:** a user who signed up with email/password can link Strava later (`GET /strava/connect`) or unlink it (`DELETE /strava/connect`, which deletes only the `StravaAccount`, never the user or their data). A single OAuth callback decides login vs. connection by checking for a live session.
- **Session:** JWT in an httpOnly cookie (`sameSite: 'lax'`), custom `AuthGuard` (no Passport). `User.tokenVersion` is compared against the cookie on every request, so logout invalidates every session on every device.
- **Password recovery:** `POST /auth/forgot-password` / `/auth/reset-password` with a 32-byte random token (only its SHA-256 hash is stored, 30-minute TTL), delivered by transactional email via Resend. The endpoint always answers `{ok:true}` regardless of whether the email exists — anti-enumeration.
- **Rate limiting:** 100 req/min per IP globally, tighter caps on the pre-auth endpoints (5/min on register/login/reset), and a custom 10 req/min **per account** bucket shared by every route that calls the Strava API — Strava's rate limit is app-wide, so one account hammering it would starve everyone else.

### Running (Strava)

- Incremental activity sync via cron (every 6h, iterating all connected accounts sequentially) plus an on-demand trigger, with live progress polling (state, phase, counters, ETA and a rate-limit countdown).
- An adaptive throttle (`StravaClientService`) that reads Strava's `X-RateLimit-*`/`X-ReadRateLimit-*` headers and sleeps ahead of the 15-minute window reset instead of taking 429s.
- Second-by-second stream reconstruction through a multi-stage TypeScript pipeline (interpolation, rolling average, HR smoothing/EWM, elevation smoothing, grade, pace, cadence) — persisted for INTERVAL/HILL activities without recorded laps, and served on demand (in-memory cache) for the lap editor.
- Workout classification (easy/long, interval, hill repeats) and automatic lap detection, alongside native Strava laps, with per-lap net elevation gain, max HR and cadence.
- **Manual lap editor:** rebuild an activity's laps (add / split / delete / resize / drag-to-reorder) without re-syncing, resolved by a single sequential scan of the stream from second 0 — the same algorithm mirrored client-side for the live coverage bar.
- Gear tracking (shoes), best-effort PRs (top 3 per distance, always derived — never materialized) and real Strava HR zones (athlete-level and per-activity, premium-gated) with historical backfills.
- Frontend: a dashboard (list + detail with Leaflet route map), a Run Overview page (all-time totals, calendar, personal records, shoes) and a Run Analysis page with 9 client-side charts sourced from **per-lap** data — weekly volume, pace × volume, Z2 vs. above-Z2, pace-zone histogram, training load, ACWR, monotony & strain, Efficiency Factor and cardiac drift.

### Strength training (Gym)

- **Shared exercise library:** 873 seeded exercises from the public-domain [`yuhonas/free-exercise-db`](https://github.com/yuhonas/free-exercise-db) (visible to everyone) plus per-user custom exercises (visible only to their creator), filterable by muscle group and equipment. Portuguese names/instructions ship as statically generated, committed data — no runtime translation API.
- **Saved routines** (`WorkoutTemplate`): structure and targets only (`targetSets`, `targetRepsMin`/`Max`) — never actual weights. Deleting a routine never deletes history (`Workout.templateId` is `ON DELETE SET NULL`, pinned by a test that reads the generated `migration.sql`).
- **Live workout session:** starting a workout is idempotent (an open workout is resumed, never duplicated); a routine seeds the exercise list, and sets are logged live. Every mutation returns the full `WorkoutDetail`, so the client never needs a follow-up GET. Per-set "last time" suggestions come from the previous finished workout, set by set.
- **Rest timer:** entirely client-side, computed from an absolute `endsAt` timestamp (no drift when the tab is backgrounded), persisted to `localStorage` so it survives a refresh, with a Web Audio beep primed on a synchronous user gesture.
- **History & records:** weekly volume bars, workout drill-down down to individual sets, estimated 1RM (Epley) and a per-exercise personal record lookup. `GET /workouts/:id/template-drift` reports whether a finished session diverged from its routine, so the user can be offered a "sync the routine" step.

### Diet

- **Food database from three sources:** the Brazilian TACO table (597 foods, committed as a CSV snapshot and seeded idempotently), Open Food Facts (looked up by barcode, cached locally on first hit, never used for search-as-you-type) and per-user custom foods. `Food` rows are always stored per 100 g, with sodium always normalized to mg regardless of source.
- **Barcode scanner:** `html5-qrcode` restricted to product barcode formats, lazy-loaded so its ~416 kB chunk only downloads when the camera is opened. On iOS — where every browser is WebKit and the native Barcode Detection API doesn't exist — a ZXing-C++/WASM ponyfill is registered as `window.BarcodeDetector`, served from our own domain to stay inside the CSP.
- **Configurable meals:** the day's meals are per-user configuration (not rebuilt daily) — renameable, reorderable, and repeatable (two meals can both be named "Lanche", which is exactly why `FoodLog` points at a `mealId` instead of carrying an enum). Five defaults are seeded lazily on first read, under an advisory lock.
- **Household measures:** foods can carry a `servingLabel`/`servingGrams` pair ("1 unidade" = 50 g), so quantities can be entered as units or grams — but `FoodLog.quantity` is *always* stored in grams, with `enteredAsServing` acting purely as a display hint that never enters a calculation.
- **Saved meals:** a named group of foods that can be applied to any meal in one action, creating all its `FoodLog` rows at once.
- **Goals & history:** daily kcal/protein/carbs/fat targets with a progress ring and macro bars, plus a 7/14-day history chart zero-filled server-side via `generate_series`, so the client never has to reconcile a sparse result against the requested range.

### Cross-cutting

- **Mobile-responsive layout** below the `md` breakpoint (fixed app bar + drawer navigation, mobile-specific views, safe-area insets), **pt/en i18n** (`react-i18next`, browser-language default, per-feature namespaces, with the backend honoring `Accept-Language` for exercise content) and a **light/dark/auto theme** applied pre-paint by an inline script.
- **Onboarding:** a first-login gate renders a skeleton shell with a 3-state sync card (intro / syncing / done) until the initial Strava import finishes — skipped entirely for users without a Strava connection.
- **Optimized boot** (`client/src/lib/boot.ts`): for a returning user, `/auth/me`, the activity-history check, the activities prefetch and the active page's chunk all start in parallel during bundle evaluation.
- **Legacy Python pipeline** retained as a numerical oracle to validate every ported statistical algorithm (ACWR, monotony, strain, …).

---

## Architecture

```
┌────────────────────────────────┐        ┌──────────────────────────────────────────────────┐
│        React SPA (Vite)        │  REST  │                  NestJS Server                   │
│                                │◄──────►│                                                  │
│  auth · onboarding · nav       │  JSON  │  auth/ (session, guards)  │  email/ (Resend)     │
│  ─ Run ─────────────────────   │  cookie│  strava/auth · connect · webhook                 │
│  dashboard · overview          │        │  strava/sync (cron + trigger, multi-account)     │
│  analysis (9 charts)           │        │  strava/best-efforts · strava/hr-zones           │
│  activity detail · lap editor  │        │  activities/ · activities/lap-editor/            │
│  ─ Gym ─────────────────────   │        │  gear/ · personal-bests/                         │
│  overview · routines · history │        │  exercises/ · workouts/ · workout-templates/     │
│  live session · rest timer     │        │  foods/ · food-logs/ · meals/ · saved-meals/     │
│  ─ Diet ────────────────────   │        │  users/ · common/ (locale) · throttler guards    │
│  overview · add meal · scanner │        │                                                  │
│  goals · history · saved meals │        ├──────────────────────────────────────────────────┤
│                                │        │                   Prisma 7 ORM                   │
│  Tailwind + shadcn/ui · i18n   │        │                (@prisma/adapter-pg)              │
└────────────────────────────────┘        └────────────────────────┬─────────────────────────┘
                                                                   │
                                                                   ▼
                                                             PostgreSQL 17
                                                     (Docker locally / Neon in prod)
```

In production, the browser only ever talks to the Vercel-hosted frontend: `client/vercel.json` proxies `/api/*` to the Render-hosted backend (`rewrites`, not `redirects`), so the session cookie is perceived as first-party and survives Safari's third-party cookie blocking. See [Deployment](#deployment).

**Stack:**

| Layer | Technology |
|---|---|
| Runtime | Node.js (via nvm) |
| Backend framework | NestJS |
| ORM | Prisma 7 (`@prisma/adapter-pg`) |
| Database | PostgreSQL 17 (Docker locally, Neon in production) |
| Auth | JWT (`@nestjs/jwt`) in an httpOnly cookie + argon2 password hashing, custom `AuthGuard` (no Passport) |
| Transactional email | Resend (welcome + password reset, best-effort — never throws) |
| Rate limiting | `@nestjs/throttler` (per-IP global guard + a custom per-account `CanActivate` reusing its storage) |
| Scheduler | `@nestjs/schedule` (cron) |
| Hardening | `helmet` on the backend, CSP + security headers on the frontend |
| Backend tests | Vitest |
| Frontend framework | React 19 + Vite |
| Frontend tests | Vitest (pure functions/hooks, no jsdom yet) |
| Styling | Tailwind CSS 4, shadcn/ui (Radix primitives), Geist Variable font |
| i18n | react-i18next (pt/en, per-feature namespaces) + `Accept-Language` on the backend |
| Maps | Leaflet + OpenStreetMap raster tiles |
| Barcode scanning | `html5-qrcode` + `barcode-detector`/`zxing-wasm` ponyfill (iOS/WebKit) |
| Charts | Hand-rolled SVG (Catmull-Rom → bézier smoothing), no charting library |
| Date handling | date-fns |
| Frontend lint/format | ESLint, Prettier |
| Commit tooling | Commitizen + Commitlint (Conventional Commits) via Husky hooks |
| External data | Strava API, Open Food Facts, TACO (committed CSV snapshot), `yuhonas/free-exercise-db` |
| Legacy pipeline | Python, pandas, SQLAlchemy, SQLite (validation oracle only) |
| Hosting | Render (backend, free tier), Neon (Postgres, free tier), Vercel (frontend) |
| Environment | WSL2 + Ubuntu |

---

## Project Structure

```
strava_dashboard/
├── python-pipeline/                # Legacy Python pipeline (pandas, SQLAlchemy, SQLite)
│                                   # Retained as numerical oracle for validating TS ports
│
├── server/                         # NestJS application
│   ├── prisma/
│   │   ├── schema.prisma           # Data model (running + gym + diet)
│   │   ├── migrations/             # Migration history
│   │   ├── seed-data/              # Committed source data: exercises.json, exercises.pt.json,
│   │   │                           # taco_composicao.csv, taco_servings.json
│   │   ├── seed-gym.ts             # 873 exercises, idempotent upsert by slug
│   │   ├── seed-gym-translations.ts# PT name/instructions backfill (never creates rows)
│   │   ├── seed-taco.ts            # 597 TACO foods, upsert by [source, externalId]
│   │   └── seed-taco-servings.ts   # Household-measure overlay (272 curated items)
│   ├── src/
│   │   ├── app.module.ts
│   │   ├── auth/                   # SessionService (JWT+cookie), AuthGuard, @CurrentUser(),
│   │   │                           # account throttler guard, email/password + password reset
│   │   ├── email/                  # EmailService (Resend) + pure templates/
│   │   ├── common/                 # lang.ts + @CurrentLang() — Accept-Language threading
│   │   ├── activities/             # GET /activities, /:id, /laps, /hr-zones, /weekly-distance
│   │   │   └── lap-editor/         # ActivityStreamsService + LapEditorService
│   │   ├── gear/                   # GET /gear, /:id/activities
│   │   ├── personal-bests/         # GET /personal-bests, /history
│   │   ├── users/                  # GET/PATCH /users/me (maxHr + daily diet goals)
│   │   ├── exercises/              # Shared exercise library (seed + user-custom)
│   │   ├── workouts/               # Live workout capture (workout → exercises → sets)
│   │   ├── workout-templates/      # Saved routines (structure + targets only)
│   │   ├── foods/                  # Food library: local search, custom foods,
│   │   │                           # barcode lookup + Open Food Facts client
│   │   ├── food-logs/              # Daily log, summary, 7/14-day zero-filled history
│   │   ├── meals/                  # Per-user configurable meals (lazy defaults, reorder)
│   │   ├── saved-meals/            # Named food groups, appliable to any meal in one action
│   │   └── strava/
│   │       ├── auth/               # OAuth redirect + callback (login OR connect), connect/disconnect
│   │       ├── webhook/            # Subscription challenge + deauthorization handler
│   │       ├── best-efforts/       # Historical backfill, decoupled from main sync
│   │       ├── hr-zones/           # Athlete-zone sync + per-activity backfill
│   │       └── sync/               # strava-sync.service (orchestration, multi-account),
│   │           │                   # strava-client (adaptive rate-limit throttle), types
│   │           ├── detectors/      # base, interval, hill, lap-classifier, workout-classifier
│   │           └── processors/     # streams-processor, lap-mapper, best-effort-mapper,
│   │                               # gear-mapper, hr-zone-mapper, lap-stats-calculator
│   ├── test/                       # Vitest unit + integration tests (per module)
│   └── .env                        # Strava + DB + JWT + Resend credentials (not committed)
│
└── client/                         # Vite + React SPA
    ├── vercel.json                 # /api/:path* → Render rewrite (session-cookie proxy),
    │                               # /redefinir-senha → /index.html, CSP + security headers
    ├── src/
    │   ├── App.tsx                 # Reset-password / login / onboarding gates, nav shell,
    │   │                           # state-based routing (no react-router)
    │   ├── lib/                    # Framework-free helpers (api.ts, boot.ts, activityFormat,
    │   │                           # polyline, chartPath, dateLocale, useActivities, API types)
    │   ├── i18n/                   # react-i18next setup, per-feature locale namespaces (pt/en)
    │   ├── components/             # Reusable generic UI (SegmentedControl, PasswordInput, shadcn/ui)
    │   └── features/
    │       ├── auth/               # AuthContext, LoginPage (email/password + Strava + forgot),
    │       │                       # ResetPasswordPage (standalone, outside AuthContext)
    │       ├── onboarding/         # FirstSyncPage (first-login import gate)
    │       ├── nav/                # Sidebar, MobileChrome (app bar + drawer), navConfig.ts
    │       ├── profile/            # ProfilePage (account, Strava connection, add password,
    │       │                       # units, theme, language, logout)
    │       ├── dashboard/          # Dashboard, Rail, ActivityList, WeeklyChart, DateRangePicker,
    │       │                       # SyncPanel, MobileWeeklySummary, bins.ts
    │       ├── overview/           # RunOverviewPage, RunCalendar, PersonalRecordsCard, ShoesSection
    │       ├── analysis/           # RunAnalysisPage (9 charts), useTrainingMetrics, useMaxHr,
    │       │                       # useHrZones, useDecoupling, AnalysisCard/ChartGrid, statsMath.ts
    │       ├── activity/           # ActivityDetailView, RouteMap, lap-editor/
    │       ├── gym/                # Overview/Routines/History pages, routine editor + pickers,
    │       │                       # WorkoutSession + rest timer, useActiveWorkout, historyBins
    │       └── diet/               # DietOverviewPage, AddMealPage, QuantitySheet, BarcodeScanner,
    │                               # AddManualFoodPage, GoalPage, DietHistoryPage, SavedMeal pages,
    │                               # useMeals/useFoodLogs/useDietHistory/useNutritionGoal
    └── index.css                   # Design tokens (light/dark/auto theme)
```

---

## Getting Started

### Prerequisites

- Node.js (via [nvm](https://github.com/nvm-sh/nvm))
- Docker (for PostgreSQL)
- A [Strava API application](https://www.strava.com/settings/api) — only needed to exercise the running module
- A [Resend](https://resend.com) API key — the `EmailService` calls `ConfigService.getOrThrow()` at boot, so *some* value must be present even in dev or the server won't start

### Environment Variables

Create a `.env` file inside `server/`:

```env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/strava_dashboard

# Strava OAuth
STRAVA_CLIENT_ID=your_client_id
STRAVA_CLIENT_SECRET=your_client_secret
STRAVA_REDIRECT_URI=http://localhost:5173/api/strava/auth/callback

# Session
JWT_SECRET=some_random_dev_secret
JWT_EXPIRES_IN=30d

# Strava webhook (deauthorization events)
STRAVA_WEBHOOK_VERIFY_TOKEN=arbitrary_token_you_choose
STRAVA_WEBHOOK_SUBSCRIPTION_ID=id_returned_by_strava_on_subscription_registration

# Transactional email (welcome, password reset)
RESEND_API_KEY=your_resend_key
EMAIL_FROM="SoTreina <contas@yourdomain.com>"

FRONTEND_URL=http://localhost:5173
```

There is no single-user seed (`SEED_USER_ID` was removed) — accounts are created either by `POST /auth/register` or by completing `GET /strava/auth` (find-or-create on `stravaAthleteId`).

The `client/` app reads its API base URL from `VITE_API_URL` (defaults to `http://localhost:3000` if unset). No frontend `.env` is required for local dev if the server runs on the default port.

### Running the App

```bash
# 1. Start PostgreSQL
docker run --name strava-pg -e POSTGRES_PASSWORD=password -p 5432:5432 -d postgres:17

# 2. Backend
cd server
npm install
npx prisma migrate dev

# 3. Seed the reference data (all idempotent, safe to re-run)
npm run db:seed:gym            # 873 exercises (English)
npm run db:seed:gym:pt         # Portuguese names/instructions backfill
npm run db:seed:taco           # 597 TACO foods
npm run db:seed:taco:servings  # household-measure overlay (272 curated items)

npm run start:dev              # http://localhost:3000

# 4. Frontend (separate terminal)
cd client
npm install
npm run dev                    # http://localhost:5173
```

Open `http://localhost:5173`. You can either **create an account** with email/password (Gym and Diet work immediately, no Strava needed) or click **"Connect with Strava"** — authorizing on Strava (scope `read,activity:read_all,profile:read_all`) creates your `User`+`StravaAccount`, logs you in, and drops you on the first-sync onboarding screen, which triggers the initial import (`POST /strava/sync`) for you. An email/password account can link Strava later from the Profile page.

Optionally set your max HR in Run > Analysis to unlock real Z2/efficiency-factor thresholds, and run the HR-zones/best-efforts backfills to fill in historical data.

---

## Deployment

- **Backend:** [Render](https://render.com) (free tier, 512MB RAM) — start command must be `npm run start:prod` (`node dist/main`); `nest start --watch` OOMs on the free tier. Needs `NPM_CONFIG_PRODUCTION=false` alongside `NODE_ENV=production`, otherwise `npm install` skips `devDependencies` (where `@nestjs/cli` lives) and the build fails
- **Database:** [Neon](https://neon.tech) (Postgres, free tier)
- **Frontend:** [Vercel](https://vercel.com) — env var `VITE_API_URL=/api` (a relative path, not the Render URL directly)
- **Proxy:** `client/vercel.json` rewrites `/api/:path*` to the Render backend, so the browser only ever talks to the Vercel domain. This is required for the session cookie to survive Safari's Intelligent Tracking Prevention, which blocks `SameSite=None; Secure` cookies set by a genuinely cross-site backend regardless of the `SameSite`/`Secure` attributes. The OAuth `STRAVA_REDIRECT_URI` also points at the Vercel proxy path, not at Render directly, to keep the whole token exchange first-party. A second rewrite maps `/redefinir-senha` → `/index.html` so the password-reset link in the email doesn't 404 (the app has no react-router, hence no SPA fallback)
- **Security headers:** `client/vercel.json` sets a restrictive CSP — `script-src 'self'` plus a sha256 hash of the inline pre-paint theme script (**recompute via `npm run csp:hash` after touching a single byte of it**) and `'wasm-unsafe-eval'` for the barcode-detector ponyfill; an `img-src` allowlist (OSM tiles, Strava's avatar CDN, the exercise-image raw host, Open Food Facts images); `connect-src 'self'` (which works only because of the proxy); plus `nosniff`, `frame-ancestors 'none'`, HSTS, COOP, Referrer-Policy and `Permissions-Policy: camera=(self)` for the scanner
- **Seeds are a manual post-deploy step:** after `prisma migrate deploy` against Neon, the four `db:seed:*` scripts must be run there too. Forgetting `db:seed:gym:pt` fails safe but silently — exercise content just falls back to English
- Registering the Strava webhook subscription and setting `STRAVA_WEBHOOK_SUBSCRIPTION_ID` is a manual one-time step (see the `curl` command in `CLAUDE.md`)

---

## API Endpoints

Every route below requires the `session` cookie (`AuthGuard`) unless noted otherwise. Resources belonging to another user answer **404, never 403** — ownership is checked through the full relational chain in the Prisma `where`.

### Auth

| Method | Path | Description |
|---|---|---|
| `GET` | `/auth/me` | Current user, incl. `hasStravaAccount`/`hasPassword` (200 + empty body if not logged in, never 401 — no auth guard) |
| `POST` | `/auth/register` | Email/password sign-up (argon2), sends a welcome email — 409 if the email is taken |
| `POST` | `/auth/login` | Email/password login — returns the full `/auth/me` payload, so the client skips a round trip |
| `POST` | `/auth/set-password` | Adds a password to a Strava-only account (409 if one already exists — this is not "change password") |
| `POST` | `/auth/forgot-password` | Emails a reset link — always answers `{ok:true}` (anti-enumeration), no auth guard |
| `POST` | `/auth/reset-password` | Consumes the token, sets the new password and bumps `tokenVersion` (kills existing sessions) |
| `POST` | `/auth/logout` | Invalidates **all** sessions for the user (`tokenVersion` bump) and clears the cookie |

### Strava

| Method | Path | Description |
|---|---|---|
| `GET` | `/strava/auth` | Redirects to Strava's authorization page (anti-CSRF `state` cookie) — doubles as login |
| `GET` | `/strava/auth/callback` | Exchanges the code; links to the logged-in user if a session exists, otherwise find-or-creates one |
| `GET` | `/strava/connect` | Same OAuth flow, but explicitly for connecting Strava to an already-logged-in account |
| `DELETE` | `/strava/connect` | Unlinks Strava — deletes only the `StravaAccount`, never the user or their activities |
| `GET`/`POST` | `/strava/webhook` | Subscription challenge (GET) and deauthorization handler (POST) — no auth, origin checked via `subscription_id` |
| `POST` | `/strava/sync` | Fire-and-forget incremental sync for the caller's account; returns current progress immediately |
| `GET` | `/strava/sync/status` | Live `SyncProgress` (state, phase incl. `rate_limited`, counters, `rateLimitResetAt`, ETA) |
| `POST` | `/strava/sync/activity/:stravaId` | Synchronous re-sync of a single activity — recovery path for activities skipped mid-sync |
| `POST` | `/strava/sync/backfill-polylines` | One-off backfill of `summaryPolyline` |
| `POST` | `/strava/sync/backfill-gear` | One-off backfill linking activities to `Gear` |
| `POST` | `/strava/sync/backfill-lap-max-hr` | One-off backfill of `ActivityLap.maxHr` |
| `POST` | `/strava/best-efforts/backfill` | Fire-and-forget backfill of `ActivityBestEffort` for older activities |
| `POST` | `/strava/hr-zones/sync-athlete` | Syncs the athlete's HR zone definitions — manual/on-demand, not on cron |
| `POST` | `/strava/hr-zones/backfill` | Fire-and-forget backfill of per-activity `ActivityHrZoneTime` |

### Running

| Method | Path | Description |
|---|---|---|
| `GET` | `/activities` | Paginated list, `startDate` desc — filters: `page`, `limit`, `workoutType`, `dateFrom`, `dateTo`, `gearId` |
| `GET` | `/activities/:id` | Full detail incl. laps and route polyline |
| `GET` | `/activities/laps` | Flat list of every `ActivityLap` for the user (no pagination) — feeds Run > Analysis |
| `GET` | `/activities/hr-zones` | Per-activity real HR zone time from Strava (premium-gated) — feeds the Z2 tier system |
| `GET` | `/activities/weekly-distance` | Weekly distance aggregate (Monday-start, zero-filled) — no current frontend consumer |
| `GET` | `/activities/:id/streams` | Second-by-second stream for the lap editor (DB when available, fetched from Strava otherwise) |
| `PUT` | `/activities/:id/laps` | Replaces the activity's laps from the editor's working list, recalculating stats from scratch |
| `GET` | `/gear` | The user's gear with Strava-reported and locally-computed distance |
| `GET` | `/gear/:id/activities` | Paginated activities for one gear item (delegates to `ActivitiesService.list`) |
| `GET` | `/personal-bests` | Top-3 best efforts per distance, derived via `$queryRaw` (never materialized) |
| `GET` | `/personal-bests/history?name=` | Full best-effort history for one distance (query param — names like `"1/2 mile"` contain `/`) |

### Gym

| Method | Path | Description |
|---|---|---|
| `GET` | `/exercises` | Paginated library — filters: `search` (matches EN or PT), `muscle`, `muscles` (OR), `equipment` |
| `GET` | `/exercises/:id` | Single exercise, localized via `Accept-Language` |
| `POST` | `/exercises` | Creates a custom exercise, visible only to its creator |
| `GET` | `/exercises/:id/last-performance` | Most recent finished workout containing it (`null` is a valid answer) |
| `GET` | `/exercises/:id/personal-record` | Heaviest set ever logged for it, scoped to the caller |
| `POST` | `/workouts` | Starts a workout (optional `templateId`) — idempotent: resumes an open workout instead of duplicating |
| `GET` | `/workouts` | Finished workouts, most recent first |
| `GET` | `/workouts/active` | The currently open workout, if any |
| `GET` | `/workouts/history-stats` | Last 180 days of finished workouts with `volumeKg`/`durationSec` — client buckets into weeks |
| `GET` | `/workouts/:id` | Full detail (exercises, sets, per-exercise targets from the routine) |
| `GET` | `/workouts/:id/template-drift` | Whether the session's structure/set counts diverged from its routine |
| `PATCH` | `/workouts/:id/finish` | Marks it finished (optionally syncing the routine to what was actually done) |
| `DELETE` | `/workouts/:id` | Discards the workout and everything under it (cascade) |
| `POST`/`PATCH`/`DELETE` | `/workouts/:id/exercises[/:workoutExerciseId]` | Add / update / remove an exercise in the session |
| `POST`/`PATCH`/`DELETE` | `/workouts/:id/exercises/:workoutExerciseId/sets[/:setId]` | Log / edit / delete a set |
| `GET` | `/workout-templates` | Routines with `exercisePreview`, `exerciseCount`, `muscleGroups`, `lastPerformedAt` |
| `POST` | `/workout-templates` | Creates a routine, with exercises or empty |
| `GET` | `/workout-templates/:id` | Full routine detail (exercises + targets, localized) |
| `PATCH` | `/workout-templates/:id` | Updates name/description and/or **replaces the exercise list wholesale** — the editor always sends the full list it built, there is no diffed update |
| `DELETE` | `/workout-templates/:id` | Deletes the routine; past workouts survive with `templateId` nulled |

Every mutation on `/workouts` returns the complete `WorkoutDetail`, so the client never issues a follow-up GET. `order` and `setNumber` are always derived server-side (`max + 1`), never sent by the client.

### Diet

| Method | Path | Description |
|---|---|---|
| `GET` | `/foods/search?q=` | Local search across TACO, cached OFF products and the caller's custom foods — never calls OFF |
| `GET` | `/foods/barcode/:code` | Local cache → Open Food Facts → cache the result; 404 lets the client offer manual entry |
| `POST` | `/foods/custom` | Creates a per-user food (always stored per 100 g; optional `servingLabel`/`servingGrams` pair) |
| `POST` | `/food-logs` | Logs a food into a meal (`quantity` in grams, `enteredAsServing` display hint) |
| `GET` | `/food-logs?date=` | The day's entries |
| `GET` | `/food-logs/summary?date=` | The day's kcal/protein/carbs/fat totals (`$queryRaw`) |
| `GET` | `/food-logs/history?days=7\|14` | Daily totals, zero-filled via `generate_series` so empty days still appear |
| `PATCH` | `/food-logs/:id` | Edits `quantity`/`enteredAsServing` only — food, meal and timestamp are immutable |
| `DELETE` | `/food-logs/:id` | Removes an entry |
| `GET` | `/meals` | The user's meals with `logCount`; lazily seeds the 5 defaults on first call (a GET that writes, deliberately) |
| `POST` | `/meals` | Adds a meal (max 12) |
| `PATCH` | `/meals/:id` | Renames a meal |
| `PUT` | `/meals/order` | Batch reorder from the full ordered id list — `order` is never trusted per row |
| `DELETE` | `/meals/:id` | Deletes a meal **and its logs across every day** (cascade); refuses to delete the last one |
| `POST`/`GET`/`PATCH`/`DELETE` | `/saved-meals[/:id]` | CRUD for named food groups |
| `POST` | `/saved-meals/:id/apply` | Materializes every item of a saved meal into `FoodLog` rows in one action |

Every meal mutation returns the whole updated list — reordering renumbers several rows at once, so returning just the touched row would force a refetch.

### User

| Method | Path | Description |
|---|---|---|
| `GET` | `/users/me` | `maxHr` + the four daily diet goals (`dailyKcalGoal`, `dailyProteinGoal`, `dailyCarbsGoal`, `dailyFatGoal`) |
| `PATCH` | `/users/me` | Updates any subset of those five fields (`maxHr` 100–230, kcal 800–6000, macros 0–500 g); always returns the full snapshot |

The sync job also runs automatically every 6 hours via cron, iterating all connected accounts sequentially (Strava's rate limit is app-wide, not per-account). The routes that call the Strava API are additionally capped at 10 req/min **per account**, and every route sits behind a 100 req/min per-IP limit (tighter on the public, pre-auth ones).

---

## Data Model

```
User (email/passwordHash/firstName/profileImgUrl nullable — Strava OAuth returns no email,
      and Strava-only accounts have no password; tokenVersion drives session invalidation)
 │
 ├── PasswordResetToken   (SHA-256 hash of a 32-byte token, 30-min TTL, single use)
 │
 ├── Running ─────────────────────────────────────────────────────────────────────────
 │   ├── StravaAccount     (OAuth tokens — @unique stravaAthleteId is the real identity key)
 │   ├── AthleteHrZones    (Strava HR zone definitions, one per user)
 │   ├── Gear              (shoes: name, brand, distance, retired/primary)
 │   └── Activity          (one per Strava run)
 │        ├── ActivityLap        (detected, natively-recorded or manually-edited — analysis source)
 │        ├── ActivitySecond     (per-second stream — only for INTERVAL/HILL without recorded laps)
 │        ├── ActivityBestEffort (Strava best efforts, one row per distance per activity)
 │        └── ActivityHrZoneTime (real HR zone time, one row per zone per activity)
 │
 ├── Gym ─────────────────────────────────────────────────────────────────────────────
 │   ├── Exercise          (shared library: source SEED = global, USER = creator-only)
 │   ├── WorkoutTemplate   (saved routine)
 │   │    └── WorkoutTemplateExercise (targetSets, targetRepsMin/Max — never actual weight)
 │   └── Workout           (a session; templateId is nullable, ON DELETE SET NULL)
 │        └── WorkoutExercise
 │             └── WorkoutSet   (weightKg, reps, rpe, setType)
 │
 └── Diet ────────────────────────────────────────────────────────────────────────────
     ├── Food              (source TACO/OFF = global reference, CUSTOM = creator-only)
     ├── Meal              (per-user, per-day-agnostic configuration: name + order)
     │    └── FoodLog      (ON DELETE CASCADE from Meal — deleting a meal wipes its history)
     └── SavedMeal
          └── SavedMealItem (grams only — no serving flag, unlike FoodLog)
```

Every entity carries a `userId` foreign key from day one, enabling cross-domain correlation. Activities use `startDate` as the canonical correlation timestamp.

**Invariants worth knowing before touching the data:**

- `ActivityLap.avgHr` is a non-nullable `Float` that uses `0` as a "no HR monitor" sentinel (`maxHr` is the field that's genuinely nullable) — any HR aggregation over laps must check `avgHr > 0` first, or it silently deflates.
- `Gear` and `ActivityBestEffort` use Strava's raw ID as `@id` (no cuid) — an intentional break from the pattern elsewhere, to avoid duplicating data and BigInt-serialization friction.
- `Food` rows are **always per 100 g**, with `sodium` always in mg — Open Food Facts reports sodium in grams and is normalized on ingest, TACO is already in mg.
- `FoodLog.quantity` is **always in grams**. `enteredAsServing` is purely a display hint ("2 unidades (100 g)" vs "100 g") and never enters a calculation — every aggregation still multiplies by `quantity/100`.
- Visibility follows one rule in both libraries: reference data is global (`Exercise.source = SEED`, `Food.source = TACO|OFF`), user-created data is creator-only (`USER`, `CUSTOM`), decided in a single `visibilityWhere()` per service.
- Two deletion semantics that deliberately differ: deleting a `WorkoutTemplate` preserves history (`ON DELETE SET NULL`), deleting a `Meal` erases its `FoodLog`s across every day (`ON DELETE CASCADE`). Both are pinned by tests that read the generated `migration.sql` and fail if the `ON DELETE` clause changes.
- Two meals may share the same name (two "Lanche"), which is exactly why `FoodLog` references a `mealId` instead of carrying the `MealType` enum — and why meal order must never be re-sorted client-side.

Postgres enums: `WorkoutType`, `LapType`, `ExerciseSource`, `MuscleGroup`, `Equipment`, `ExerciseLevel`, `ExerciseForce`, `ExerciseMechanic`, `SetType`, `FoodSource`, `MealType`.

---

## Testing

```bash
cd server
npm test           # vitest run
npm run test:watch
npm run test:cov
```

```bash
cd client
npm test           # vitest run — pure functions/hooks only, no jsdom yet
```

**Server** (`server/test/`, one directory per module): workout classification and lap detectors; pure mappers (lap/split, best-effort, gear, HR-zone); the training-load calculator (fixtures validated against the legacy Python pipeline); the adaptive rate-limit throttle; the lap editor's sequential-scan resolver; `StravaSyncService`/`BestEffortsSyncService` integration (with `sleep` mocked via `vi.spyOn`, since `vi.useFakeTimers()` conflicts with NestJS/Prisma's internal Promises); auth (session service, guards, DTO parsing, password hashing, account throttler); the Resend email service; the exercises/workouts/workout-templates services and the gym seed; and the foods/food-logs/meals/saved-meals services, DTOs and the Open Food Facts client (with `fetch` mocked).

Two tests assert on generated SQL rather than behavior: `gym/workout-templates-migration.test.ts` and `meals/meals-migration.test.ts` read the migration files and fail if the `ON DELETE` clause — or, for `add_meals`, the *order* of the data-migration steps (backfill → `SET NOT NULL` → `DROP COLUMN`) — changes, since either would be silently destructive.

**Client**: `useTrainingMetrics`/`computeWeekMetrics`, `useDecoupling`, `lapBoundaryMath` (the client-side mirror of the lap editor's scan algorithm), `useRestTimer`/`RestTimerEngine` (with fake timers), `historyBins`, `relativeTime`, `quantityFormat` and `activityFormat`/`avatarUrl`.

---

## Tooling & Conventions

- **Commits:** Conventional Commits, enforced via Commitlint + Husky (`commit-msg` hook), configured at the repo root; `npm run commit` (from the root) launches Commitizen for a guided commit message.
- **Formatting:** Prettier, consistent config between `server/` and `client/`.
- **Type checking:** run `npx tsc --noEmit` before starting the server after non-trivial changes.
- **Validation:** manual parsing in `dto.ts` per module, not `class-validator` — a deliberate consistency choice across every module in the project.
- **Locale:** the backend threads `lang` explicitly as a trailing parameter instead of using request-scoped providers or CLS — each service constructs its own `PrismaClient`, so a request-scoped provider would open one connection pool per request.
- **Vertical slices:** features are implemented backend + frontend together, not in separate phases (documented exception: `Gear`/`ActivityBestEffort` shipped backend-only; their frontend pages came later).
- **Full-file handoffs:** for substantial changes, complete files are preferred over diffs.
- **Replaced screens get deleted**, not left as dead code — the diet redesign removed its predecessor pages outright rather than orphaning them.

---

## Known Limitations

- `hasRecordedLaps` relies on matching Strava's auto-lap name string (e.g. `'Strava Auto Lap'`) — fragile as a signal, but functional today.
- Day and week boundaries are computed in **UTC** in two places: `GET /activities/weekly-distance` and the diet's `date=YYYY-MM-DD` → `[00:00, +24h)` window. A run or a food entry logged between 9pm and midnight BRT can land on the wrong day/week. The frontend aggregates activities in local time, so for running this only affects that one endpoint (which has no frontend consumer); for diet it affects real entries.
- `StravaSyncService` and the administrative backfills (`BestEffortsSyncService`/`HrZonesBackfillService`) have independent `isSyncing` guards — nothing stops firing the main sync and a backfill at the same time, competing for the same Strava rate limit. Per-account throttling reduces (but doesn't eliminate) the practical chance of a collision.
- `useTrainingMetrics` uses real Strava HR-zone data only when `hrZonesSyncedAt` is set and the account is premium; otherwise it falls back to `maxHr * 0.7` (if configured) or a flat `avgHr < 150` heuristic, with a visible UI hint indicating which tier is active.
- `processSteadyActivity` has an early-return path that creates zero laps if an activity has neither recorded laps nor metric splits — no current activity hits this, so no defensive guard was added, but such an activity would be invisible to `GET /activities/laps` (and thus Run > Analysis) despite appearing normally elsewhere.
- The sync resume cursor is implicit (max `startDate` in the DB) and depends on ascending processing order — a non-rate-limit error on one activity is logged and skipped, and if later activities save successfully the cursor moves past it. Manual recovery: `POST /strava/sync/activity/:stravaId`.
- The Strava webhook doesn't sign its payloads; origin validation relies on checking `subscription_id` against a known value, which is guessable in theory. Accepted residual risk for the current group size.
- The barcode scanner's decode resolution is capped by `html5-qrcode`: its decoding canvas is created at the `qrbox` size in **CSS pixels**, throwing away most of the resolution the camera already captured. Widening the `qrbox` mitigated it; fixing it properly means dropping `html5-qrcode` for `zxing-wasm` directly over `getUserMedia`.
- Household measures cover 272 of the 597 TACO foods — the rest were deliberately left out (regional preparations, uncommon raw cuts, and every case where the measure could only be a forced "1 portion = 100 g"). A food without an overlay simply stays grams-only: a safe, silent fallback. Extending it is just adding rows to `taco_servings.json` and re-running the seed.
- `npm run db:seed:gym:pt` is a manual post-deploy step. Forgetting it fails safe — exercise content falls back to English — but silently.

---

## Roadmap

**Platform**

- [x] Prisma schema, PostgreSQL migrations, Prisma 7 + `@prisma/adapter-pg`
- [x] Email/password authentication (argon2) with transactional email via Resend
- [x] Password recovery (`forgot-password` / `reset-password`) with hashed, single-use tokens
- [x] Strava OAuth as login **and** as an optional post-signup connection (connect/disconnect)
- [x] Server-side session invalidation (`tokenVersion`), CSRF `state`, helmet, CSP, per-IP and per-account rate limiting
- [x] Mobile-responsive layout (app bar + drawer nav, mobile-specific views)
- [x] pt/en i18n (frontend namespaces + backend `Accept-Language`)
- [x] Light/dark/auto theme
- [x] Optimized boot (parallel session check, history check, prefetch and page chunk)
- [x] Custom domain (`sotreina.com`) — DNS/Vercel setup in progress

**Running**

- [x] Strava OAuth 2.0 flow (incl. `profile:read_all` for HR zones)
- [x] Incremental sync (cron + manual trigger), multi-account, live progress, adaptive rate-limit handling
- [x] Second-by-second stream ingestion (fallback path plus on-demand for the lap editor)
- [x] Workout classification + lap detection (ported from the Python pipeline)
- [x] Manual lap editor (add/split/delete/resize/reorder)
- [x] Route polylines, gear tracking, best-effort PRs, real Strava HR zones — with backfills
- [x] Dashboard, activity detail, Run Overview, Run Analysis (9 lap-level charts — temporarily hidden behind a nav flag while being tuned)
- [ ] Migrate sync from polling (cron) to Strava activity webhooks (the deauthorization webhook already exists; activity events are received but ignored)

**Gym**

- [x] Exercise library (873 seeded + user-custom, PT translations, muscle/equipment filters)
- [x] Saved routines with targets, reorder, and history-preserving deletion
- [x] Live workout session (idempotent start, per-set "last time" suggestions, template drift detection)
- [x] Client-side rest timer (absolute timestamps, `localStorage`-persisted, Web Audio beep)
- [x] History (weekly volume, workout drill-down, per-set detail, estimated 1RM) and per-exercise PRs
- [ ] Free workout (no routine) — the backend supports it, the UI has no entry point yet
- [ ] Supersets (schema already carries `supersetGroupId`; the logic and UI are missing)
- [ ] Analytics (volume by muscle group, e1RM trends, PR detection), configurable per-exercise rest, routine duplication, suggested load progression, Hevy history import

**Diet**

- [x] Food library: TACO (597, committed seed) + Open Food Facts by barcode (cached) + custom foods
- [x] Barcode scanner with an iOS/WebKit WASM fallback for `BarcodeDetector`
- [x] Configurable, repeatable, reorderable meals (lazy defaults under an advisory lock)
- [x] Household measures (`servingLabel`/`servingGrams`) with grams as the single stored unit
- [x] Saved meals appliable to any meal in one action
- [x] Daily kcal/macro goals, progress ring and 7/14-day history
- [ ] Recipes, automatic goal recommendations (goals are 100% manual today), macro charts in the history, trends beyond 14 days
- [ ] Additional nutrition sources (Nutritionix, USDA FDC)
- [ ] Household measures for more of the TACO table (272 of 597 covered)

**Hub**

- [ ] Cycling and swimming modules (nav entries exist, disabled)
- [ ] Cross-domain correlation views (training load vs. nutrition vs. strength volume)

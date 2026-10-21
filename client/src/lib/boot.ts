import type { ComponentType } from 'react';
import { apiFetch } from './api';
import type { ActivitiesResponse } from './types';
// type-only: erased at runtime, so no import cycle with AuthContext
import type { AuthUser } from '@/features/auth/AuthContext';
import {
  ACTIVE_PAGE_KEY,
  DEFAULT_PAGE,
  isKnownPage,
  type PageId,
} from '@/features/nav/navConfig';
import { FIRST_SYNC_FLAG } from '@/features/onboarding/firstSyncFlag';

// Boot wiring, evaluated once at module scope (main.tsx imports this module
// first, before React/i18n). Goal: for a returning logged-in user, /auth/me,
// the hasActivities gate, the heavy activities fetch and the active page's
// chunk all start in parallel at t0 instead of chaining one after the other.
//
// The optimistic fetches are gated on localStorage hints on purpose: firing
// them for a logged-out visitor would log 401s in the console on every load —
// the exact problem the empty-200 /auth/me contract was introduced to avoid.

// '1' after a load confirmed the logged-in user has imported activities
export const HAS_ACTIVITIES_HINT = 'has-activities';

// prefetch older than this is dropped (user idled before the page mounted)
const PREFETCH_MAX_AGE_MS = 30_000;

// shared with React.lazy in App.tsx — same import specifier means the browser
// module map dedupes the boot preload and the lazy() call into one download.
// ComponentType<any> (not the default ComponentType<{}>) because these pages
// don't all share one prop shape
export const PAGE_IMPORTERS: Partial<
  Record<PageId, () => Promise<{ default: ComponentType<any> }>>
> = {
  overview: () => import('@/features/today/TodayPage'),
  'run/activities': () => import('@/features/dashboard/Dashboard'),
  'run/overview': () => import('@/features/overview/RunOverviewPage'),
  'run/analysis': () => import('@/features/analysis/RunAnalysisPage'),
  'gym/overview': () => import('@/features/gym/GymOverviewPage'),
  'gym/workouts': () => import('@/features/gym/GymWorkoutsPage'),
  'gym/history': () => import('@/features/gym/GymHistoryPage'),
  'diet/overview': () => import('@/features/diet/DietOverviewPage'),
  'diet/history': () => import('@/features/diet/DietHistoryPage'),
};

export function recordHasActivities(has: boolean): void {
  if (has) localStorage.setItem(HAS_ACTIVITIES_HINT, '1');
  else localStorage.removeItem(HAS_ACTIVITIES_HINT);
}

export function clearBootHints(): void {
  localStorage.removeItem(HAS_ACTIVITIES_HINT);
}

// ---- optimistic prefetch of the heavy activities payload ----

let prefetch: {
  promise: Promise<ActivitiesResponse>;
  startedAt: number;
} | null = null;

function startActivitiesPrefetch(): void {
  const promise = apiFetch('/activities?limit=1000').then((res) => {
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json() as Promise<ActivitiesResponse>;
  });
  // guard branch: avoids an unhandled rejection if nobody consumes it
  promise.catch(() => {});
  prefetch = { promise, startedAt: Date.now() };
}

/** One-shot: hands the prefetch over once; later callers go to the network. */
export function takeActivitiesPrefetch(): Promise<ActivitiesResponse> | null {
  const taken = prefetch;
  prefetch = null;
  if (!taken || Date.now() - taken.startedAt > PREFETCH_MAX_AGE_MS) return null;
  return taken.promise;
}

// ---- shared boot fetches ----

// same guard pattern as i18n/index.ts: this module may be imported
// transitively by pure vitest tests (no jsdom), where the module-scope
// fetch/localStorage side effects below would crash the suite
const inBrowser = typeof localStorage !== 'undefined';

// /auth/me answers 200 for everyone; an empty body means "no session"
export const authMe: Promise<AuthUser | null> = inBrowser
  ? apiFetch('/auth/me')
      .then((res) => (res.ok ? res.text() : ''))
      .then((text) => (text ? (JSON.parse(text) as AuthUser) : null))
      .catch(() => null)
  : Promise.resolve(null);

function fetchHasActivities(): Promise<boolean> {
  return apiFetch('/activities?limit=1')
    .then((res) => {
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json();
    })
    .then((data: ActivitiesResponse) => {
      recordHasActivities(data.total > 0);
      return data.total > 0;
    })
    .catch(() => true); // fail open — the dashboard surfaces its own fetch errors
}

const hinted = inBrowser && localStorage.getItem(HAS_ACTIVITIES_HINT) === '1';

if (!inBrowser) {
  // tests: no preloads, no fetches
} else if (localStorage.getItem(FIRST_SYNC_FLAG) != null) {
  // mid-onboarding reload → the gate will land on FirstSyncPage
  import('@/features/onboarding/FirstSyncPage').catch(() => {});
} else if (hinted) {
  const stored = localStorage.getItem(ACTIVE_PAGE_KEY);
  const activePage = isKnownPage(stored) ? stored : DEFAULT_PAGE;
  // preload failures are fine: lazy() retries the import on render
  PAGE_IMPORTERS[activePage]?.().catch(() => {});
  startActivitiesPrefetch();
} else {
  // no hint = likely logged out or first visit
  import('@/features/auth/LoginPage').catch(() => {});
}

// with a hint the gate check runs in parallel with /auth/me; without one it
// chains on the session answer (still earlier than the old App.tsx effect)
export const bootHasActivities: Promise<boolean> = !inBrowser
  ? Promise.resolve(true)
  : hinted
    ? fetchHasActivities()
    : authMe.then((user) => (user ? fetchHasActivities() : true));

// dead/no session → drop hints so future loads stop firing optimistic fetches
authMe.then((user) => {
  if (!user) {
    clearBootHints();
    prefetch = null;
  }
});

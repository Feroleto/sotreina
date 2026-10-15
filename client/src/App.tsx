import { lazy, Suspense, useEffect, useRef, useState } from 'react';
import { flushSync } from 'react-dom';
import { useTranslation } from 'react-i18next';
import Sidebar from '@/features/nav/Sidebar';
import MobileChrome from '@/features/nav/MobileChrome';
import PlaceholderPage from '@/features/nav/PlaceholderPage';
import ProfilePage from '@/features/profile/ProfilePage';
import { FIRST_SYNC_FLAG } from '@/features/onboarding/firstSyncFlag';
import { useAuth } from '@/features/auth/AuthContext';
import { parseThemePref, type ThemePref } from '@/lib/theme';
import { useActiveWorkout } from '@/features/gym/useActiveWorkout';
import ActiveWorkoutBar from '@/features/gym/ActiveWorkoutBar';
import {
  PAGE_IMPORTERS,
  bootHasActivities,
  recordHasActivities,
} from '@/lib/boot';
import {
  ACTIVE_PAGE_KEY,
  DEFAULT_PAGE,
  isKnownPage,
  isPageDisabled,
  type PageId,
} from '@/features/nav/navConfig';

// section switches crossfade via the View Transitions API where it exists
// (Chromium, Safari 18+); elsewhere the new page plays the same entrance as
// a plain CSS animation (.page-enter in index.css)
const supportsViewTransitions =
  typeof document !== 'undefined' && 'startViewTransition' in document;

/**
 * Runs `commit` inside a view transition once `page`'s chunk is loaded
 * (otherwise the "new" snapshot is Suspense's empty fallback and the real
 * page pops in after). `scope` is the <html> class that names what gets
 * captured, only for the transition's lifetime (see index.css): 'vt-page' =
 * just the page panel, 'vt-root' = the whole screen. A lasting name would
 * make the element a stacking context and trap the page's own overlays
 * (sheets, lap editor, scanner) under the z-40 mobile app bar.
 * `isCurrent` lets a newer call supersede a slower one.
 */
function runViewTransition(
  page: PageId,
  scope: 'vt-page' | 'vt-root',
  commit: () => void,
  isCurrent: () => boolean = () => true,
) {
  if (!supportsViewTransitions) {
    commit();
    return;
  }
  const load = PAGE_IMPORTERS[page]?.() ?? Promise.resolve();
  void load
    .catch(() => {})
    .then(() => {
      if (!isCurrent()) return;
      const root = document.documentElement;
      root.classList.add(scope);
      const vt = document.startViewTransition(() => flushSync(commit));
      void vt.finished.finally(() => {
        if (isCurrent()) root.classList.remove(scope);
      });
    });
}

// code-split per page: keeps Leaflet, the analysis charts and the dashboard
// out of the entry chunk that the logged-out LoginPage visitor downloads.
// Importers are shared with lib/boot.ts, which preloads the active page's
// chunk at t0 — same specifier, so the module map dedupes the download.
const Dashboard = lazy(PAGE_IMPORTERS['run/activities']!);
const RunOverviewPage = lazy(PAGE_IMPORTERS['run/overview']!);
const RunAnalysisPage = lazy(PAGE_IMPORTERS['run/analysis']!);
const GymOverviewPage = lazy(PAGE_IMPORTERS['gym/overview']!);
const GymWorkoutsPage = lazy(PAGE_IMPORTERS['gym/workouts']!);
const GymHistoryPage = lazy(PAGE_IMPORTERS['gym/history']!);
const DietOverviewPage = lazy(PAGE_IMPORTERS['diet/overview']!);
const DietHistoryPage = lazy(PAGE_IMPORTERS['diet/history']!);
// login/onboarding are dead weight for the recurring logged-in user; boot.ts
// preloads whichever one the localStorage hints predict will be needed
const LoginPage = lazy(() => import('@/features/auth/LoginPage'));
const ResetPasswordPage = lazy(() => import('@/features/auth/ResetPasswordPage'));
const FirstSyncPage = lazy(() => import('@/features/onboarding/FirstSyncPage'));

function PageContent({
  page,
  themePref,
  onThemePref,
  activeWorkout,
  onOpenDrawer,
}: {
  page: PageId;
  themePref: ThemePref;
  onThemePref: (pref: ThemePref) => void;
  activeWorkout: ReturnType<typeof useActiveWorkout>;
  onOpenDrawer: () => void;
}) {
  const { t } = useTranslation('nav');
  switch (page) {
    case 'overview':
      return <PlaceholderPage title={t('sections.overview')} />;
    case 'run/overview':
      return <RunOverviewPage />;
    case 'run/analysis':
      return <RunAnalysisPage />;
    case 'gym/overview':
      return <GymOverviewPage />;
    case 'gym/workouts':
      return (
        <GymWorkoutsPage activeWorkout={activeWorkout} onOpenDrawer={onOpenDrawer} />
      );
    case 'gym/history':
      return <GymHistoryPage />;
    case 'diet/overview':
      return <DietOverviewPage />;
    case 'diet/history':
      return <DietHistoryPage />;
    case 'profile':
      return <ProfilePage themePref={themePref} onThemePref={onThemePref} />;
    case 'run/activities':
    default:
      return <Dashboard />;
  }
}

// real text content (not a bare background) so the first paint counts as
// FCP while the auth check waits on a possibly cold backend
function BootSplash() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-page-bg">
      <div className="flex items-center gap-2.5">
        <div className="flex h-[30px] w-[30px] items-center justify-center rounded-[9px] bg-acc text-[14px] font-bold text-white">
          ST
        </div>
        <span className="text-[15px] font-semibold text-foreground">
          SoTreina
        </span>
      </div>
    </div>
  );
}

function App() {
  const { user, loading } = useAuth();
  // 'auto' follows the browser via prefers-color-scheme; a manual pick
  // persists and wins until the user goes back to Auto
  const [themePref, setThemePref] = useState<ThemePref>(() =>
    parseThemePref(localStorage.getItem('theme')),
  );
  const [systemDark, setSystemDark] = useState(
    () => window.matchMedia('(prefers-color-scheme: dark)').matches,
  );
  const [collapsed, setCollapsed] = useState(
    () => localStorage.getItem('sidebar-collapsed') === 'true',
  );
  const [page, setPage] = useState<PageId>(() => {
    const stored = localStorage.getItem(ACTIVE_PAGE_KEY);
    return isKnownPage(stored) && !isPageDisabled(stored) ? stored : DEFAULT_PAGE;
  });
  // first-access gate: null while checking whether the user has any imported
  // activity yet; onboardingDone lets FirstSyncPage hand off to the dashboard
  const [hasActivities, setHasActivities] = useState<boolean | null>(null);
  const [onboardingDone, setOnboardingDone] = useState(false);

  // owned here (not MobileChrome) so WorkoutSession's hamburger button can
  // open the same drawer from anywhere in the tree
  const [drawerOpen, setDrawerOpen] = useState(false);
  // drawer gets its own history entry so hardware/gesture back closes it
  // instead of leaving the app (same pattern as the activity detail)
  const drawerPushedRef = useRef(false);
  // the first page after boot appears as-is; only real navigations animate
  const [navigated, setNavigated] = useState(false);
  // a slow chunk for an earlier click must not land after a later one
  const navSeqRef = useRef(0);

  // enabled only once auth is resolved, mirroring lib/boot.ts's has-activities
  // hint — otherwise a logged-out visitor would fire a 401 against
  // /workouts/active. Lives here (not GymWorkoutsPage) so an active session
  // survives navigating away from Academia and can drive ActiveWorkoutBar
  const activeWorkout = useActiveWorkout(!!user);

  const theme =
    themePref === 'auto' ? (systemDark ? 'dark' : 'light') : themePref;

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    // the fetch itself started back in lib/boot.ts, possibly in parallel
    // with /auth/me — here we only consume the shared promise
    bootHasActivities.then((has) => {
      if (!cancelled) setHasActivities(has);
    });
    return () => {
      cancelled = true;
    };
  }, [user]);

  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = (e: MediaQueryListEvent) => setSystemDark(e.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    const dark = theme === 'dark';
    // already applied pre-paint by index.html's inline script on first run
    if (root.classList.contains('dark') === dark) return;
    // freeze every transition for the swap, otherwise each surface's own
    // color/background transition fires at once and the switch smears
    const freeze = document.createElement('style');
    freeze.textContent = '*,*::before,*::after{transition:none!important}';
    document.head.appendChild(freeze);
    root.classList.toggle('dark', dark);
    void window.getComputedStyle(document.body).backgroundColor; // force style flush
    requestAnimationFrame(() => freeze.remove());
  }, [theme]);

  useEffect(() => {
    localStorage.setItem('theme', themePref);
  }, [themePref]);

  useEffect(() => {
    localStorage.setItem('sidebar-collapsed', String(collapsed));
  }, [collapsed]);

  useEffect(() => {
    localStorage.setItem(ACTIVE_PAGE_KEY, page);
  }, [page]);

  useEffect(() => {
    const onPop = () => {
      drawerPushedRef.current = false;
      setDrawerOpen(false);
    };
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, []);

  const openDrawer = () => {
    setDrawerOpen(true);
    window.history.pushState({ drawer: true }, '');
    drawerPushedRef.current = true;
  };

  const closeDrawer = () => {
    if (drawerPushedRef.current) {
      window.history.back();
    } else {
      setDrawerOpen(false);
    }
  };

  const navigate = (next: PageId, opts?: { collapse?: boolean }) => {
    if (isPageDisabled(next)) return;
    if (opts?.collapse) setCollapsed(true);
    if (next === page) return;
    const seq = ++navSeqRef.current;
    runViewTransition(
      next,
      'vt-page',
      () => {
        setNavigated(true);
        setPage(next);
      },
      () => seq === navSeqRef.current,
    );
  };

  // reached only via the emailed reset link — must work regardless of
  // whether the visitor currently has a session, so this check comes before
  // the loading/user gate below
  if (window.location.pathname === '/redefinir-senha') {
    return (
      <Suspense fallback={<BootSplash />}>
        <ResetPasswordPage themePref={themePref} onThemePref={setThemePref} />
      </Suspense>
    );
  }

  if (loading || (user && hasActivities === null)) {
    return <BootSplash />;
  }

  if (!user) {
    return (
      <Suspense fallback={<BootSplash />}>
        <LoginPage themePref={themePref} onThemePref={setThemePref} />
      </Suspense>
    );
  }

  // no imported history yet (or a first import is still running after a
  // reload) → onboarding sync screen instead of an empty dashboard. Gated on
  // hasStravaAccount too: a user who registered via email/password and never
  // connected Strava has no sync to onboard into — FirstSyncPage's calls are
  // Strava-specific and would just fail for them
  if (
    !onboardingDone &&
    user.hasStravaAccount &&
    (hasActivities === false || localStorage.getItem(FIRST_SYNC_FLAG) != null)
  ) {
    return (
      <Suspense fallback={<BootSplash />}>
        <FirstSyncPage
          // onboarding → app shell crossfades as a whole screen (the
          // dashboard's own first-visit entrances then play on top)
          onDone={() =>
            runViewTransition(page, 'vt-root', () => {
              recordHasActivities(true);
              setHasActivities(true);
              setOnboardingDone(true);
            })
          }
        />
      </Suspense>
    );
  }

  return (
    <div className="min-h-screen bg-page-bg max-md:pt-[calc(max(12px,env(safe-area-inset-top))_+_53px)] max-md:pb-[env(safe-area-inset-bottom)] md:p-3.5">
      <MobileChrome
        activePage={page}
        onNavigate={navigate}
        drawerOpen={drawerOpen}
        onOpenDrawer={openDrawer}
        onCloseDrawer={closeDrawer}
      />
      {activeWorkout.workout && page !== 'gym/workouts' && (
        <ActiveWorkoutBar
          workout={activeWorkout.workout}
          onOpen={() => navigate('gym/workouts')}
        />
      )}
      <div className="flex items-start md:gap-3.5">
        <Sidebar
          collapsed={collapsed}
          onToggleCollapse={() => setCollapsed((c) => !c)}
          activePage={page}
          onNavigate={navigate}
          themePref={themePref}
          onThemePref={setThemePref}
        />
        <div className="min-w-0 flex-1 md:min-h-[calc(100vh-28px)] md:rounded-2xl md:border md:border-border md:bg-card md:shadow-[0_8px_24px_rgba(8,12,20,.06)]">
          {/* the only element captured by the section view transition —
              chrome (sidebar, app bar, drawer) stays live, see index.css */}
          <div
            key={page}
            data-vt-page
            className={navigated && !supportsViewTransitions ? 'page-enter' : undefined}
          >
            <Suspense fallback={<div className="min-h-[calc(100vh-28px)]" />}>
              <PageContent
                page={page}
                themePref={themePref}
                onThemePref={setThemePref}
                activeWorkout={activeWorkout}
                onOpenDrawer={openDrawer}
              />
            </Suspense>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;

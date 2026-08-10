import { lazy, Suspense, useEffect, useRef, useState } from 'react';
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
    document.documentElement.classList.toggle('dark', theme === 'dark');
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
    setPage(next);
    if (opts?.collapse) setCollapsed(true);
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
          onDone={() => {
            recordHasActivities(true);
            setHasActivities(true);
            setOnboardingDone(true);
          }}
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
  );
}

export default App;

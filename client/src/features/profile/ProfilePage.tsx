import { useState } from 'react';
import type { FormEvent, ReactNode } from 'react';
import { ChevronRight, LogOut } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import SegmentedControl from '@/components/SegmentedControl';
import PasswordInput from '@/components/PasswordInput';
import { useAuth } from '@/features/auth/AuthContext';
import { useAppLanguage } from '@/i18n/useAppLanguage';
import { apiFetch } from '@/lib/api';
import { API_BASE_URL } from '@/lib/apiUrl';
import { THEME_OPTIONS, type ThemePref } from '@/lib/theme';
import { ConnectWithStrava } from '@/components/StravaBrand';
import DrillStack from '@/components/DrillStack';
import { formatNumber } from '@/lib/activityFormat';
import { cn } from '@/lib/utils';
import type { Area } from '@/lib/types';
import { AREAS } from '@/features/areas/areas';
import { useAreas } from '@/features/areas/useAreas';
import { useUserGoals } from '@/features/today/useUserGoals';
import WeeklyGoalsPage from '@/features/today/WeeklyGoalsPage';
import GoalPage from '@/features/diet/GoalPage';
import EditNamePage from './EditNamePage';

interface ProfilePageProps {
  themePref: ThemePref;
  onThemePref: (pref: ThemePref) => void;
}

function SectionTitle({ children }: { children: ReactNode }) {
  return (
    <h2 className="mt-[26px] text-[14px] font-semibold text-foreground">
      {children}
    </h2>
  );
}

function PrefRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex min-h-[52px] items-center justify-between gap-3 border-b border-border py-2">
      <div className="text-[14.5px] font-medium text-foreground">{label}</div>
      {children}
    </div>
  );
}

/** 46×28 switch (21d): accent track + dark knob when on */
function AreaSwitch({
  label,
  icon,
  on,
  disabled,
  onToggle,
}: {
  label: string;
  icon: string;
  on: boolean;
  disabled: boolean;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      disabled={disabled}
      onClick={onToggle}
      className="flex w-full cursor-pointer items-center gap-3 border-b border-border py-[13px] text-left disabled:cursor-default"
    >
      <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth={1.8}
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
        className="flex-none text-muted-foreground"
      >
        <path d={icon} />
      </svg>
      <span className="min-w-0 flex-1 text-[14.5px] font-medium text-foreground">
        {label}
      </span>
      <span
        aria-hidden="true"
        className={cn(
          'flex h-7 w-[46px] flex-none rounded-full p-[3px] motion-safe:transition-colors motion-safe:duration-150',
          on ? 'justify-end bg-acc' : 'justify-start bg-chip',
          disabled && 'opacity-50',
        )}
      >
        <span
          className={cn(
            'h-[22px] w-[22px] rounded-full',
            on ? 'bg-[#141414]' : 'bg-muted-foreground',
          )}
        />
      </span>
    </button>
  );
}

type ProfileView = 'main' | 'name' | 'weeklyGoals' | 'dietGoal';

/**
 * Perfil — Redesign 21d: personal data, the areas in use (same selection as
 * the first-access picker), goals of the enabled areas, app preferences and
 * the account (Strava, password, logout). Reached from the mobile tab bar
 */
export default function ProfilePage({
  themePref,
  onThemePref,
}: ProfilePageProps) {
  const { t } = useTranslation(['nav', 'auth', 'today']);
  const { user, logout, setUser } = useAuth();
  const { areas, has, save: saveAreas, error: areasError } = useAreas();
  const { goals, saveWeekly, saveDaily } = useUserGoals();
  const [view, setView] = useState<ProfileView>('main');
  const { language, setLanguage } = useAppLanguage();
  const initials = user?.firstName
    ? user.firstName.slice(0, 2).toUpperCase()
    : '—';
  const themes: [ThemePref, string][] = THEME_OPTIONS.map(([k, key]) => [
    k,
    t(`common:${key}`),
  ]);

  const [confirmingDisconnect, setConfirmingDisconnect] = useState(false);
  const [disconnecting, setDisconnecting] = useState(false);
  const [disconnectError, setDisconnectError] = useState<string | null>(null);

  const disconnectStrava = async () => {
    if (disconnecting) return;
    setDisconnecting(true);
    setDisconnectError(null);
    try {
      const res = await apiFetch('/strava/connect', { method: 'DELETE' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const { accountDeleted } = (await res.json()) as {
        accountDeleted: boolean;
      };
      // a Strava-only account (no password) is deleted outright, since
      // nothing would be left to log in with — the server already cleared
      // the session cookie, this drops the local state
      if (accountDeleted) {
        await logout();
        return;
      }
      setUser(user ? { ...user, hasStravaAccount: false } : null);
      setConfirmingDisconnect(false);
    } catch {
      setDisconnectError(t('profile.disconnectError'));
    } finally {
      setDisconnecting(false);
    }
  };

  const [addingPassword, setAddingPassword] = useState(false);
  const [pwEmail, setPwEmail] = useState('');
  const [pwPassword, setPwPassword] = useState('');
  const [pwConfirmPassword, setPwConfirmPassword] = useState('');
  const [pwSubmitting, setPwSubmitting] = useState(false);
  const [pwError, setPwError] = useState<string | null>(null);
  const [pwSuccess, setPwSuccess] = useState(false);

  const openAddPassword = () => {
    setAddingPassword(true);
    setPwError(null);
    setPwSuccess(false);
  };

  const cancelAddPassword = () => {
    setAddingPassword(false);
    setPwEmail('');
    setPwPassword('');
    setPwConfirmPassword('');
    setPwError(null);
  };

  const submitAddPassword = async (e: FormEvent) => {
    e.preventDefault();
    if (pwSubmitting) return;
    setPwError(null);
    if (pwPassword !== pwConfirmPassword) {
      setPwError(t('auth:login.passwordMismatch'));
      return;
    }
    setPwSubmitting(true);
    try {
      const res = await apiFetch('/auth/set-password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: pwEmail, password: pwPassword }),
      });
      if (!res.ok) {
        if (res.status === 409) setPwError(t('auth:login.emailInUse'));
        else setPwError(t('auth:login.genericError'));
        return;
      }
      setUser(await res.json());
      setAddingPassword(false);
      setPwEmail('');
      setPwPassword('');
      setPwConfirmPassword('');
      setPwSuccess(true);
    } catch {
      setPwError(t('auth:login.genericError'));
    } finally {
      setPwSubmitting(false);
    }
  };

  const toggleArea = (id: Area) =>
    void saveAreas(
      AREAS.map((a) => a.id).filter((a) => (a === id ? !has(a) : has(a))),
    );

  const goalRows = [
    has('RUN') && {
      key: 'RUN',
      name: t('tabs.run'),
      detail: t('profile.goalRunDetail'),
      value: goals ? `${goals.weeklyRunKmGoal} km` : '—',
      view: 'weeklyGoals' as const,
    },
    has('GYM') && {
      key: 'GYM',
      name: t('tabs.gym'),
      detail: t('profile.goalGymDetail'),
      value: goals ? String(goals.weeklyWorkoutsGoal) : '—',
      view: 'weeklyGoals' as const,
    },
    has('DIET') && {
      key: 'DIET',
      name: t('tabs.diet'),
      detail: t('profile.goalDietDetail'),
      value: goals ? `${formatNumber(goals.dailyKcalGoal)} kcal` : '—',
      view: 'dietGoal' as const,
    },
  ].filter((row) => !!row);

  const back = () => setView('main');
  const detail =
    view === 'name' ? (
      <EditNamePage onBack={back} />
    ) : view === 'weeklyGoals' && goals ? (
      <WeeklyGoalsPage
        goals={goals}
        areas={areas}
        onBack={back}
        onSave={async (next) => {
          await saveWeekly(next);
          back();
        }}
      />
    ) : view === 'dietGoal' && goals ? (
      <GoalPage
        goal={goals}
        onBack={back}
        onSave={async (next) => {
          await saveDaily(next);
          back();
        }}
      />
    ) : null;

  return (
    <DrillStack depth={detail ? 1 : 0} viewKey={detail ? view : 'main'}>
      {detail ?? (
        <div className="px-[22px] pt-2 pb-[44px] tabular-nums md:max-w-[560px] md:px-[34px] md:pt-[30px] md:pb-[34px]">
          {/* on mobile the section title lives in the header (MobileChrome) */}
          <h1 className="hidden text-[19px] font-semibold tracking-[-.01em] text-foreground md:block">
            {t('profile.title')}
          </h1>

          <button
            type="button"
            onClick={() => setView('name')}
            className="flex w-full cursor-pointer items-center gap-3.5 border-b border-border pb-5 text-left md:mt-5"
          >
            {user?.profileImgUrl ? (
              <img
                src={user.profileImgUrl}
                alt=""
                width={48}
                height={48}
                className="h-12 w-12 flex-none rounded-full object-cover outline outline-1 -outline-offset-1 outline-black/10 dark:outline-white/10"
              />
            ) : (
              <span className="flex h-12 w-12 flex-none items-center justify-center rounded-full bg-chip text-[15px] font-semibold text-foreground">
                {initials}
              </span>
            )}
            <span className="min-w-0 flex-1">
              <span className="block truncate text-[15.5px] font-medium text-foreground">
                {user?.firstName ?? t('runnerFallback')}
              </span>
              <span className="mt-0.5 block truncate text-[12.5px] text-muted-foreground">
                {user?.email ?? t('profile.noEmail')}
              </span>
            </span>
            <ChevronRight
              className="h-4 w-4 flex-none text-muted-foreground"
              strokeWidth={2}
            />
          </button>

          <SectionTitle>{t('profile.areas')}</SectionTitle>
          <div className="mt-1.5">
            {AREAS.map((area) => {
              const on = has(area.id);
              return (
                <AreaSwitch
                  key={area.id}
                  label={t(area.labelKey)}
                  icon={area.icon}
                  on={on}
                  // at least one area stays on — none is the "not chosen yet" state
                  disabled={on && areas.length === 1}
                  onToggle={() => toggleArea(area.id)}
                />
              );
            })}
          </div>
          <p
            className={cn(
              'mt-2.5 text-[12px] leading-[1.5] text-pretty',
              areasError ? 'text-neg' : 'text-muted-foreground',
            )}
          >
            {areasError ? t('profile.saveError') : t('profile.areasHint')}
          </p>

          <SectionTitle>{t('profile.goals')}</SectionTitle>
          <div className="mt-1.5">
            {goalRows.map((row) => (
              <button
                key={row.key}
                type="button"
                onClick={() => setView(row.view)}
                disabled={!goals}
                className="flex w-full cursor-pointer items-center gap-3 border-b border-border py-[13px] text-left disabled:cursor-default"
              >
                <span className="min-w-0 flex-1">
                  <span className="block text-[14.5px] font-medium text-foreground">
                    {row.name}
                  </span>
                  <span className="mt-0.5 block text-[12px] text-muted-foreground">
                    {row.detail}
                  </span>
                </span>
                <span className="font-mono text-[14.5px] font-medium text-foreground">
                  {row.value}
                </span>
                <ChevronRight
                  className="h-4 w-4 flex-none text-muted-foreground"
                  strokeWidth={2}
                />
              </button>
            ))}
          </div>

          <SectionTitle>{t('profile.app')}</SectionTitle>
          <div className="mt-1.5">
            <PrefRow label={t('profile.theme')}>
              <SegmentedControl
                size="compact"
                items={themes}
                active={themePref}
                onPick={onThemePref}
              />
            </PrefRow>
            <PrefRow label={t('profile.language')}>
              <SegmentedControl
                size="compact"
                items={[
                  ['pt', 'PT'],
                  ['en', 'EN'],
                ]}
                active={language}
                onPick={setLanguage}
              />
            </PrefRow>
            <PrefRow label={t('profile.units')}>
              <span className="text-[13.5px] text-muted-foreground">
                {t('profile.unitsKm')}
              </span>
            </PrefRow>
          </div>

          <SectionTitle>{t('profile.account')}</SectionTitle>
          <div className="mt-1.5 border-b border-border py-[13px]">
            <div className="flex items-center justify-between gap-2.5">
              <div className="min-w-0">
                <div className="text-[14.5px] font-medium text-foreground">
                  Strava
                </div>
                <div className="mt-0.5 flex items-center gap-1.5">
                  <span
                    className={`h-[7px] w-[7px] rounded-full ${user?.hasStravaAccount ? 'bg-pos' : 'bg-muted-foreground'}`}
                  />
                  <span className="text-[12px] text-muted-foreground">
                    {user?.hasStravaAccount
                      ? t('profile.stravaConnected')
                      : t('profile.stravaNotConnected')}
                  </span>
                </div>
              </div>
              {user?.hasStravaAccount ? (
                <button
                  type="button"
                  onClick={() => setConfirmingDisconnect(true)}
                  className="shrink-0 cursor-pointer rounded-[9px] bg-chip px-[13px] py-1.5 text-[12.5px] font-medium text-foreground hover:bg-grid-ax"
                >
                  {t('profile.disconnect')}
                </button>
              ) : null}
            </div>

            {!user?.hasStravaAccount && (
              <ConnectWithStrava
                href={`${API_BASE_URL}/strava/connect`}
                className="mt-3"
              />
            )}

            {confirmingDisconnect && (
              <div className="mt-3 flex items-center justify-between gap-3 rounded-[10px] bg-chip px-3 py-2.5">
                <span className="text-[12.5px] text-foreground">
                  {user?.hasPassword
                    ? t('profile.disconnectConfirm')
                    : t('profile.disconnectConfirmDeleteAccount')}
                </span>
                <div className="flex shrink-0 items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setConfirmingDisconnect(false)}
                    disabled={disconnecting}
                    className="cursor-pointer rounded-[8px] px-2.5 py-1 text-[12.5px] font-medium text-muted-foreground hover:text-foreground"
                  >
                    {t('profile.disconnectConfirmCancel')}
                  </button>
                  <button
                    type="button"
                    onClick={() => void disconnectStrava()}
                    disabled={disconnecting}
                    className="cursor-pointer rounded-[8px] bg-neg px-2.5 py-1 text-[12.5px] font-medium text-white disabled:opacity-70"
                  >
                    {t('profile.disconnectConfirmYes')}
                  </button>
                </div>
              </div>
            )}

            {disconnectError && (
              <p className="mt-2 text-[12px] text-neg">{disconnectError}</p>
            )}
          </div>

          {!user?.hasPassword && (
            <div className="border-b border-border py-[13px]">
              {!addingPassword ? (
                <div className="flex items-center justify-between gap-2.5">
                  <div className="min-w-0">
                    <div className="text-[14.5px] font-medium text-foreground">
                      {t('profile.passwordRow')}
                    </div>
                    <p className="mt-0.5 text-[12px] text-muted-foreground">
                      {t('profile.passwordSubtitle')}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={openAddPassword}
                    className="shrink-0 cursor-pointer rounded-[9px] bg-chip px-[13px] py-1.5 text-[12.5px] font-medium text-foreground hover:bg-grid-ax"
                  >
                    {t('profile.addPassword')}
                  </button>
                </div>
              ) : (
                <form
                  onSubmit={(e) => void submitAddPassword(e)}
                  className="flex flex-col gap-2.5"
                >
                  <div className="text-[14.5px] font-medium text-foreground">
                    {t('profile.passwordRow')}
                  </div>
                  <p className="text-[12px] leading-[1.5] text-muted-foreground">
                    {t('profile.addPasswordEmailHint')}
                  </p>
                  <input
                    type="email"
                    value={pwEmail}
                    onChange={(e) => setPwEmail(e.target.value)}
                    placeholder={t('auth:login.emailPlaceholder')}
                    autoComplete="email"
                    required
                    className="w-full rounded-[11px] border border-border bg-transparent px-3.5 py-[11px] text-[16px] text-foreground outline-none placeholder:text-muted-foreground focus:border-acc md:text-[14px]"
                  />
                  <PasswordInput
                    value={pwPassword}
                    onChange={(e) => setPwPassword(e.target.value)}
                    placeholder={t('auth:login.passwordPlaceholder')}
                    autoComplete="new-password"
                    minLength={8}
                    required
                    showLabel={t('auth:login.showPassword')}
                    hideLabel={t('auth:login.hidePassword')}
                  />
                  <PasswordInput
                    value={pwConfirmPassword}
                    onChange={(e) => setPwConfirmPassword(e.target.value)}
                    placeholder={t('auth:login.confirmPasswordPlaceholder')}
                    autoComplete="new-password"
                    minLength={8}
                    required
                    showLabel={t('auth:login.showPassword')}
                    hideLabel={t('auth:login.hidePassword')}
                  />

                  {pwError && <p className="text-[12px] text-neg">{pwError}</p>}

                  <div className="flex items-center gap-2">
                    <button
                      type="submit"
                      disabled={pwSubmitting}
                      className="press cursor-pointer rounded-[9px] bg-acc px-[13px] py-1.5 text-[12.5px] font-semibold text-acc-fg disabled:cursor-default disabled:opacity-70"
                    >
                      {pwSubmitting
                        ? t('profile.addPasswordSubmitting')
                        : t('profile.addPasswordSubmit')}
                    </button>
                    <button
                      type="button"
                      onClick={cancelAddPassword}
                      disabled={pwSubmitting}
                      className="cursor-pointer rounded-[9px] px-2.5 py-1.5 text-[12.5px] font-medium text-muted-foreground hover:text-foreground"
                    >
                      {t('profile.disconnectConfirmCancel')}
                    </button>
                  </div>
                </form>
              )}
            </div>
          )}

          {pwSuccess && (
            <p className="mt-2.5 text-[12.5px] text-pos">
              {t('profile.addPasswordSuccess')}
            </p>
          )}

          <button
            onClick={() => void logout()}
            className="flex min-h-[52px] w-full cursor-pointer items-center gap-2 border-b border-border text-[14.5px] font-medium text-neg"
          >
            <LogOut className="h-4 w-4" strokeWidth={1.8} />
            {t('logOut')}
          </button>

          <div className="mt-5 flex justify-center gap-4 text-[12.5px] text-muted-foreground">
            <a
              href="/privacidade"
              className="underline-offset-4 hover:underline"
            >
              {t('profile.privacy')}
            </a>
            <a href="/suporte" className="underline-offset-4 hover:underline">
              {t('profile.support')}
            </a>
          </div>
        </div>
      )}
    </DrillStack>
  );
}

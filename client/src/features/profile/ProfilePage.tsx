import { useState } from 'react';
import type { FormEvent } from 'react';
import { LogOut } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import SegmentedControl from '@/components/SegmentedControl';
import PasswordInput from '@/components/PasswordInput';
import { useAuth } from '@/features/auth/AuthContext';
import { useAppLanguage } from '@/i18n/useAppLanguage';
import { apiFetch } from '@/lib/api';
import { API_BASE_URL } from '@/lib/apiUrl';
import { THEME_OPTIONS, type ThemePref } from '@/lib/theme';

interface ProfilePageProps {
  themePref: ThemePref;
  onThemePref: (pref: ThemePref) => void;
}

function PrefRow({
  label,
  children,
  last,
}: {
  label: string;
  children: React.ReactNode;
  last?: boolean;
}) {
  return (
    <div
      className={`flex min-h-[52px] items-center justify-between gap-3 py-2 ${
        last ? '' : 'border-b border-border'
      }`}
    >
      <div className="text-[13.5px] font-medium text-foreground">{label}</div>
      {children}
    </div>
  );
}

/** account/preferences page — reached via the mobile tab bar's "Profile" tab */
export default function ProfilePage({
  themePref,
  onThemePref,
}: ProfilePageProps) {
  const { t } = useTranslation(['nav', 'auth']);
  const { user, logout, setUser } = useAuth();
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

  return (
    <div className="mx-auto max-w-[560px] px-5 pt-[18px] pb-[44px] md:px-[34px] md:pt-[30px] md:pb-[34px]">
      {/* on mobile the section title lives in the app bar (MobileChrome) */}
      <h1 className="hidden text-[19px] font-semibold tracking-[-.01em] text-foreground md:block">
        {t('profile.title')}
      </h1>

      <div className="flex items-center gap-3.5 rounded-[14px] border border-border bg-card p-4 md:mt-5">
        {user?.profileImgUrl ? (
          <img
            src={user.profileImgUrl}
            alt=""
            width={52}
            height={52}
            className="h-[52px] w-[52px] flex-none rounded-full object-cover outline outline-1 -outline-offset-1 outline-black/10 dark:outline-white/10"
          />
        ) : (
          <div className="flex h-[52px] w-[52px] flex-none items-center justify-center rounded-full bg-chip text-[17px] font-semibold text-foreground">
            {initials}
          </div>
        )}
        <div className="min-w-0 flex-1">
          <div className="truncate text-[15px] font-semibold text-foreground">
            {user?.firstName ?? t('runnerFallback')}
          </div>
        </div>
      </div>

      <div className="mt-3.5 rounded-[14px] border border-border bg-card p-4">
        <div className="mb-2.5 text-[11.5px] font-medium tracking-[.05em] text-muted-foreground">
          {t('profile.stravaTitle')}
        </div>
        <div className="flex items-center justify-between gap-2.5">
          <div className="flex items-center gap-1.5">
            <span
              className={`h-[7px] w-[7px] rounded-full ${user?.hasStravaAccount ? 'bg-pos' : 'bg-muted-foreground'}`}
            />
            <p className="text-[13px] text-foreground">
              {user?.hasStravaAccount
                ? t('profile.stravaConnected')
                : t('profile.stravaNotConnected')}
            </p>
          </div>
          {user?.hasStravaAccount ? (
            <button
              type="button"
              onClick={() => setConfirmingDisconnect(true)}
              className="shrink-0 cursor-pointer rounded-[9px] bg-chip px-[13px] py-1.5 text-[12.5px] font-medium text-foreground hover:bg-grid-ax"
            >
              {t('profile.disconnect')}
            </button>
          ) : (
            <a
              href={`${API_BASE_URL}/strava/connect`}
              className="shrink-0 cursor-pointer rounded-[9px] bg-chip px-[13px] py-1.5 text-[12.5px] font-medium text-foreground hover:bg-grid-ax"
            >
              {t('profile.connectStrava')}
            </a>
          )}
        </div>

        {confirmingDisconnect && (
          <div className="mt-3 flex items-center justify-between gap-3 rounded-[10px] bg-chip px-3 py-2.5">
            <span className="text-[12.5px] text-foreground">
              {t('profile.disconnectConfirm')}
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
        <div className="mt-3.5 rounded-[14px] border border-border bg-card p-4">
          <div className="mb-2.5 text-[11.5px] font-medium tracking-[.05em] text-muted-foreground">
            {t('profile.passwordTitle')}
          </div>

          {!addingPassword ? (
            <div className="flex items-center justify-between gap-2.5">
              <p className="text-[13px] text-foreground">
                {t('profile.passwordSubtitle')}
              </p>
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
                  className="press cursor-pointer rounded-[9px] bg-acc px-[13px] py-1.5 text-[12.5px] font-semibold text-white disabled:cursor-default disabled:opacity-70"
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
        <p className="mt-2.5 px-1 text-[12.5px] text-pos">
          {t('profile.addPasswordSuccess')}
        </p>
      )}

      <div className="mt-3.5 rounded-[14px] border border-border bg-card px-4 py-1">
        <PrefRow label={t('profile.units')}>
          <span className="text-[13px] text-muted-foreground">
            {t('profile.unitsKm')}
          </span>
        </PrefRow>
        <PrefRow label={t('profile.theme')}>
          <SegmentedControl
            size="compact"
            items={themes}
            active={themePref}
            onPick={onThemePref}
          />
        </PrefRow>
        <PrefRow label={t('profile.language')} last>
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
      </div>

      <button
        onClick={() => void logout()}
        className="mt-3.5 flex min-h-[52px] w-full cursor-pointer items-center justify-center gap-2 rounded-[14px] border border-border bg-card text-[14px] font-semibold text-neg"
      >
        <LogOut className="h-4 w-4" strokeWidth={1.8} />
        {t('logOut')}
      </button>
    </div>
  );
}

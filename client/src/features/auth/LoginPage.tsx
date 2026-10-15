import { useEffect, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { ArrowRight, Loader2, Lock } from 'lucide-react';
import { Trans, useTranslation } from 'react-i18next';
import { API_BASE_URL } from '@/lib/apiUrl';
import { apiFetch } from '@/lib/api';
import SegmentedControl from '@/components/SegmentedControl';
import PasswordInput from '@/components/PasswordInput';
import { useAppLanguage } from '@/i18n/useAppLanguage';
import { useAuth } from '@/features/auth/AuthContext';
import { THEME_OPTIONS, type ThemePref } from '@/lib/theme';
import HeroTrace from '@/features/auth/HeroTrace';

type Mode = 'login' | 'register';
type View = 'main' | 'form' | 'forgot';

// TODO: swap the button for Strava's official "Connect with Strava" asset
// (SVG/PNG from developers.strava.com/guidelines) once it's vendored into
// the repo — this mirrors the required brand orange (#FC4C02) and wordmark
// in the meantime. #FC4C02 is Strava's brand color: fixed in both themes,
// deliberately not tokenized.

function HowItWorksPopover() {
  const { t } = useTranslation('auth');
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node))
        setOpen(false);
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onPointerDown);
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('mousedown', onPointerDown);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [open]);

  return (
    <div ref={ref} className="relative self-center md:self-start">
      {open && (
        <div className="absolute bottom-full left-1/2 mb-2.5 w-[300px] -translate-x-1/2 rounded-xl border border-border bg-popover p-4 text-left text-[12px] leading-[1.55] text-popover-foreground shadow-lg md:left-0 md:translate-x-0">
          {t('login.howItWorks.body')}
        </div>
      )}
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="text-[11.5px] font-medium text-acc-tx hover:underline"
      >
        {t('login.howItWorks.trigger')}
      </button>
    </div>
  );
}

interface LoginPageProps {
  themePref: ThemePref;
  onThemePref: (pref: ThemePref) => void;
}

export default function LoginPage({ themePref, onThemePref }: LoginPageProps) {
  const { t } = useTranslation('auth');
  const { language, setLanguage } = useAppLanguage();
  const { setUser } = useAuth();
  const [connecting, setConnecting] = useState(false);
  const [authError, setAuthError] = useState(() =>
    new URLSearchParams(window.location.search).has('auth_error'),
  );

  const [view, setView] = useState<View>('main');
  const [mode, setMode] = useState<Mode>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [firstName, setFirstName] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const [forgotEmail, setForgotEmail] = useState('');
  const [forgotSubmitting, setForgotSubmitting] = useState(false);
  const [forgotSuccess, setForgotSuccess] = useState(false);

  useEffect(() => {
    // keep the notice in state but drop ?auth_error=1 from the address bar
    if (authError) {
      window.history.replaceState(null, '', window.location.pathname);
    }
  }, [authError]);

  const connect = () => {
    if (connecting) return;
    setAuthError(false);
    setConnecting(true);
    window.location.href = `${API_BASE_URL}/strava/auth`;
  };

  const openForm = () => {
    setView('form');
    setMode('login');
    setFormError(null);
    setAuthError(false);
  };

  // wrong credentials mean whatever's in these fields was bad — clearing
  // them (rather than leaving the rejected values sitting there) avoids
  // the user re-submitting the same typo, same on "back": a stale
  // email/password shouldn't survive to the next time the form opens
  const clearCredentialFields = () => {
    setEmail('');
    setPassword('');
    setConfirmPassword('');
  };

  const goBack = () => {
    if (view === 'forgot') {
      // came from the login form, not the Strava-first screen — return
      // there instead of all the way back to 'main'
      setView('form');
      setForgotSuccess(false);
      return;
    }
    setView('main');
    clearCredentialFields();
  };

  const openForgotPassword = () => {
    setView('forgot');
    setFormError(null);
    setForgotEmail('');
    setForgotSuccess(false);
  };

  const submitForgotPassword = async (e: FormEvent) => {
    e.preventDefault();
    if (forgotSubmitting) return;
    setForgotSubmitting(true);
    try {
      await apiFetch('/auth/forgot-password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: forgotEmail }),
      });
    } finally {
      // always show the same success state, regardless of the response —
      // same anti-enumeration principle as the backend
      setForgotSuccess(true);
      setForgotSubmitting(false);
    }
  };

  const submitForm = async (e: FormEvent) => {
    e.preventDefault();
    if (submitting) return;
    setFormError(null);
    if (mode === 'register' && password !== confirmPassword) {
      setFormError(t('login.passwordMismatch'));
      return;
    }
    setSubmitting(true);
    try {
      const res = await apiFetch(
        mode === 'login' ? '/auth/login' : '/auth/register',
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(
            mode === 'login'
              ? { email, password }
              : { email, password, firstName: firstName.trim() || undefined },
          ),
        },
      );
      if (!res.ok) {
        if (res.status === 401) {
          setFormError(t('login.invalidCredentials'));
          clearCredentialFields();
        } else if (res.status === 409) setFormError(t('login.emailInUse'));
        else setFormError(t('login.genericError'));
        return;
      }
      setUser(await res.json());
    } catch {
      setFormError(t('login.genericError'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="flex min-h-dvh flex-col md:h-screen md:min-h-0 md:flex-row">
      {/* Hero — editorial, always dark regardless of app theme; on mobile it
          fills the space above the bottom sheet (top padding tracks the
          real status bar / notch via env(safe-area-inset-top), plus a
          small fixed cushion, instead of a flat guess) */}
      <div className="flex min-w-0 flex-1 flex-col bg-[#0B0F17] px-[26px] pt-[calc(env(safe-area-inset-top)+20px)] md:flex-[1.25] md:px-[44px] md:pt-[36px]">
        <div className="flex items-center gap-[10px]">
          <div className="flex h-[30px] w-[30px] items-center justify-center rounded-[9px] bg-acc text-[12px] font-bold text-white">
            ST
          </div>
          <span className="text-[14px] font-semibold text-[#EDF1F7]">
            SoTreina
          </span>
        </div>

        <div className="mt-4 py-8 md:my-auto md:py-10">
          <h1 className="text-[33px] leading-[1.18] font-bold tracking-[-.025em] text-[#EDF1F7] md:text-[40px] md:leading-[1.16]">
            <Trans
              t={t}
              i18nKey="login.headline"
              components={{ br: <br />, acc: <span className="text-acc" /> }}
            />
          </h1>
          <p className="mt-3.5 text-[14px] leading-[1.5] text-[#8A93A5] md:mt-4 md:text-[14.5px]">
            {t('login.subheadline')}
          </p>
        </div>

        <HeroTrace />
      </div>

      {/* Sign-in — mobile: bottom sheet anchored under the hero; desktop:
          right panel. Follows the app theme either way.
          Desktop seam treatment against the always-dark hero (md+ only):
          dark matches its #0B0F17 + hairline border; light keeps bg-card with
          an inset shadow as if the dark panel cast it */}
      <div className="relative flex min-h-[54dvh] w-full flex-none flex-col rounded-t-[26px] bg-card px-[26px] pt-[28px] pb-[max(18px,env(safe-area-inset-bottom))] text-center dark:border-t dark:border-white/[.09] dark:bg-[#0F1522] md:min-h-0 md:w-[480px] md:justify-center md:rounded-none md:px-[52px] md:py-[48px] md:text-left md:shadow-[inset_20px_0_30px_-22px_rgba(8,12,20,.42)] md:dark:border-t-0 md:dark:border-l md:dark:border-white/[.09] md:dark:bg-[#0B0F17] md:dark:shadow-none">
        <div className="absolute right-[26px] top-[26px] hidden items-center gap-2 md:flex">
          <SegmentedControl
            size="compact"
            items={THEME_OPTIONS.map(
              ([k, key]) => [k, t(`common:${key}`)] as [ThemePref, string],
            )}
            active={themePref}
            onPick={onThemePref}
          />
          <SegmentedControl
            size="compact"
            items={[
              ['pt', 'PT'],
              ['en', 'EN'],
            ]}
            active={language}
            onPick={setLanguage}
          />
        </div>

        {(view === 'form' || view === 'forgot') && (
          <div className="flex justify-start">
            <button
              type="button"
              onClick={goBack}
              className="mb-4 cursor-pointer rounded-[9px] bg-chip py-[7px] pr-[13px] pl-2.5 text-[13px] font-medium text-foreground hover:bg-grid-ax"
            >
              {t('login.back')}
            </button>
          </div>
        )}

        <h2 className="text-[20px] font-semibold tracking-[-.01em] text-foreground">
          {view === 'main'
            ? t('login.signIn')
            : view === 'forgot'
              ? t('login.forgotTitle')
              : mode === 'login'
                ? t('login.tabLogin')
                : t('login.tabRegister')}
        </h2>
        <p className="mt-[7px] text-[13px] leading-[1.55] text-muted-foreground">
          {view === 'main'
            ? t('login.signInSubtitle')
            : view === 'forgot'
              ? t('login.forgotSubtitle')
              : mode === 'login'
                ? t('login.formSubtitleLogin')
                : t('login.formSubtitleRegister')}
        </p>

        {view === 'form' && (
          <>
            <div className="mt-[22px] flex justify-center md:justify-start">
              <SegmentedControl
                size="compact"
                items={[
                  ['login', t('login.tabLogin')],
                  ['register', t('login.tabRegister')],
                ]}
                active={mode}
                onPick={(m) => {
                  setMode(m);
                  setFormError(null);
                }}
              />
            </div>

            <form
              onSubmit={(e) => void submitForm(e)}
              className="mt-4 flex flex-col gap-2.5 text-left"
            >
              {mode === 'register' && (
                <input
                  type="text"
                  value={firstName}
                  onChange={(e) => setFirstName(e.target.value)}
                  placeholder={t('login.namePlaceholder')}
                  autoComplete="given-name"
                  className="w-full rounded-[11px] border border-border bg-transparent px-3.5 py-[11px] text-[16px] text-foreground outline-none placeholder:text-muted-foreground focus:border-acc md:text-[14px]"
                />
              )}
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder={t('login.emailPlaceholder')}
                autoComplete="email"
                required
                className="w-full rounded-[11px] border border-border bg-transparent px-3.5 py-[11px] text-[16px] text-foreground outline-none placeholder:text-muted-foreground focus:border-acc md:text-[14px]"
              />
              <PasswordInput
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder={t('login.passwordPlaceholder')}
                autoComplete={
                  mode === 'login' ? 'current-password' : 'new-password'
                }
                minLength={mode === 'register' ? 8 : undefined}
                required
                showLabel={t('login.showPassword')}
                hideLabel={t('login.hidePassword')}
              />
              {mode === 'register' && (
                <PasswordInput
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder={t('login.confirmPasswordPlaceholder')}
                  autoComplete="new-password"
                  minLength={8}
                  required
                  showLabel={t('login.showPassword')}
                  hideLabel={t('login.hidePassword')}
                />
              )}

              {mode === 'login' && (
                <div className="flex justify-end">
                  <button
                    type="button"
                    onClick={openForgotPassword}
                    className="text-[12px] font-medium text-acc-tx hover:underline"
                  >
                    {t('login.forgotPassword')}
                  </button>
                </div>
              )}

              {formError && <p className="text-[12px] text-neg">{formError}</p>}

              <button
                type="submit"
                disabled={submitting}
                className="press mt-1 flex w-full items-center justify-center gap-[9px] rounded-[12px] bg-acc py-[13px] text-[14.5px] font-semibold text-white disabled:cursor-default disabled:opacity-80 md:rounded-[11px]"
              >
                {submitting ? (
                  <>
                    <Loader2
                      size={15}
                      className="animate-spin"
                      strokeWidth={2}
                    />
                    {mode === 'login'
                      ? t('login.submittingLogin')
                      : t('login.submittingRegister')}
                  </>
                ) : mode === 'login' ? (
                  t('login.submitLogin')
                ) : (
                  t('login.submitRegister')
                )}
              </button>
            </form>
          </>
        )}

        {view === 'forgot' &&
          (forgotSuccess ? (
            <p className="mt-[22px] text-[13px] leading-[1.55] text-foreground">
              {t('login.forgotSuccess')}
            </p>
          ) : (
            <form
              onSubmit={(e) => void submitForgotPassword(e)}
              className="mt-4 flex flex-col gap-2.5 text-left"
            >
              <input
                type="email"
                value={forgotEmail}
                onChange={(e) => setForgotEmail(e.target.value)}
                placeholder={t('login.emailPlaceholder')}
                autoComplete="email"
                required
                className="w-full rounded-[11px] border border-border bg-transparent px-3.5 py-[11px] text-[16px] text-foreground outline-none placeholder:text-muted-foreground focus:border-acc md:text-[14px]"
              />
              <button
                type="submit"
                disabled={forgotSubmitting}
                className="press mt-1 flex w-full items-center justify-center gap-[9px] rounded-[12px] bg-acc py-[13px] text-[14.5px] font-semibold text-white disabled:cursor-default disabled:opacity-80 md:rounded-[11px]"
              >
                {forgotSubmitting ? (
                  <>
                    <Loader2
                      size={15}
                      className="animate-spin"
                      strokeWidth={2}
                    />
                    {t('login.forgotSubmitting')}
                  </>
                ) : (
                  t('login.forgotSubmit')
                )}
              </button>
            </form>
          ))}

        {view === 'main' && (
          <div className="mt-[22px]">
            {authError && (
              <p className="mb-[14px] text-[12px] text-neg">
                {t('login.authError')}
              </p>
            )}

            <button
              type="button"
              onClick={connect}
              disabled={connecting}
              className="flex w-full items-center justify-center gap-[9px] rounded-[12px] bg-[#FC4C02] py-[15px] text-[15px] font-semibold text-white transition-colors hover:bg-[#E04300] disabled:cursor-default disabled:opacity-80 disabled:hover:bg-[#FC4C02] md:rounded-[11px] md:py-[13px] md:text-[14.5px]"
            >
              {connecting ? (
                <>
                  <Loader2 size={15} className="animate-spin" strokeWidth={2} />
                  {t('login.connecting')}
                </>
              ) : (
                <>
                  {t('login.connect')}
                  <ArrowRight size={15} strokeWidth={2} />
                </>
              )}
            </button>

            <p className="mt-[11px] text-[11.5px] text-muted-foreground">
              {t('login.redirectNotice')}
            </p>
          </div>
        )}

        <div className="mt-auto flex flex-col items-center gap-3 pt-6 md:absolute md:bottom-[26px] md:left-[52px] md:right-[52px] md:mt-0 md:pt-0 md:items-stretch">
          {view === 'main' && (
            <button
              type="button"
              onClick={openForm}
              className="self-center text-center text-[14.5px] leading-[1.5] md:self-start md:text-left"
            >
              <span className="text-muted-foreground">
                {t('login.emailCtaPrefix')}{' '}
              </span>
              <span className="font-medium text-acc-tx hover:underline">
                {t('login.emailCtaLink')}
              </span>
            </button>
          )}
          <div className="flex items-start justify-center gap-[7px] text-muted-foreground md:justify-start">
            <Lock size={14} strokeWidth={1.7} className="mt-px shrink-0" />
            <span className="text-[11px] leading-[1.5]">
              {t('login.readOnlyNotice')}
            </span>
          </div>
          <HowItWorksPopover />
        </div>
      </div>
    </div>
  );
}

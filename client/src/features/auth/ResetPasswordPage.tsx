import { useState } from 'react';
import type { FormEvent } from 'react';
import { Loader2 } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { apiFetch } from '@/lib/api';
import SegmentedControl from '@/components/SegmentedControl';
import PasswordInput from '@/components/PasswordInput';
import { useAppLanguage } from '@/i18n/useAppLanguage';
import { THEME_OPTIONS, type ThemePref } from '@/lib/theme';
import { Logo } from '@/components/Logo';

type Status = 'form' | 'success' | 'invalid';

interface ResetPasswordPageProps {
  themePref: ThemePref;
  onThemePref: (pref: ThemePref) => void;
}

// Reached only via the emailed reset link (/redefinir-senha?token=...) — a
// standalone page, independent of AuthContext, since it must work whether or
// not the visitor currently has a session.
export default function ResetPasswordPage({
  themePref,
  onThemePref,
}: ResetPasswordPageProps) {
  const { t } = useTranslation('auth');
  const { language, setLanguage } = useAppLanguage();
  const [token] = useState(() =>
    new URLSearchParams(window.location.search).get('token'),
  );

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [status, setStatus] = useState<Status>(token ? 'form' : 'invalid');
  const [formError, setFormError] = useState<string | null>(null);

  const backToLogin = () => {
    window.location.href = '/';
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (submitting || !token) return;
    setFormError(null);
    if (password !== confirmPassword) {
      setFormError(t('login.passwordMismatch'));
      return;
    }
    setSubmitting(true);
    try {
      const res = await apiFetch('/auth/reset-password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, newPassword: password }),
      });
      if (!res.ok) {
        if (res.status === 400) setStatus('invalid');
        else setFormError(t('login.genericError'));
        return;
      }
      setStatus('success');
    } catch {
      setFormError(t('login.genericError'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="flex min-h-svh items-center justify-center bg-page-bg px-[26px] py-10">
      <div className="relative w-full max-w-[420px] rounded-[18px] border border-border bg-card p-[32px] text-left shadow-sm">
        <div className="absolute right-[20px] top-[20px] hidden items-center gap-2 md:flex">
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

        <div className="flex items-center gap-[10px]">
          <Logo className="text-foreground" />
          <span className="text-[14px] font-semibold text-foreground">
            SoTreina
          </span>
        </div>

        {status === 'invalid' && (
          <div className="mt-6">
            <h2 className="text-[20px] font-semibold tracking-[-.01em] text-foreground">
              {t('login.resetTitle')}
            </h2>
            <p className="mt-[7px] text-[13px] leading-[1.55] text-neg">
              {t('login.resetInvalidToken')}
            </p>
            <button
              type="button"
              onClick={backToLogin}
              className="press mt-5 flex w-full items-center justify-center rounded-[12px] bg-acc py-[13px] text-[14.5px] font-semibold text-acc-fg md:rounded-[11px]"
            >
              {t('login.resetBackToLogin')}
            </button>
          </div>
        )}

        {status === 'success' && (
          <div className="mt-6">
            <h2 className="text-[20px] font-semibold tracking-[-.01em] text-foreground">
              {t('login.resetTitle')}
            </h2>
            <p className="mt-[7px] text-[13px] leading-[1.55] text-pos">
              {t('login.resetSuccess')}
            </p>
            <button
              type="button"
              onClick={backToLogin}
              className="press mt-5 flex w-full items-center justify-center rounded-[12px] bg-acc py-[13px] text-[14.5px] font-semibold text-acc-fg md:rounded-[11px]"
            >
              {t('login.resetBackToLogin')}
            </button>
          </div>
        )}

        {status === 'form' && (
          <div className="mt-6">
            <h2 className="text-[20px] font-semibold tracking-[-.01em] text-foreground">
              {t('login.resetTitle')}
            </h2>
            <p className="mt-[7px] text-[13px] leading-[1.55] text-muted-foreground">
              {t('login.resetSubtitle')}
            </p>
            <form
              onSubmit={(e) => void submit(e)}
              className="mt-4 flex flex-col gap-2.5"
            >
              <PasswordInput
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder={t('login.passwordPlaceholder')}
                autoComplete="new-password"
                minLength={8}
                required
                showLabel={t('login.showPassword')}
                hideLabel={t('login.hidePassword')}
              />
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

              {formError && <p className="text-[12px] text-neg">{formError}</p>}

              <button
                type="submit"
                disabled={submitting}
                className="press mt-1 flex w-full items-center justify-center gap-[9px] rounded-[12px] bg-acc py-[13px] text-[14.5px] font-semibold text-acc-fg disabled:cursor-default disabled:opacity-80 md:rounded-[11px]"
              >
                {submitting ? (
                  <>
                    <Loader2
                      size={15}
                      className="animate-spin"
                      strokeWidth={2}
                    />
                    {t('login.resetSubmitting')}
                  </>
                ) : (
                  t('login.resetSubmit')
                )}
              </button>
            </form>
          </div>
        )}
      </div>
    </div>
  );
}

import { useEffect, useRef, useState } from 'react';
import { Loader2 } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { apiFetch } from '@/lib/api';
import type { AuthUser } from '@/features/auth/AuthContext';

const CODE_LEN = 6;
// mirrors the server's per-account cooldown between codes
const RESEND_COOLDOWN_MS = 60_000;

interface EmailCodeFormProps {
  /** true when no code is on its way yet (Perfil); false right after
   *  register, which already sent the first one */
  sendOnMount: boolean;
  onVerified: (user: AuthUser) => void;
  onSkip: () => void;
}

/**
 * The 6-digit email verification step (spec §3.3), shared by the sign-up flow
 * and Perfil. Never blocking: "Fazer depois" always gets the user out. Submits
 * on its own once the 6th digit lands
 */
export default function EmailCodeForm({
  sendOnMount,
  onVerified,
  onSkip,
}: EmailCodeFormProps) {
  const { t } = useTranslation('auth');
  const [code, setCode] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [resent, setResent] = useState(false);
  const [resendAt, setResendAt] = useState(() =>
    sendOnMount ? 0 : Date.now() + RESEND_COOLDOWN_MS,
  );
  const [now, setNow] = useState(() => Date.now());
  const sentOnMount = useRef(false);

  const secondsLeft = Math.max(0, Math.ceil((resendAt - now) / 1000));

  useEffect(() => {
    if (secondsLeft === 0) return;
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, [secondsLeft]);

  const sendCode = async (isResend: boolean) => {
    setError(null);
    setResent(false);
    try {
      const res = await apiFetch('/auth/email/send-code', { method: 'POST' });
      if (res.ok) {
        setResendAt(Date.now() + RESEND_COOLDOWN_MS);
        setNow(Date.now());
        setResent(isResend);
        return;
      }
      if (res.status === 429) {
        // a code is already on its way (or the hourly cap was hit): show the
        // server's countdown instead of an error
        const body = (await res.json().catch(() => null)) as {
          retryAfterSeconds?: number;
        } | null;
        setResendAt(Date.now() + (body?.retryAfterSeconds ?? 60) * 1000);
        setNow(Date.now());
        return;
      }
      setError(t('verify.sendError'));
    } catch {
      setError(t('verify.sendError'));
    }
  };

  useEffect(() => {
    // the ref survives StrictMode's remount, so only one code goes out
    if (!sendOnMount || sentOnMount.current) return;
    sentOnMount.current = true;
    void sendCode(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sendOnMount]);

  const verify = async (value: string) => {
    if (submitting) return;
    setSubmitting(true);
    setError(null);
    setResent(false);
    try {
      const res = await apiFetch('/auth/email/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: value }),
      });
      if (res.ok) {
        onVerified(await res.json());
        return;
      }
      setError(
        res.status === 400 ? t('verify.invalidCode') : t('verify.genericError'),
      );
      setCode('');
    } catch {
      setError(t('verify.genericError'));
    } finally {
      setSubmitting(false);
    }
  };

  const onCodeChange = (raw: string) => {
    const digits = raw.replace(/\D/g, '').slice(0, CODE_LEN);
    setCode(digits);
    if (digits.length === CODE_LEN) void verify(digits);
  };

  return (
    <div className="mt-[22px] flex flex-col gap-2.5 text-left">
      <div className="relative">
        <input
          type="text"
          inputMode="numeric"
          autoComplete="one-time-code"
          value={code}
          onChange={(e) => onCodeChange(e.target.value)}
          maxLength={CODE_LEN}
          disabled={submitting}
          autoFocus
          aria-label={t('verify.codeLabel')}
          placeholder="000000"
          className="w-full rounded-[11px] border border-border bg-transparent px-3.5 py-[11px] text-center font-mono text-[22px] tracking-[.4em] text-foreground outline-none placeholder:text-muted-foreground/50 focus:border-acc disabled:opacity-70"
        />
        {submitting && (
          <Loader2
            size={16}
            strokeWidth={2}
            className="absolute top-1/2 right-3.5 -translate-y-1/2 animate-spin text-muted-foreground"
          />
        )}
      </div>

      {error && <p className="text-[12px] text-neg">{error}</p>}
      {resent && !error && (
        <p className="text-[12px] text-muted-foreground">
          {t('verify.resent')}
        </p>
      )}

      <div className="mt-1 flex items-center justify-between gap-3">
        <button
          type="button"
          onClick={() => void sendCode(true)}
          disabled={secondsLeft > 0}
          className="cursor-pointer text-[13px] font-medium text-acc-tx tabular-nums hover:underline disabled:cursor-default disabled:text-muted-foreground disabled:no-underline"
        >
          {secondsLeft > 0
            ? t('verify.resendIn', { seconds: secondsLeft })
            : t('verify.resend')}
        </button>
        <button
          type="button"
          onClick={onSkip}
          className="cursor-pointer rounded-[9px] bg-chip px-[13px] py-1.5 text-[13px] font-medium text-foreground hover:bg-grid-ax"
        >
          {t('verify.later')}
        </button>
      </div>
    </div>
  );
}

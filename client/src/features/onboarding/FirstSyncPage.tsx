import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { apiFetch } from '@/lib/api';
import { formatKm } from '@/lib/activityFormat';
import type { ActivitiesResponse, SyncStatus } from '@/lib/types';
import { useAuth } from '@/features/auth/AuthContext';
import { FIRST_SYNC_FLAG } from './firstSyncFlag';

const POLL_MS = 2000;

type Step = 'intro' | 'syncing' | 'done';

function formatCountdown(totalSeconds: number): string {
  const m = Math.floor(totalSeconds / 60);
  const s = totalSeconds % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

interface HistorySummary {
  count: number;
  km: number;
  firstYear: number | null;
  lastYear: number | null;
}

// mobile stand-in: stacked column matching the tab-bar layout's content flow
function MobileSkeletonBackdrop() {
  return (
    <div
      aria-hidden="true"
      className="flex min-h-full flex-1 flex-col gap-[14px] px-5 pt-[76px] md:hidden"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-[10px]">
          <div className="flex h-[30px] w-[30px] items-center justify-center rounded-[9px] bg-acc text-[12px] font-bold text-white">
            ST
          </div>
          <span className="text-[14px] font-semibold text-foreground">
            SoTreina
          </span>
        </div>
        <div className="h-[30px] w-[30px] rounded-full bg-chip" />
      </div>

      <div className="grid grid-cols-2 gap-[14px]">
        {['62%', '48%', '55%', '42%'].map((width) => (
          <div
            key={width}
            className="flex flex-col gap-2.5 rounded-[14px] border border-border bg-card p-4"
          >
            <div className="h-[10px] rounded-[5px] bg-chip" style={{ width }} />
            <div className="h-[18px] w-2/3 rounded-[6px] bg-chip" />
          </div>
        ))}
      </div>

      <div className="flex flex-col gap-3 rounded-[14px] border border-border bg-card p-4">
        <div className="h-[11px] w-[40%] rounded-[5px] bg-chip" />
        <div className="h-[140px] rounded-[10px] bg-chip" />
      </div>

      <div className="flex flex-col gap-4 rounded-[14px] border border-border bg-card p-4">
        {['72%', '58%', '66%'].map((width) => (
          <div key={width} className="flex items-center gap-3">
            <div className="h-2 w-2 flex-none rounded-full bg-chip" />
            <div className="h-[10px] rounded-[5px] bg-chip" style={{ width }} />
            <div className="ml-auto h-[10px] w-[44px] flex-none rounded-[5px] bg-chip" />
          </div>
        ))}
      </div>
    </div>
  );
}

// static, non-interactive stand-in for the app shell so the sync card feels
// like it sits on top of the real dashboard
function SkeletonBackdrop() {
  return (
    <div
      aria-hidden="true"
      className="hidden min-h-full flex-1 gap-[14px] p-[14px] md:flex"
    >
      {/* sidebar */}
      <div className="flex w-[210px] flex-none flex-col gap-6 rounded-[16px] border border-border bg-card px-[14px] py-[20px]">
        <div className="flex items-center gap-[10px]">
          <div className="flex h-[30px] w-[30px] items-center justify-center rounded-[9px] bg-acc text-[12px] font-bold text-white">
            ST
          </div>
          <span className="text-[14px] font-semibold text-foreground">
            SoTreina
          </span>
        </div>
        {['78%', '62%', '70%', '54%', '66%'].map((width) => (
          <div
            key={width}
            className="h-[11px] rounded-[6px] bg-chip"
            style={{ width }}
          />
        ))}
        <div className="mt-auto flex items-center gap-2.5">
          <div className="h-[28px] w-[28px] flex-none rounded-full bg-chip" />
          <div className="h-[10px] w-[64px] rounded-[6px] bg-chip" />
        </div>
      </div>

      {/* main panel */}
      <div className="flex min-w-0 flex-1 flex-col gap-5 rounded-[16px] border border-border bg-card px-[30px] py-[28px]">
        <div className="h-[15px] w-[150px] rounded-[6px] bg-chip" />
        <div className="h-[10px] w-[230px] rounded-[6px] bg-chip" />
        <div className="grid flex-1 grid-cols-2 gap-4">
          {['38%', '52%', '44%', '46%'].map((width) => (
            <div
              key={width}
              className="flex flex-col gap-[14px] rounded-[12px] border border-border p-[16px_18px]"
            >
              <div
                className="h-[11px] rounded-[6px] bg-chip"
                style={{ width }}
              />
              <div className="flex-1 rounded-[8px] bg-chip" />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

interface FirstSyncPageProps {
  onDone: () => void;
}

export default function FirstSyncPage({ onDone }: FirstSyncPageProps) {
  const { t } = useTranslation('onboarding');
  const { user } = useAuth();
  // null while the initial status check resolves (card hidden until then)
  const [step, setStep] = useState<Step | null>(null);
  const [status, setStatus] = useState<SyncStatus | null>(null);
  const [failed, setFailed] = useState(false);
  const [summary, setSummary] = useState<HistorySummary | null>(null);
  // ticks every second while rate-limited so the countdown moves smoothly
  // between the 2s status polls, instead of jumping in POLL_MS increments
  const [now, setNow] = useState(() => Date.now());

  // resume where the backend actually is: a reload mid-sync goes straight to
  // the progress card, a reload after completion goes to "All set"
  useEffect(() => {
    apiFetch('/strava/sync/status')
      .then((res) => (res.ok ? res.json() : null))
      .then((s: SyncStatus | null) => {
        const pending = localStorage.getItem(FIRST_SYNC_FLAG) != null;
        if (s?.state === 'running') {
          setStatus(s);
          setStep('syncing');
        } else if (s?.state === 'done' && pending) {
          setStatus(s);
          setStep('done');
        } else if (s?.state === 'error' && pending) {
          setStatus(s);
          setFailed(true);
          setStep('syncing');
        } else {
          setStep('intro');
        }
      })
      .catch(() => setStep('intro'));
  }, []);

  useEffect(() => {
    if (step !== 'syncing' || failed) return;
    const id = setInterval(() => {
      apiFetch('/strava/sync/status')
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.json();
        })
        .then((s: SyncStatus) => {
          setStatus(s);
          if (s.state === 'done') setStep('done');
          else if (s.state === 'error') setFailed(true);
        })
        .catch(() => {});
    }, POLL_MS);
    return () => clearInterval(id);
  }, [step, failed]);

  useEffect(() => {
    if (status?.phase !== 'rate_limited' || !status.rateLimitResetAt) return;
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, [status?.phase, status?.rateLimitResetAt]);

  useEffect(() => {
    if (step !== 'done') return;
    apiFetch('/activities?limit=1000')
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data: ActivitiesResponse) => {
        const years = data.items.map((a) =>
          new Date(a.startDate).getFullYear(),
        );
        setSummary({
          count: data.total,
          km: data.items.reduce((sum, a) => sum + (a.distanceKm ?? 0), 0),
          firstYear: years.length ? Math.min(...years) : null,
          lastYear: years.length ? Math.max(...years) : null,
        });
      })
      .catch(() => {});
  }, [step]);

  const startSync = () => {
    localStorage.setItem(FIRST_SYNC_FLAG, '1');
    setFailed(false);
    setStep('syncing');
    apiFetch('/strava/sync', { method: 'POST' })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((s: SyncStatus) => {
        setStatus(s);
        // not running means the app-wide sync lock is held by another
        // account's sync — nothing started for this user
        if (s.state !== 'running') setFailed(true);
      })
      .catch(() => setFailed(true));
  };

  const openDashboard = () => {
    localStorage.removeItem(FIRST_SYNC_FLAG);
    onDone();
  };

  const firstName = user?.firstName ?? null;
  const initials = firstName ? firstName.slice(0, 2).toUpperCase() : '—';

  const total = status?.total ?? null;
  const processed = status?.processed ?? 0;
  const percent =
    total == null ? 0 : total === 0 ? 100 : (processed / total) * 100;
  const processingYear = status?.processingDate
    ? new Date(status.processingDate).getFullYear()
    : null;
  const isRateLimited = status?.phase === 'rate_limited';
  const rateLimitSecondsLeft =
    isRateLimited && status?.rateLimitResetAt
      ? Math.max(
          0,
          Math.round(
            (new Date(status.rateLimitResetAt).getTime() - now) / 1000,
          ),
        )
      : null;

  const primaryButton =
    'press w-full cursor-pointer rounded-[12px] bg-acc py-[15px] text-[15px] font-semibold text-white hover:brightness-[.93] md:rounded-[11px] md:py-[13px] md:text-[14.5px]';

  return (
    <div className="relative flex min-h-screen bg-page-bg">
      <MobileSkeletonBackdrop />
      <SkeletonBackdrop />

      {/* mobile: bottom-sheet scrim; desktop: centered dialog scrim */}
      <div className="absolute inset-0 flex items-end justify-center bg-[rgba(8,12,20,.22)] md:items-center md:bg-[rgba(8,12,20,.16)] dark:bg-[rgba(4,7,12,.5)] md:dark:bg-[rgba(4,7,12,.45)]">
        {step != null && (
          <div className="flex w-full flex-col items-center rounded-t-[26px] border border-border bg-card px-[26px] pb-[46px] pt-[32px] text-center shadow-[0_24px_60px_rgba(8,12,20,.22)] md:w-[430px] md:rounded-[20px] md:px-[44px] md:pb-[32px] md:pt-[40px]">
            {step === 'intro' && (
              <>
                {/* keeps large.jpg: 52px at 2x DPR needs 104px, medium (62px) would blur */}
                {user?.profileImgUrl ? (
                  <img
                    src={user.profileImgUrl}
                    alt=""
                    width={52}
                    height={52}
                    className="h-[52px] w-[52px] rounded-full object-cover"
                  />
                ) : (
                  <div className="flex h-[52px] w-[52px] items-center justify-center rounded-full bg-chip text-[17px] font-semibold text-foreground">
                    {initials}
                  </div>
                )}
                <div className="mt-3 flex items-center gap-1.5 rounded-full bg-pos-bg px-[10px] py-1 text-[11px] font-semibold text-pos">
                  <span className="h-[6px] w-[6px] rounded-full bg-pos" />
                  {t('badge.connected')}
                </div>
                <h2 className="mt-[18px] text-[21px] font-semibold tracking-[-.01em] text-foreground">
                  {firstName
                    ? t('intro.titleWithName', { name: firstName })
                    : t('intro.title')}
                </h2>
                <p className="mt-2 text-[13.5px] leading-[1.55] text-muted-foreground">
                  {t('intro.body')}
                </p>
                <button
                  type="button"
                  onClick={startSync}
                  className={`mt-[26px] ${primaryButton}`}
                >
                  {t('intro.cta')}
                </button>
                <p className="mt-[11px] text-[11.5px] text-muted-foreground">
                  {t('intro.hint')}
                </p>
              </>
            )}

            {step === 'syncing' && (
              <>
                <h2 className="text-[16px] font-semibold text-foreground">
                  {t('syncing.title')}
                </h2>
                {total == null ? (
                  <div className="mt-[22px] text-[14px] leading-[40px] text-muted-foreground">
                    {t('syncing.finding')}
                  </div>
                ) : (
                  <div className="mt-[22px] flex items-baseline gap-2">
                    <span className="text-[40px] font-bold leading-none tracking-[-.03em] text-foreground tabular-nums">
                      {processed}
                    </span>
                    <span className="text-[14px] text-muted-foreground">
                      {t('syncing.ofTotal', { count: total })}
                    </span>
                  </div>
                )}
                <div className="mt-5 h-2 w-full overflow-hidden rounded-full bg-chip">
                  {total == null ? (
                    <div className="h-full w-1/3 animate-pulse rounded-full bg-acc" />
                  ) : (
                    <div
                      className="h-full rounded-full bg-acc transition-[width] duration-[120ms] ease-linear"
                      style={{ width: `${percent}%` }}
                    />
                  )}
                </div>
                <div className="mt-3 min-h-[19px] text-[12.5px] text-muted-foreground">
                  {failed ? (
                    <span className="text-[12px] text-neg">
                      {t('syncing.failed')}{' '}
                      <button
                        type="button"
                        onClick={startSync}
                        className="cursor-pointer font-medium underline underline-offset-2"
                      >
                        {t('syncing.retry')}
                      </button>
                    </span>
                  ) : isRateLimited && rateLimitSecondsLeft != null ? (
                    <span className="tabular-nums">
                      {t('syncing.rateLimited', {
                        time: formatCountdown(rateLimitSecondsLeft),
                      })}
                    </span>
                  ) : processingYear != null ? (
                    t('syncing.processingYear', { year: processingYear })
                  ) : (
                    ' '
                  )}
                </div>
                <div className="mt-[26px] w-full border-t border-border pt-[18px] text-[11.5px] text-muted-foreground">
                  {t('syncing.readOnlyNotice')}
                </div>
              </>
            )}

            {step === 'done' && (
              <>
                <div className="flex h-[52px] w-[52px] items-center justify-center rounded-full bg-pos-bg text-pos">
                  <svg
                    width="24"
                    height="24"
                    viewBox="0 0 24 24"
                    fill="none"
                    aria-hidden="true"
                  >
                    <path
                      d="M6 12.5l4 4L18 8"
                      stroke="currentColor"
                      strokeWidth="2.2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                </div>
                <h2 className="mt-[18px] text-[21px] font-semibold tracking-[-.01em] text-foreground">
                  {t('done.title')}
                </h2>
                <p className="mt-2 text-[13.5px] leading-[1.55] text-muted-foreground tabular-nums">
                  {summary
                    ? [
                        t('done.activityCount', { count: summary.count }),
                        t('done.distanceKm', { km: formatKm(summary.km) }),
                        summary.firstYear != null
                          ? summary.firstYear === summary.lastYear
                            ? `${summary.firstYear}`
                            : `${summary.firstYear}–${summary.lastYear}`
                          : null,
                      ]
                        .filter(Boolean)
                        .join(' · ')
                    : ' '}
                </p>
                <button
                  type="button"
                  onClick={openDashboard}
                  className={`mt-[26px] ${primaryButton}`}
                >
                  {t('done.cta')}
                </button>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

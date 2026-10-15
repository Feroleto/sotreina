import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Check } from 'lucide-react';
import { m, useReducedMotion } from 'motion/react';
import MotionProvider from '@/components/MotionProvider';
import CountUp from '@/components/CountUp';
import { formatDurationShort } from '@/lib/activityFormat';
import { currentIntlLocale } from '@/lib/dateLocale';
import { DUR, EASE_OUT, SPRING_CELEBRATE } from '@/lib/motion';
import type { FinishedWorkout, WorkoutPersonalRecord } from '@/lib/types';

// one celebration per workout: leaving and coming back while the summary is
// still up (it lives in useActiveWorkout until dismissed) shows it settled
const celebratedKey = (id: string) => `celebrated:workout:${id}`;

function claimCelebration(id: string): boolean {
  try {
    if (localStorage.getItem(celebratedKey(id))) return false;
    localStorage.setItem(celebratedKey(id), '1');
    return true;
  } catch {
    // storage blocked: celebrate anyway, it's only ever a one-off screen
    return true;
  }
}

function formatKg(kg: number): string {
  return kg.toLocaleString(currentIntlLocale(), { maximumFractionDigits: 1 });
}

function Kpi({
  label,
  index,
  celebrate,
  children,
}: {
  label: string;
  index: number;
  celebrate: boolean;
  children: React.ReactNode;
}) {
  return (
    <m.div
      initial={celebrate ? { opacity: 0, transform: 'translateY(8px)' } : false}
      animate={{ opacity: 1, transform: 'translateY(0px)' }}
      transition={{ duration: DUR.page, ease: EASE_OUT, delay: 0.15 + index * 0.08 }}
      className="rounded-[14px] border border-border bg-card px-3.5 py-3"
    >
      <div className="text-[10.5px] font-semibold tracking-[.07em] text-muted-foreground uppercase">
        {label}
      </div>
      <div className="mt-1 text-[22px] font-bold tracking-[-.02em] text-foreground tabular-nums">
        {children}
      </div>
    </m.div>
  );
}

function RecordCard({
  record,
  index,
  celebrate,
  reduce,
}: {
  record: WorkoutPersonalRecord;
  index: number;
  celebrate: boolean;
  reduce: boolean;
}) {
  const { t } = useTranslation('gym');
  // after the KPIs have mostly counted up
  const delay = 0.6 + index * 0.12;
  const set = (kg: number, reps: number | null) =>
    reps != null ? `${formatKg(kg)} kg × ${reps}` : `${formatKg(kg)} kg`;

  return (
    <m.div
      initial={celebrate ? { opacity: 0, transform: 'translateY(8px)' } : false}
      animate={{ opacity: 1, transform: 'translateY(0px)' }}
      transition={{ duration: DUR.page, ease: EASE_OUT, delay }}
      className="relative flex items-center gap-3 rounded-[14px] border border-border bg-card p-[14px_16px]"
    >
      {/* a short accent glow as the badge lands — opacity only, on its own
          layer, rather than animating box-shadow (a repaint per frame) */}
      {celebrate && !reduce && (
        <m.div
          aria-hidden
          className="pointer-events-none absolute -inset-px rounded-[14px]"
          style={{
            boxShadow:
              '0 0 0 1.5px var(--acc), 0 0 22px color-mix(in oklab, var(--acc) 40%, transparent)',
          }}
          initial={{ opacity: 0 }}
          animate={{ opacity: [0, 1, 0] }}
          transition={{ duration: 1.1, times: [0, 0.25, 1], ease: 'easeOut', delay: delay + 0.15 }}
        />
      )}
      <m.span
        initial={celebrate && !reduce ? { opacity: 0, scale: 0.6 } : false}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ ...SPRING_CELEBRATE, delay: delay + 0.15 }}
        className="flex h-9 w-9 flex-none items-center justify-center rounded-full bg-acc text-[11px] font-bold text-white"
      >
        {t('summary.prBadge')}
      </m.span>
      <div className="min-w-0 flex-1">
        <div className="truncate text-[14px] font-semibold text-foreground">
          {record.exerciseName}
        </div>
        <div className="mt-0.5 text-[12px] text-muted-foreground">
          {t('summary.prFrom', { previous: set(record.previousWeightKg, record.previousReps) })}
        </div>
      </div>
      <div className="flex-none text-[14px] font-semibold text-foreground tabular-nums">
        {set(record.weightKg, record.reps)}
      </div>
    </m.div>
  );
}

function Summary({ workout, onDone }: { workout: FinishedWorkout; onDone: () => void }) {
  const { t } = useTranslation('gym');
  const reduce = useReducedMotion() ?? false;
  // read once at mount; StrictMode's double-invoked initializer keeps the
  // first answer
  const [firstTime] = useState(() => claimCelebration(workout.id));
  // reduced motion: everything just fades in, numbers land on their value
  const celebrate = firstTime && !reduce;
  const fade = firstTime && reduce;
  const { summary } = workout;

  return (
    <m.div
      initial={fade ? { opacity: 0 } : false}
      animate={{ opacity: 1 }}
      transition={{ duration: DUR.page, ease: EASE_OUT }}
      className="px-5 pt-[18px] pb-[44px] md:mx-auto md:max-w-[560px] md:pt-10"
    >
      <m.div
        initial={celebrate ? { opacity: 0, transform: 'translateY(8px)' } : false}
        animate={{ opacity: 1, transform: 'translateY(0px)' }}
        transition={{ duration: DUR.page, ease: EASE_OUT }}
        className="flex flex-col items-center text-center"
      >
        <div className="flex h-12 w-12 items-center justify-center rounded-full bg-acc-bg text-acc">
          <Check className="h-6 w-6" strokeWidth={2.4} />
        </div>
        <h1 className="mt-3 text-[22px] font-bold tracking-[-.02em] text-foreground">
          {t('summary.title')}
        </h1>
        <p className="mt-0.5 text-[13px] text-muted-foreground">
          {workout.templateName ?? t('start.freeWorkout')}
        </p>
      </m.div>

      <div className="mt-6 grid grid-cols-3 gap-2.5">
        <Kpi label={t('summary.duration')} index={0} celebrate={celebrate}>
          <CountUp
            value={summary.durationSec}
            format={(v) => formatDurationShort(Math.round(v))}
            delay={0.15}
            celebrate={celebrate}
          />
        </Kpi>
        <Kpi label={t('summary.volume')} index={1} celebrate={celebrate}>
          <CountUp
            value={summary.volumeKg}
            // tons, same unit/format as the Histórico tab — "1.880 kg" wraps
            // in the 3-column grid on a phone
            format={(v) => `${(v / 1000).toFixed(1)} t`}
            delay={0.23}
            celebrate={celebrate}
          />
        </Kpi>
        <Kpi label={t('summary.sets')} index={2} celebrate={celebrate}>
          <CountUp
            value={summary.setCount}
            format={(v) => String(Math.round(v))}
            delay={0.31}
            celebrate={celebrate}
          />
        </Kpi>
      </div>

      {summary.personalRecords.length > 0 && (
        <div className="mt-6">
          <m.div
            initial={celebrate ? { opacity: 0 } : false}
            animate={{ opacity: 1 }}
            transition={{ duration: DUR.page, ease: EASE_OUT, delay: 0.6 }}
            className="mb-2.5 px-1 text-[14px] font-semibold text-foreground"
          >
            {t('summary.prTitle', { count: summary.personalRecords.length })}
          </m.div>
          <div className="flex flex-col gap-2.5">
            {summary.personalRecords.map((r, i) => (
              <RecordCard
                key={r.exerciseId}
                record={r}
                index={i}
                celebrate={celebrate}
                reduce={reduce}
              />
            ))}
          </div>
        </div>
      )}

      <button
        type="button"
        onClick={onDone}
        className="press mt-8 w-full rounded-[12px] bg-acc py-[13px] text-[14.5px] font-semibold text-white"
      >
        {t('summary.done')}
      </button>
    </m.div>
  );
}

/**
 * Shown right after finishing a workout (instead of dropping straight back
 * to the routines list): duration/volume/sets count up, and any PR from this
 * session lands with a badge pop — the celebration happens once per workout.
 */
export default function WorkoutSummaryPage(props: {
  workout: FinishedWorkout;
  onDone: () => void;
}) {
  return (
    <MotionProvider>
      <Summary {...props} />
    </MotionProvider>
  );
}

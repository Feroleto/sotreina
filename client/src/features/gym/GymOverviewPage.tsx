import type { CSSProperties } from 'react';
import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import type { TemplateSummary } from '@/lib/types';
import { formatDayMonth } from '@/lib/activityFormat';
import { endOfWeek, nextBin, startOfBin } from '@/features/dashboard/bins';
import { useWorkoutHistory } from './useWorkoutHistory';
import { useWorkoutTemplates } from './useWorkoutTemplates';
import { formatLastPerformed } from './relativeTime';
import { pickNextRoutine } from './routineFormat';
import GymCalendar from './GymCalendar';
import GymPersonalRecordCard from './GymPersonalRecordCard';
import { useEntrance } from '@/lib/useEntrance';
import { LoadingSwap, Skeleton } from '@/components/Skeleton';

function formatTons(kg: number): string {
  return (kg / 1000).toFixed(1);
}

function formatShortDuration(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.round((sec % 3600) / 60);
  return h > 0 ? `${h}h${String(m).padStart(2, '0')}` : `${m}min`;
}

function Stat({ label, value, first }: { label: string; value: string; first?: boolean }) {
  return (
    <div className={first ? 'py-3.5' : 'border-l border-border py-3.5 pl-3.5'}>
      <div className="text-[12px] text-muted-foreground">{label}</div>
      <div className="mt-1 font-mono text-[20px] font-medium text-foreground">{value}</div>
    </div>
  );
}

function HeroSkeleton() {
  return (
    <div>
      <Skeleton className="mt-[22px] h-[64px] w-[45%]" />
      <Skeleton className="mt-3 h-[12px] w-[60%]" />
      <div className="mt-[22px] grid grid-cols-3 border-y border-border">
        {[0, 1, 2].map((i) => (
          <div key={i} className={i ? 'border-l border-border py-3.5 pl-3.5' : 'py-3.5'}>
            <Skeleton className="h-[11px] w-[55%]" />
            <Skeleton className="mt-2 h-[20px] w-[60%]" />
          </div>
        ))}
      </div>
    </div>
  );
}

interface GymOverviewPageProps {
  /** name of the session already running, if any — "Próximo treino" resumes it */
  activeWorkoutName: string | null;
  onStartWorkout: (templateId: string) => void;
  onResumeWorkout: () => void;
  onOpenRoutine: (templateId: string) => void;
  onNewRoutine: () => void;
}

/**
 * Treino overview — Redesign 18b ("Monolito", same system as Corrida 17b):
 * the week in one number, the next routine with a single primary action,
 * then the routines as hairline rows. Calendar and PR search follow below
 */
export default function GymOverviewPage({
  activeWorkoutName,
  onStartWorkout,
  onResumeWorkout,
  onOpenRoutine,
  onNewRoutine,
}: GymOverviewPageProps) {
  const { t } = useTranslation('gym');
  const { items, loading } = useWorkoutHistory();
  const { templates, loading: templatesLoading } = useWorkoutTemplates();
  const { attach: enterRef, state: enterState } = useEntrance('gym/overview', {
    ready: !loading && !templatesLoading,
  });

  // current (partial) Monday-start week against the one before it — no
  // weekly target exists, so last week is what the progress bar measures
  const { thisWeek, lastWeekCount, weekStart } = useMemo(() => {
    const monday = startOfBin(new Date(), 'week');
    const prevMonday = new Date(monday);
    prevMonday.setDate(prevMonday.getDate() - 7);
    const end = nextBin(monday, 'week');
    const current = items.filter((w) => {
      const d = new Date(w.startedAt);
      return d >= monday && d < end;
    });
    const previous = items.filter((w) => {
      const d = new Date(w.startedAt);
      return d >= prevMonday && d < monday;
    });
    return {
      thisWeek: current,
      lastWeekCount: previous.length,
      weekStart: monday,
    };
  }, [items]);

  const count = thisWeek.length;
  const volumeKg = thisWeek.reduce((s, w) => s + w.volumeKg, 0);
  const exercises = thisWeek.reduce((s, w) => s + w.exerciseCount, 0);
  const durationSec = thisWeek.reduce((s, w) => s + w.durationSec, 0);
  const pct = lastWeekCount > 0 ? Math.round((count / lastWeekCount) * 100) : null;

  const next = useMemo(() => pickNextRoutine(templates), [templates]);
  const lastPerformed = (tpl: TemplateSummary) =>
    tpl.lastPerformedAt
      ? t('routines.lastPerformed', {
          when: formatLastPerformed(t, tpl.lastPerformedAt),
        })
      : t('routines.neverPerformed');

  return (
    <div
      ref={enterRef}
      data-enter={enterState}
      className="px-[22px] pt-3 pb-[44px] tabular-nums md:max-w-[640px] md:p-[30px_34px_34px]"
    >
      <div className="text-[13px] text-muted-foreground">
        {t('overviewPage.thisWeek', {
          range: `${formatDayMonth(weekStart)} – ${formatDayMonth(endOfWeek(weekStart))}`,
        })}
      </div>

      <LoadingSwap loading={loading} skeleton={<HeroSkeleton />}>
        <div className="mt-[22px] flex items-baseline gap-2">
          <span className="font-mono text-[64px] leading-none font-medium tracking-[-.05em] text-foreground">
            {count}
          </span>
          <span className="text-[17px] text-muted-foreground">
            {t('overviewPage.workouts', { count })}
          </span>
        </div>
        <div className="mt-3 flex justify-between text-[12.5px] text-muted-foreground">
          <span>
            {lastWeekCount > 0
              ? t('overviewPage.lastWeek', { count: lastWeekCount })
              : t('overviewPage.noLastWeek')}
          </span>
          {pct !== null && <span className="font-medium text-foreground">{pct}%</span>}
        </div>
        {pct !== null && (
          <div className="mt-[7px] h-[3px] rounded-[2px] bg-border">
            <div
              className="macro-fill h-full bg-acc"
              style={{
                clipPath: `inset(0 ${100 - Math.min(100, pct)}% 0 0 round 2px)`,
              }}
            />
          </div>
        )}

        <div className="mt-[22px] grid grid-cols-3 border-y border-border">
          <Stat first label={t('history.kpiVolume')} value={`${formatTons(volumeKg)} t`} />
          <Stat label={t('overviewPage.exercises')} value={String(exercises)} />
          <Stat label={t('history.kpiTime')} value={formatShortDuration(durationSec)} />
        </div>
      </LoadingSwap>

      {(activeWorkoutName != null || next) && (
        <>
          <div className="mt-6 text-[14px] font-semibold text-foreground">
            {activeWorkoutName != null ? t('overviewPage.inProgress') : t('overviewPage.next')}
          </div>
          <div className="mt-2.5 flex items-center gap-3 border-b border-border py-4">
            <div className="min-w-0 flex-1">
              <div className="truncate text-[17px] font-semibold tracking-[-.01em] text-foreground">
                {activeWorkoutName ?? next!.name}
              </div>
              {activeWorkoutName == null && next && (
                <div className="mt-[3px] text-[12px] text-muted-foreground">
                  {t('routines.exerciseCount', { count: next.exerciseCount })} ·{' '}
                  {lastPerformed(next)}
                </div>
              )}
            </div>
            <button
              type="button"
              onClick={() =>
                activeWorkoutName != null ? onResumeWorkout() : onStartWorkout(next!.id)
              }
              className="press flex h-10 flex-none cursor-pointer items-center rounded-full bg-acc px-[18px] text-[13.5px] font-semibold text-acc-fg"
            >
              {activeWorkoutName != null ? t('overviewPage.resume') : t('overviewPage.start')}
            </button>
          </div>
        </>
      )}

      <div className="mt-6 flex items-center justify-between">
        <div className="text-[14px] font-semibold text-foreground">
          {t('overview.routinesSection.title')}
        </div>
        <button
          type="button"
          onClick={onNewRoutine}
          className="-mr-2 min-h-[44px] cursor-pointer px-2 text-[12.5px] font-medium text-muted-foreground hover:text-foreground"
        >
          + {t('overviewPage.newRoutine')}
        </button>
      </div>
      <div>
        {templates.map((tpl, i) => (
          <button
            key={tpl.id}
            type="button"
            onClick={() => onOpenRoutine(tpl.id)}
            className="enter-rise flex w-full cursor-pointer items-center gap-3 border-b border-border py-[13px] text-left"
            style={{ '--i': i } as CSSProperties}
          >
            <div className="min-w-0 flex-1">
              <div className="truncate text-[14.5px] font-medium text-foreground">{tpl.name}</div>
              <div className="mt-0.5 truncate text-[12px] text-muted-foreground">
                {t('routines.exerciseCount', { count: tpl.exerciseCount })} · {lastPerformed(tpl)}
              </div>
            </div>
            <svg
              width="8"
              height="14"
              viewBox="0 0 8 14"
              aria-hidden="true"
              className="flex-none text-muted-foreground"
            >
              <path
                d="M1 1l6 6-6 6"
                stroke="currentColor"
                strokeWidth="1.8"
                fill="none"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </button>
        ))}
        {!templatesLoading && templates.length === 0 && (
          <p className="border-b border-border py-6 text-center text-[13px] text-muted-foreground">
            {t('routines.empty')}
          </p>
        )}
      </div>

      <div className="mt-8">
        <GymCalendar items={items} />
      </div>

      <div className="mt-6">
        <GymPersonalRecordCard />
      </div>
    </div>
  );
}

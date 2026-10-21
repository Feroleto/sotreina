import type { CSSProperties } from 'react';
import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Check, Pencil } from 'lucide-react';
import type { PageId } from '@/features/nav/navConfig';
import { useActivities } from '@/lib/useActivities';
import { formatKm, formatNumber } from '@/lib/activityFormat';
import { currentIntlLocale } from '@/lib/dateLocale';
import { useEntrance } from '@/lib/useEntrance';
import { LoadingSwap, Skeleton } from '@/components/Skeleton';
import DrillStack from '@/components/DrillStack';
import { useWorkoutHistory } from '@/features/gym/useWorkoutHistory';
import { useWorkoutTemplates } from '@/features/gym/useWorkoutTemplates';
import { pickNextRoutine } from '@/features/gym/routineFormat';
import { useDietHistory } from '@/features/diet/useDietHistory';
import { localDateString, useFoodLogs } from '@/features/diet/useFoodLogs';
import { useMeals } from '@/features/diet/useMeals';
import { useUserGoals } from './useUserGoals';
import WeeklyGoalsPage from './WeeklyGoalsPage';
import {
  buildDays,
  buildFeed,
  buildTotals,
  calendarDaysAgo,
  isDietDone,
  type FeedItem,
} from './todayStatus';

// fallbacks while /users/me loads — the schema defaults
const DEFAULT_KCAL_GOAL = 2000;
const DEFAULT_RUN_KM_GOAL = 20;
const DEFAULT_WORKOUTS_GOAL = 3;

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function formatTodayHeader(d: Date): string {
  return capitalize(
    d.toLocaleDateString(currentIntlLocale(), {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
    }),
  );
}

function pctOf(value: number, goal: number): number {
  return goal > 0 ? Math.min(100, Math.round((value / goal) * 100)) : 0;
}

function StatusCell({
  label,
  sub,
  done,
  first,
  onClick,
}: {
  label: string;
  sub: string;
  done: boolean;
  first?: boolean;
  onClick: () => void;
}) {
  const { t } = useTranslation('today');
  return (
    <button
      type="button"
      onClick={onClick}
      className={`min-w-0 cursor-pointer py-4 text-left ${first ? '' : 'border-l border-border pl-3.5'}`}
    >
      {done ? (
        <span className="flex h-[22px] w-[22px] items-center justify-center rounded-full bg-acc text-acc-fg">
          <Check className="h-3 w-3" strokeWidth={3} aria-hidden="true" />
        </span>
      ) : (
        <span className="block h-[22px] w-[22px] rounded-full border-[1.5px] border-muted-foreground" />
      )}
      <div className="mt-2.5 text-[13.5px] font-medium text-foreground">
        {label}
        <span className="sr-only">
          {' '}
          · {done ? t('status.done') : t('status.pending')}
        </span>
      </div>
      <div className="mt-0.5 truncate text-[12px] text-muted-foreground">
        {sub}
      </div>
    </button>
  );
}

function AreaRow({
  name,
  detail,
  value,
  pct,
  over,
  onClick,
}: {
  name: string;
  detail: string;
  value: string;
  pct: number;
  over?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full cursor-pointer items-center gap-3 border-b border-border py-[13px] text-left"
    >
      <div className="min-w-0 flex-1">
        <div className="text-[14.5px] font-medium text-foreground">{name}</div>
        <div className="mt-0.5 truncate text-[12px] text-muted-foreground">
          {detail}
        </div>
      </div>
      <div className="flex-none text-right">
        <div className="font-mono text-[14.5px] font-medium text-foreground">
          {value}
        </div>
        <div className="mt-[5px] ml-auto h-[3px] w-16 rounded-[2px] bg-border">
          <div
            className={`macro-fill h-full ${over ? 'bg-neg' : 'bg-acc'}`}
            style={{ clipPath: `inset(0 ${100 - pct}% 0 0 round 2px)` }}
          />
        </div>
      </div>
    </button>
  );
}

function TodaySkeleton() {
  return (
    <div>
      <div className="mt-[22px] grid grid-cols-3 border-y border-border">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className={i ? 'border-l border-border py-4 pl-3.5' : 'py-4'}
          >
            <Skeleton className="h-[22px] w-[22px] rounded-full" />
            <Skeleton className="mt-2.5 h-[13px] w-[55%]" />
            <Skeleton className="mt-1.5 h-[11px] w-[75%]" />
          </div>
        ))}
      </div>
      <Skeleton className="mt-6 h-[14px] w-[35%]" />
      <Skeleton className="mt-3.5 h-[72px] w-full" />
      <Skeleton className="mt-6 h-[14px] w-[25%]" />
      {[0, 1, 2].map((i) => (
        <Skeleton key={i} className="mt-3 h-[40px] w-full" />
      ))}
    </div>
  );
}

const AREA_PAGE = {
  run: 'run/activities',
  gym: 'gym/overview',
  diet: 'diet/overview',
} as const;

interface TodayPageProps {
  /** name of the gym session already running, if any */
  activeWorkoutName: string | null;
  onNavigate: (page: PageId) => void;
}

/**
 * "Hoje" — Redesign 18a, same Monolito system as 17b/18b/18c: the day's
 * status per area, the last 7 days of completed areas, each area against
 * its goal, and a mixed feed. Every number derives client-side from
 * payloads the area pages already fetch — no endpoint of its own
 */
export default function TodayPage({
  activeWorkoutName,
  onNavigate,
}: TodayPageProps) {
  const { t } = useTranslation(['today', 'diet', 'gym']);
  const [editingGoals, setEditingGoals] = useState(false);
  // fixed for the page's lifetime: a page left open past midnight keeps
  // describing the day it loaded, consistent with the data it fetched
  const [now] = useState(() => new Date());
  const today = localDateString(now);

  const { activities, loading: runLoading } = useActivities();
  const { items: workouts, loading: gymLoading } = useWorkoutHistory();
  const { templates } = useWorkoutTemplates();
  const { points: dietPoints, loading: dietLoading } = useDietHistory(7);
  const { logs: todayLogs } = useFoodLogs(today);
  const { meals } = useMeals();
  const { goals, saveWeekly } = useUserGoals();

  const kcalGoal = goals?.dailyKcalGoal ?? DEFAULT_KCAL_GOAL;
  const runKmGoal = goals?.weeklyRunKmGoal ?? DEFAULT_RUN_KM_GOAL;
  const workoutsGoal = goals?.weeklyWorkoutsGoal ?? DEFAULT_WORKOUTS_GOAL;

  const firstLoad = runLoading || gymLoading || dietLoading;
  const { attach: enterRef, state: enterState } = useEntrance('overview', {
    ready: !firstLoad,
  });

  const days = useMemo(
    () => buildDays({ activities, workouts, dietPoints, kcalGoal, now }),
    [activities, workouts, dietPoints, kcalGoal, now],
  );
  const totals = useMemo(
    () => buildTotals({ activities, workouts, now }),
    [activities, workouts, now],
  );
  const feed = useMemo(
    () => buildFeed({ activities, workouts, meals, todayLogs }),
    [activities, workouts, meals, todayLogs],
  );
  const nextRoutine = useMemo(() => pickNextRoutine(templates), [templates]);

  const kcalToday = dietPoints.find((p) => p.date === today)?.totalKcal ?? 0;
  const runDone = totals.runKmToday > 0;
  const gymDone = totals.workoutsToday.length > 0;
  const dietDone = isDietDone(kcalToday, kcalGoal);

  const gymSub = (() => {
    if (activeWorkoutName != null)
      return t('status.gymInProgress', { name: activeWorkoutName });
    if (gymDone) {
      const [first] = totals.workoutsToday;
      return totals.workoutsToday.length === 1
        ? t('status.gymDone', {
            name: first.templateName ?? t('gym:start.freeWorkout'),
          })
        : t('status.gymDoneCount', { count: totals.workoutsToday.length });
    }
    return nextRoutine
      ? t('status.gymPending', { name: nextRoutine.name })
      : t('status.pending');
  })();

  const whenLabel = (iso: string) => {
    const n = calendarDaysAgo(iso, now);
    if (n === 0) return t('feed.today');
    if (n === 1) return t('feed.yesterday');
    return t('feed.daysAgo', { count: n });
  };

  const feedRow = (f: FeedItem) => {
    switch (f.kind) {
      case 'run':
        return {
          name: f.name,
          detail: `${t('status.run')} · ${whenLabel(f.at)} · ${t('feed.minutes', { count: Math.round(f.durationSec / 60) })}`,
          value: `${formatKm(f.distanceKm)} km`,
          page: AREA_PAGE.run,
        };
      case 'gym':
        return {
          name: f.name ?? t('gym:start.freeWorkout'),
          detail: `${t('status.gym')} · ${whenLabel(f.at)} · ${t('feed.exercises', { count: f.exerciseCount })}`,
          value: t('feed.minutes', { count: Math.round(f.durationSec / 60) }),
          page: AREA_PAGE.gym,
        };
      case 'diet':
        return {
          name: t(`diet:meal.${f.mealType}`),
          detail: `${t('status.diet')} · ${whenLabel(f.at)} · ${t('feed.items', { count: f.itemCount })}`,
          value: `${formatNumber(f.kcal)} kcal`,
          page: AREA_PAGE.diet,
        };
    }
  };

  const dayInitial = (date: string) =>
    new Date(`${date}T00:00:00`)
      .toLocaleDateString(currentIntlLocale(), { weekday: 'narrow' })
      .toUpperCase();

  const detail =
    editingGoals && goals ? (
      <WeeklyGoalsPage
        goals={goals}
        onBack={() => setEditingGoals(false)}
        onSave={async (next) => {
          await saveWeekly(next);
          setEditingGoals(false);
        }}
      />
    ) : null;

  return (
    <DrillStack depth={detail ? 1 : 0} viewKey={detail ? 'goals' : 'today'}>
      {detail ?? (
        <div
          ref={enterRef}
          data-enter={enterState}
          className="px-[22px] pt-3 pb-[44px] tabular-nums md:max-w-[640px] md:p-[30px_34px_34px]"
        >
          {/* on mobile the "Hoje" title lives in the header (MobileChrome) */}
          <h1 className="hidden text-[19px] font-semibold tracking-[-.01em] text-foreground md:block">
            {t('title')}
          </h1>
          <p className="text-[13px] text-muted-foreground md:mt-[2px]">
            {formatTodayHeader(now)}
          </p>

          <LoadingSwap loading={firstLoad} skeleton={<TodaySkeleton />}>
            <div className="mt-[22px] grid grid-cols-3 border-y border-border">
              <StatusCell
                first
                label={t('status.run')}
                sub={
                  runDone
                    ? t('status.runDone', { km: formatKm(totals.runKmToday) })
                    : t('status.pending')
                }
                done={runDone}
                onClick={() => onNavigate(AREA_PAGE.run)}
              />
              <StatusCell
                label={t('status.gym')}
                sub={gymSub}
                done={gymDone}
                onClick={() => onNavigate(AREA_PAGE.gym)}
              />
              <StatusCell
                label={t('status.diet')}
                sub={t('status.dietProgress', {
                  kcal: formatNumber(Math.round(kcalToday)),
                  goal: formatNumber(kcalGoal),
                })}
                done={dietDone}
                onClick={() => onNavigate(AREA_PAGE.diet)}
              />
            </div>

            <div className="mt-6 flex items-baseline justify-between">
              <div className="text-[14px] font-semibold text-foreground">
                {t('days.title')}
              </div>
              <div className="text-[12px] text-muted-foreground">
                {t('days.legend')}
              </div>
            </div>
            <div className="mt-3.5 flex h-[72px] items-end gap-2.5">
              {days.map((d, i) => {
                const count = Number(d.run) + Number(d.gym) + Number(d.diet);
                const isToday = i === days.length - 1;
                return (
                  <div
                    key={d.date}
                    role="img"
                    aria-label={t('days.a11y', {
                      day: dayInitial(d.date),
                      count,
                    })}
                    className="chart-bar flex h-full flex-1 flex-col justify-end gap-[3px]"
                    style={{ '--i': i } as CSSProperties}
                  >
                    {/* filled segments stack from the bottom, like the design */}
                    {[2, 1, 0].map((k) => (
                      <div
                        key={k}
                        className={`h-5 rounded-[3px] ${
                          k < count
                            ? isToday
                              ? 'bg-acc'
                              : 'bg-foreground'
                            : 'bg-border'
                        }`}
                      />
                    ))}
                  </div>
                );
              })}
            </div>
            <div className="mt-2 flex gap-2.5" aria-hidden="true">
              {days.map((d) => (
                <div
                  key={d.date}
                  className="flex-1 text-center font-mono text-[10.5px] text-muted-foreground"
                >
                  {dayInitial(d.date)}
                </div>
              ))}
            </div>

            <div className="mt-6 flex items-center justify-between">
              <div className="text-[14px] font-semibold text-foreground">
                {t('areas.title')}
              </div>
              <button
                type="button"
                onClick={() => setEditingGoals(true)}
                disabled={!goals}
                aria-label={t('areas.editGoals')}
                title={t('areas.editGoals')}
                className="-mr-2 flex h-11 w-11 cursor-pointer items-center justify-center text-muted-foreground hover:text-foreground disabled:cursor-default disabled:opacity-40"
              >
                <Pencil className="h-4 w-4" strokeWidth={1.8} />
              </button>
            </div>
            <div className="border-t border-border">
              <AreaRow
                name={t('status.run')}
                detail={t('areas.runGoal', { km: runKmGoal })}
                value={`${formatKm(totals.runKmWeek)} km`}
                pct={pctOf(totals.runKmWeek, runKmGoal)}
                onClick={() => onNavigate(AREA_PAGE.run)}
              />
              <AreaRow
                name={t('status.gym')}
                detail={t('areas.gymGoal', { count: workoutsGoal })}
                value={`${totals.workoutsWeek} / ${workoutsGoal}`}
                pct={pctOf(totals.workoutsWeek, workoutsGoal)}
                onClick={() => onNavigate(AREA_PAGE.gym)}
              />
              <AreaRow
                name={t('status.diet')}
                detail={t('areas.dietGoal', { kcal: formatNumber(kcalGoal) })}
                value={formatNumber(Math.round(kcalToday))}
                pct={pctOf(kcalToday, kcalGoal)}
                // strict value > goal, same rule as DietOverviewPage's bar
                over={kcalToday > kcalGoal}
                onClick={() => onNavigate(AREA_PAGE.diet)}
              />
            </div>

            <div className="mt-6 text-[14px] font-semibold text-foreground">
              {t('feed.title')}
            </div>
            <div className="mt-1.5">
              {feed.map((f, i) => {
                const row = feedRow(f);
                return (
                  <button
                    key={`${f.kind}:${f.id}`}
                    type="button"
                    onClick={() => onNavigate(row.page)}
                    className="enter-rise flex w-full cursor-pointer items-center gap-3 border-b border-border py-[13px] text-left"
                    style={{ '--i': i } as CSSProperties}
                  >
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[14.5px] font-medium text-foreground">
                        {row.name}
                      </div>
                      <div className="mt-0.5 truncate text-[12px] text-muted-foreground">
                        {row.detail}
                      </div>
                    </div>
                    <div className="flex-none font-mono text-[14.5px] font-medium text-foreground">
                      {row.value}
                    </div>
                  </button>
                );
              })}
              {feed.length === 0 && (
                <p className="border-b border-border py-6 text-center text-[13px] text-muted-foreground">
                  {t('feed.empty')}
                </p>
              )}
            </div>
          </LoadingSwap>
        </div>
      )}
    </DrillStack>
  );
}

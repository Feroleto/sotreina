import { useMemo, useState } from 'react';
import type { CSSProperties } from 'react';
import { useTranslation } from 'react-i18next';
import { ChevronRight } from 'lucide-react';
import { formatDayMonth } from '@/lib/activityFormat';
import { endOfWeek } from '@/features/dashboard/bins';
import { useWorkoutHistory } from './useWorkoutHistory';
import { aggregateWeeklyVolume, groupWorkoutsByWeek } from './historyBins';
import WorkoutDetailPage from './WorkoutDetailPage';
import DrillStack from '@/components/DrillStack';
import { useEntrance } from '@/lib/useEntrance';
import { LoadingSwap, Skeleton } from '@/components/Skeleton';
import type { WorkoutHistoryItem } from '@/lib/types';
import { formatVolume, volumeLabel } from '@/lib/units';

const WEEKS = 12;
const RECENT_WEEK_GROUPS = 4;
// one color per distinct routine (first-seen order); free workouts always
// get the neutral --dot-easy token instead of cycling into this palette.
// --chart-1 goes last: in dark mode its hue sits close to --acc's blue, so
// it's the one most likely to look redundant next to the accent-colored dot
const ROUTINE_DOT_COLORS = [
  'var(--acc)',
  'var(--chart-2)',
  'var(--chart-4)',
  'var(--chart-1)',
];

// always shows both parts, unlike lib/activityFormat's formatDuration —
// this card's spec calls for "{h}h {min}min" literally, every time
function formatTotalDuration(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.round((sec % 3600) / 60);
  return `${h}h ${m}min`;
}

function KpiCard({
  label,
  value,
  sub,
}: {
  label: string;
  value: string;
  sub: string;
}) {
  return (
    <div className="w-[150px] flex-none rounded-[14px] border border-border bg-card p-[14px_15px]">
      <div className="text-[10.5px] font-semibold tracking-[.07em] text-muted-foreground uppercase">
        {label}
      </div>
      <div className="mt-1 text-[20px] font-bold tracking-[-.02em] text-foreground">
        {value}
      </div>
      <div className="mt-[2px] text-[11px] text-muted-foreground">{sub}</div>
    </div>
  );
}

// mirrors the loaded layout: KPI carousel, weekly bars card, session rows
function HistorySkeleton() {
  return (
    <div className="px-5 pt-[18px] pb-[44px]">
      <div className="-mx-5 flex gap-3 overflow-hidden px-5">
        {[0, 1, 2, 3].map((i) => (
          <Skeleton
            key={i}
            className="h-[86px] w-[150px] flex-none rounded-[14px]"
          />
        ))}
      </div>
      <Skeleton className="mt-3 h-[178px] rounded-[14px]" />
      <div className="mt-6">
        <Skeleton className="mb-3 h-[11px] w-[110px]" />
        {[0, 1, 2, 3].map((i) => (
          <div
            key={i}
            className="flex items-center gap-3 border-b border-border py-[14px]"
          >
            <Skeleton className="h-2 w-2 flex-none rounded-full" />
            <div className="flex-1">
              <Skeleton className="h-[13px] w-[45%]" />
              <Skeleton className="mt-1.5 h-[10px] w-[65%]" />
            </div>
            <Skeleton className="h-[13px] w-[42px] flex-none" />
          </div>
        ))}
      </div>
    </div>
  );
}

export default function GymHistoryPage() {
  const { t } = useTranslation('gym');
  const { items, loading, error } = useWorkoutHistory();
  const [selected, setSelected] = useState<number | null>(null);
  const [viewingWorkout, setViewingWorkout] =
    useState<WorkoutHistoryItem | null>(null);

  const weeks = useMemo(() => aggregateWeeklyVolume(items, WEEKS), [items]);
  const windowStart = weeks[0]?.start ?? new Date();
  const windowItems = useMemo(
    () => items.filter((w) => new Date(w.startedAt) >= windowStart),
    [items, windowStart],
  );

  const count = windowItems.length;
  const volumeKg = windowItems.reduce((s, w) => s + w.volumeKg, 0);
  const durationSec = windowItems.reduce((s, w) => s + w.durationSec, 0);
  const frequency = count / Math.max(1, weeks.length);
  const maxVolume = Math.max(1, ...weeks.map((w) => w.volumeKg));

  const sel = selected !== null && weeks[selected] ? selected : null;
  const reading =
    sel !== null
      ? t('history.barReading', {
          unit: volumeLabel(),
          range: `${formatDayMonth(weeks[sel].start)} – ${formatDayMonth(endOfWeek(weeks[sel].start))}`,
          volume: formatVolume(weeks[sel].volumeKg),
        })
      : t('history.barHint', {
          unit: volumeLabel(),
          volume: formatVolume(volumeKg),
          count: weeks.length,
        });

  const routineColorById = useMemo(() => {
    const map = new Map<string, string>();
    let i = 0;
    for (const w of items) {
      if (w.templateId && !map.has(w.templateId)) {
        map.set(
          w.templateId,
          ROUTINE_DOT_COLORS[i % ROUTINE_DOT_COLORS.length],
        );
        i++;
      }
    }
    return map;
  }, [items]);

  const weekGroups = useMemo(() => groupWorkoutsByWeek(items), [items]);
  // volume bars grow and the week groups rise, once per session
  const { attach: enterRef, state: enterState } = useEntrance('gym/history', {
    ready: !loading,
  });
  const visibleGroups = weekGroups.slice(0, RECENT_WEEK_GROUPS);
  const olderWeekGroups = Math.max(0, weekGroups.length - RECENT_WEEK_GROUPS);

  const list = (
    <LoadingSwap loading={loading} skeleton={<HistorySkeleton />}>
      <div
        ref={enterRef}
        data-enter={enterState}
        className="px-5 pt-[18px] pb-[44px]"
      >
        {error && <p className="text-[12.5px] text-neg">{error}</p>}

        {!error && items.length === 0 && (
          <p className="mt-8 text-center text-[13.5px] text-muted-foreground">
            {t('history.empty')}
          </p>
        )}

        {items.length > 0 && (
          <>
            {/* KPI carousel — edge-bleed horizontal scroll */}
            <div className="no-scrollbar -mx-5 flex gap-3 overflow-x-auto px-5">
              <KpiCard
                label={t('history.kpiWorkouts')}
                value={String(count)}
                sub={t('history.weeksCount', { count: weeks.length })}
              />
              <KpiCard
                label={t('history.kpiVolume')}
                value={`${formatVolume(volumeKg)} ${volumeLabel()}`}
                sub={t('history.weeksCount', { count: weeks.length })}
              />
              <KpiCard
                label={t('history.kpiTime')}
                value={formatTotalDuration(durationSec)}
                sub={t('history.inTraining')}
              />
              <KpiCard
                label={t('history.kpiFrequency')}
                value={frequency.toFixed(1)}
                sub={t('history.perWeek')}
              />
            </div>

            {/* weekly volume bars */}
            <div className="mt-3 rounded-[14px] border border-border bg-card p-[16px]">
              <div
                className={`text-[12.5px] ${sel !== null ? 'text-foreground' : 'text-muted-foreground'}`}
              >
                {reading}
              </div>
              <div className="mt-3 flex h-[120px] items-end gap-[4px]">
                {weeks.map((w, i) => (
                  <button
                    key={w.start.getTime()}
                    type="button"
                    onClick={() => setSelected((cur) => (cur === i ? null : i))}
                    aria-label={`${formatDayMonth(w.start)} · ${formatVolume(w.volumeKg)} ${volumeLabel()}`}
                    className="flex h-full flex-1 cursor-pointer items-end"
                  >
                    <span
                      className="chart-bar w-full rounded-t-[4px]"
                      style={
                        {
                          '--i': i,
                          height: `${((w.volumeKg / maxVolume) * 100).toFixed(1)}%`,
                          background:
                            sel === i
                              ? 'color-mix(in oklab, var(--acc) 70%, white)'
                              : 'var(--acc)',
                        } as CSSProperties
                      }
                    />
                  </button>
                ))}
              </div>
              <div className="flex gap-[4px] border-t border-border pt-1">
                {weeks.map((w, i) => (
                  <div
                    key={w.start.getTime()}
                    className="flex-1 text-center text-[9.5px] text-muted-foreground"
                  >
                    {i % 3 === 0 ? formatDayMonth(w.start) : ''}
                  </div>
                ))}
              </div>
            </div>

            {/* recent sessions, grouped by week — same grouping pattern as
                the run Dashboard's ActivityList.tsx */}
            <div className="mt-6">
              {visibleGroups.map((group, gi) => (
                <div
                  key={group.start.getTime()}
                  className="enter-rise mb-[22px]"
                  style={{ '--i': gi } as CSSProperties}
                >
                  <div className="flex items-baseline justify-between border-b border-border pb-[9px]">
                    <div className="text-[11.5px] font-semibold tracking-[.05em] text-muted-foreground uppercase">
                      {t('history.weekOf', {
                        date: formatDayMonth(group.start),
                      })}
                    </div>
                    <div className="text-[12px] text-muted-foreground">
                      {formatVolume(group.volumeKg)} {volumeLabel()}
                    </div>
                  </div>
                  {group.workouts.map((w) => (
                    <div
                      key={w.id}
                      onClick={() => setViewingWorkout(w)}
                      className="flex cursor-pointer items-center gap-[12px] border-b border-border p-[14px_2px]"
                    >
                      <span
                        className="h-2 w-2 flex-none rounded-full"
                        style={{
                          background: w.templateId
                            ? routineColorById.get(w.templateId)
                            : 'var(--dot-easy)',
                        }}
                      />
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-[14px] font-semibold text-foreground">
                          {w.templateName ?? t('start.freeWorkout')}
                        </div>
                        <div className="mt-0.5 text-[11.5px] text-muted-foreground">
                          {t('history.sessionMeta', {
                            date: formatDayMonth(new Date(w.startedAt)),
                            duration: Math.round(w.durationSec / 60),
                            count: w.exerciseCount,
                          })}
                        </div>
                      </div>
                      <div className="flex-none text-[14px] font-semibold text-foreground">
                        {formatVolume(w.volumeKg)} {volumeLabel()}
                      </div>
                      <ChevronRight
                        className="h-4 w-4 flex-none text-muted-foreground"
                        strokeWidth={1.8}
                      />
                    </div>
                  ))}
                </div>
              ))}
              {olderWeekGroups > 0 && (
                <div className="text-[12.5px] text-muted-foreground">
                  {t('history.olderWeeks', { count: olderWeekGroups })}
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </LoadingSwap>
  );

  return (
    <DrillStack
      depth={viewingWorkout ? 1 : 0}
      viewKey={viewingWorkout ? `workout:${viewingWorkout.id}` : 'list'}
    >
      {viewingWorkout ? (
        <WorkoutDetailPage
          item={viewingWorkout}
          onBack={() => setViewingWorkout(null)}
        />
      ) : (
        list
      )}
    </DrillStack>
  );
}

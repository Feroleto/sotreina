import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { useWorkoutHistory } from './useWorkoutHistory';
import { useWorkoutTemplates } from './useWorkoutTemplates';
import { aggregateWeeklyVolume } from './historyBins';
import { formatLastPerformed } from './relativeTime';
import { stripWorkoutPrefix } from './routineFormat';
import GymCalendar from './GymCalendar';
import GymPersonalRecordCard from './GymPersonalRecordCard';
import { LoadingSwap, Skeleton } from '@/components/Skeleton';

const WEEKS = 12;

function formatTons(kg: number): string {
  return (kg / 1000).toFixed(1);
}

function formatTotalDuration(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.round((sec % 3600) / 60);
  return `${h}h ${m}min`;
}

function TotalTile({
  label,
  value,
  sub,
  borderLeft,
  borderTop,
}: {
  label: string;
  value: string;
  sub: string;
  borderLeft: boolean;
  borderTop: boolean;
}) {
  return (
    <div
      className={`p-[14px] ${borderLeft ? 'border-l border-border' : ''} ${
        borderTop ? 'border-t border-border' : ''
      }`}
    >
      <div className="text-[10.5px] font-semibold tracking-[.07em] text-muted-foreground uppercase">
        {label}
      </div>
      <div className="mt-1 text-[22px] font-bold tracking-[-.02em] text-foreground">{value}</div>
      <div className="mt-[2px] text-[11px] text-muted-foreground">{sub}</div>
    </div>
  );
}

// the 2×2 totals grid with its inner dividers
function TotalsSkeleton() {
  return (
    <div className="grid grid-cols-2">
      {[0, 1, 2, 3].map((i) => (
        <div
          key={i}
          className={`p-[14px] ${i % 2 ? 'border-l border-border' : ''} ${
            i > 1 ? 'border-t border-border' : ''
          }`}
        >
          <Skeleton className="h-[10px] w-[55%]" />
          <Skeleton className="mt-2 h-[22px] w-[60%]" />
          <Skeleton className="mt-2 h-[10px] w-[45%]" />
        </div>
      ))}
    </div>
  );
}

export default function GymOverviewPage() {
  const { t } = useTranslation('gym');
  const { items, loading } = useWorkoutHistory();
  const { templates } = useWorkoutTemplates();

  // same 12-week window (Monday-start, current week included) used by the
  // "Histórico" tab's KPI carousel — Overview and Histórico read off the
  // same real GET /workouts/history-stats data, just sliced/rendered
  // differently
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

  const routineStats = useMemo(() => {
    const byTemplate = new Map<string, { count: number; volumeKg: number }>();
    for (const w of windowItems) {
      if (!w.templateId) continue;
      const entry = byTemplate.get(w.templateId) ?? { count: 0, volumeKg: 0 };
      entry.count += 1;
      entry.volumeKg += w.volumeKg;
      byTemplate.set(w.templateId, entry);
    }
    const rows = templates.map((tpl) => ({
      template: tpl,
      periodCount: byTemplate.get(tpl.id)?.count ?? 0,
      periodVolumeKg: byTemplate.get(tpl.id)?.volumeKg ?? 0,
    }));
    rows.sort((a, b) => b.periodCount - a.periodCount);
    const maxVolume = Math.max(1, ...rows.map((r) => r.periodVolumeKg));
    return { rows, maxVolume };
  }, [templates, windowItems]);

  return (
    <div className="px-5 pt-[18px] pb-[44px] tabular-nums">
      <LoadingSwap loading={loading} skeleton={<TotalsSkeleton />}>
        <div className="grid grid-cols-2">
          <TotalTile
            label={t('history.kpiWorkouts')}
            value={String(count)}
            sub={t('history.weeksCount', { count: weeks.length })}
            borderLeft={false}
            borderTop={false}
          />
          <TotalTile
            label={t('history.kpiVolume')}
            value={`${formatTons(volumeKg)} t`}
            sub={t('history.weeksCount', { count: weeks.length })}
            borderLeft
            borderTop={false}
          />
          <TotalTile
            label={t('history.kpiTime')}
            value={formatTotalDuration(durationSec)}
            sub={t('history.inTraining')}
            borderLeft={false}
            borderTop
          />
          <TotalTile
            label={t('history.kpiFrequency')}
            value={frequency.toFixed(1)}
            sub={t('history.perWeek')}
            borderLeft
            borderTop
          />
        </div>
      </LoadingSwap>

      <div className="mt-5">
        <GymCalendar items={items} />
      </div>

      <div className="mt-5">
        <GymPersonalRecordCard />
      </div>

      <div className="mt-[22px]">
        <div className="flex items-baseline justify-between">
          <div className="text-[13.5px] font-semibold text-foreground">
            {t('overview.routinesSection.title')}
          </div>
          <div className="text-[11.5px] text-muted-foreground">
            {t('history.weeksCount', { count: WEEKS })}
          </div>
        </div>

        <div className="mt-3 flex flex-col gap-2.5">
          {routineStats.rows.map(({ template, periodCount, periodVolumeKg }, idx) => {
            const isFavorite = idx === 0 && periodCount > 0;
            const muscle = template.muscleGroups[0];
            const progressPct = (periodVolumeKg / routineStats.maxVolume) * 100;
            return (
              <div
                key={template.id}
                className="rounded-[14px] border border-border p-[14px_16px]"
              >
                <div className="flex items-center justify-between">
                  <div className="text-[10px] font-semibold tracking-[.06em] text-muted-foreground uppercase">
                    {muscle ? t(`muscles.${muscle}`, muscle) : '—'}
                  </div>
                  {isFavorite && (
                    <span className="rounded-full bg-acc-bg px-2 py-[3px] text-[10px] font-semibold text-acc-tx">
                      {t('overview.routinesSection.favorite')}
                    </span>
                  )}
                </div>
                <div className="mt-1 truncate text-[15px] font-semibold text-foreground">
                  {stripWorkoutPrefix(template.name)}
                </div>
                <div className="mt-1 flex items-baseline gap-1.5">
                  <span className="text-[20px] font-bold text-foreground">{periodCount}</span>
                  <span className="text-[11.5px] text-muted-foreground">
                    {t('overview.routinesSection.workoutsLabel', { count: periodCount })}
                  </span>
                </div>
                <div className="mt-2 h-[6px] w-full overflow-hidden rounded-[3px] bg-chip">
                  <div
                    className="h-full rounded-[3px] bg-acc"
                    style={{ width: `${Math.max(0, Math.min(100, progressPct)).toFixed(1)}%` }}
                  />
                </div>
                <div className="mt-2 text-[11.5px] text-muted-foreground">
                  {t('overview.routinesSection.meta', {
                    volume: formatTons(periodVolumeKg),
                    when: template.lastPerformedAt
                      ? t('routines.lastPerformed', {
                          when: formatLastPerformed(t, template.lastPerformedAt),
                        })
                      : t('routines.neverPerformed'),
                  })}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

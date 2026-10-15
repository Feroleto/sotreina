import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  WORKOUT_META,
  formatDayMonth,
  formatDurationShort,
  formatKm,
  formatPace,
} from '@/lib/activityFormat';
import type { BinWithRuns } from './bins';

function PeekCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[10px] bg-chip px-[13px] py-[11px]">
      <div className="text-[11px] tracking-[.03em] uppercase text-muted-foreground">
        {label}
      </div>
      <div className="mt-1 text-[15px] font-semibold text-foreground">
        {value}
      </div>
    </div>
  );
}

interface ActivityListProps {
  loading: boolean;
  groups: BinWithRuns[];
  onOpenDetail: (id: string) => void;
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  /** mobile load-more: weeks not yet shown (groups are cumulative there) */
  olderWeeks: number;
  onLoadMore: () => void;
  /** rodapé do modo "Tudo" sem range custom; null oculta */
  allModeFooter: string | null;
}

export default function ActivityList({
  loading,
  groups,
  onOpenDetail,
  currentPage,
  totalPages,
  onPageChange,
  olderWeeks,
  onLoadMore,
  allModeFooter,
}: ActivityListProps) {
  const { t } = useTranslation('dashboard');
  const [peekId, setPeekId] = useState<string | null>(null);

  if (loading) {
    return (
      <p className="py-10 text-center text-[13.5px] text-muted-foreground">
        {t('list.loading')}
      </p>
    );
  }
  if (groups.length === 0) {
    return (
      <p className="py-10 text-center text-[13.5px] text-muted-foreground">
        {t('list.empty')}
      </p>
    );
  }

  return (
    <>
      {groups.map((week) => (
        <div key={week.start.getTime()} className="mb-[26px]">
          <div className="flex items-baseline justify-between border-b border-grid-ax pb-[9px]">
            <div className="text-xs font-semibold tracking-[.04em] uppercase text-muted-foreground">
              {formatDayMonth(week.start)} –{' '}
              {formatDayMonth(
                new Date(
                  week.start.getFullYear(),
                  week.start.getMonth(),
                  week.start.getDate() + 6,
                ),
              )}
            </div>
            <div className="text-[12.5px] text-muted-foreground">
              {t('list.runsCount', { count: week.count })} · {formatKm(week.km)}{' '}
              km
            </div>
          </div>
          {week.runs.map((a) => {
            const peek = peekId === a.id;
            const meta = WORKOUT_META[a.workoutType];
            return (
              <div key={a.id} className="border-b border-border">
                <div className="flex items-center">
                  <div
                    onClick={() => {
                      onOpenDetail(a.id);
                      setPeekId(null);
                    }}
                    className="flex min-w-0 flex-1 cursor-pointer items-center gap-[13px] px-0.5 py-[13px]"
                  >
                    <div
                      className="h-2 w-2 flex-none rounded-full md:h-[7px] md:w-[7px]"
                      style={{ background: meta?.dot }}
                    />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-semibold text-foreground">
                        {a.name}
                        <span className="hidden font-normal text-muted-foreground md:inline">
                          {' '}
                          · {formatDayMonth(new Date(a.startDate))}
                        </span>
                      </div>
                      {/* mobile meta line: date · km · time */}
                      <div className="mt-[1px] text-[11.5px] text-muted-foreground md:hidden">
                        {formatDayMonth(new Date(a.startDate))} ·{' '}
                        {a.distanceKm != null
                          ? `${formatKm(a.distanceKm)} km`
                          : '—'}{' '}
                        · {formatDurationShort(a.movingTimeSec)}
                      </div>
                    </div>
                    <div className="hidden w-[72px] text-right text-[13.5px] text-muted-foreground md:block">
                      {a.distanceKm != null
                        ? `${formatKm(a.distanceKm)} km`
                        : '—'}
                    </div>
                    <div className="hidden w-16 text-right text-[13.5px] text-muted-foreground md:block">
                      {formatDurationShort(a.movingTimeSec)}
                    </div>
                    <div className="text-right text-sm font-semibold text-foreground md:w-[84px]">
                      {formatPace(a.paceRawSecKm)}
                    </div>
                    <span
                      aria-hidden="true"
                      className="text-[15px] text-muted-foreground md:hidden"
                    >
                      ›
                    </span>
                  </div>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setPeekId(peek ? null : a.id);
                    }}
                    className="ml-1 hidden h-[38px] w-[38px] cursor-pointer rounded-[9px] text-[15px] text-muted-foreground hover:bg-chip motion-safe:transition-transform motion-safe:duration-150 md:block"
                    style={{
                      transform: peek ? 'rotate(90deg)' : 'rotate(0deg)',
                    }}
                    aria-label={
                      peek ? t('list.closeSummary') : t('list.openSummary')
                    }
                    aria-expanded={peek}
                  >
                    ›
                  </button>
                </div>
                {peek && (
                  <div className="grid grid-cols-4 gap-2.5 px-5 pt-0.5 pb-4">
                    <PeekCard
                      label={t('list.elevation')}
                      value={
                        a.elevationGainM != null
                          ? `${Math.round(a.elevationGainM)} m`
                          : '—'
                      }
                    />
                    <PeekCard
                      label={t('list.avgHr')}
                      value={
                        a.averageBpm != null
                          ? `${Math.round(a.averageBpm)} bpm`
                          : '—'
                      }
                    />
                    <PeekCard
                      label={t('list.maxHr')}
                      value={
                        a.maxBpm != null ? `${Math.round(a.maxBpm)} bpm` : '—'
                      }
                    />
                    <PeekCard
                      label={t('list.cadence')}
                      value={
                        a.averageCadence != null
                          ? `${Math.round(a.averageCadence)} spm`
                          : '—'
                      }
                    />
                  </div>
                )}
              </div>
            );
          })}
        </div>
      ))}
      {/* mobile: cumulative load-more */}
      {olderWeeks > 0 && (
        <button
          onClick={onLoadMore}
          className="w-full cursor-pointer rounded-[10px] bg-chip py-3 text-[13px] font-medium text-foreground md:hidden"
        >
          {t('list.olderWeeks', { count: olderWeeks })}
        </button>
      )}
      {totalPages > 1 && (
        <div className="hidden items-center justify-between md:flex">
          <button
            onClick={() => onPageChange(currentPage - 1)}
            disabled={currentPage <= 1}
            className="cursor-pointer rounded-[9px] bg-chip px-[13px] py-[7px] text-[13px] font-medium text-foreground hover:bg-grid-ax disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-chip"
          >
            {t('list.recentWeeks')}
          </button>
          <span className="text-[12.5px] text-muted-foreground">
            {t('list.pageOf', { current: currentPage, total: totalPages })}
          </span>
          <button
            onClick={() => onPageChange(currentPage + 1)}
            disabled={currentPage >= totalPages}
            className="cursor-pointer rounded-[9px] bg-chip px-[13px] py-[7px] text-[13px] font-medium text-foreground hover:bg-grid-ax disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-chip"
          >
            {t('list.previousWeeks')}
          </button>
        </div>
      )}
      {allModeFooter != null && (
        <div className="mt-4 hidden text-center text-[12.5px] text-muted-foreground md:block">
          {allModeFooter}
        </div>
      )}
    </>
  );
}

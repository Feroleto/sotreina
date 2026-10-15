import { useEffect, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { isMobileViewport, useIsMobile } from '@/lib/useIsMobile';
import WeeklyChart, { type Granularity, type Period } from './WeeklyChart';
import MobileWeeklySummary from './MobileWeeklySummary';
import DateRangePicker, { type DateRange } from './DateRangePicker';
import Rail from './Rail';
import ActivityList from './ActivityList';
import RangeChip from './RangeChip';
import ActivityDetailView from '@/features/activity/ActivityDetailView';
import DrillStack from '@/components/DrillStack';
import { useEntrance } from '@/lib/useEntrance';
import { useActivities } from '@/lib/useActivities';
import {
  CHART_MAX_WEEKS,
  DAY_MS,
  MONTHLY_THRESHOLD_DAYS,
  WEEKS_PER_PAGE,
  aggregateBins,
  aggregateWeeks,
  formatRangeLabel,
  startOfBin,
  type TypeFilter,
} from './bins';

export default function Dashboard() {
  const { t } = useTranslation('dashboard');
  const [period, setPeriod] = useState<Period>('12');
  const [dateRange, setDateRange] = useState<DateRange | null>(null);
  const [typeFilter, setTypeFilter] = useState<TypeFilter>('ALL');
  const [detailId, setDetailId] = useState<string | null>(null);
  const [weekPage, setWeekPage] = useState(1);
  const [refreshKey, setRefreshKey] = useState(0);
  const { activities, loading, error } = useActivities(refreshKey);
  const { attach: enterRef, state: enterState } = useEntrance('run/activities', { ready: !loading });
  const isMobile = useIsMobile();

  // mobile: the detail view is pushed onto browser history so the hardware /
  // gesture back closes it instead of leaving the app
  const pushedDetailRef = useRef(false);

  useEffect(() => {
    const onPop = () => {
      // back may be popping the drawer's own entry (MobileChrome) while the
      // detail entry is still on the stack — in that case the detail stays
      if (window.history.state?.activityDetail) return;
      pushedDetailRef.current = false;
      setDetailId(null);
    };
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, []);

  const openDetail = (id: string) => {
    setDetailId(id);
    if (isMobileViewport()) {
      window.history.pushState({ activityDetail: true }, '');
      pushedDetailRef.current = true;
    }
  };

  const closeDetail = () => {
    if (pushedDetailRef.current) {
      window.history.back();
    } else {
      setDetailId(null);
    }
  };

  const isAll = period === 'all';
  const n = isAll ? 0 : parseInt(period, 10);
  const rangeActive = dateRange != null;
  const rangeDays = dateRange
    ? Math.round((dateRange.end - dateRange.start) / DAY_MS) + 1
    : 0;

  const earliestDate = useMemo(
    () =>
      activities.length > 0
        ? new Date(
            activities.reduce(
              (min, a) => (a.startDate < min ? a.startDate : min),
              activities[0].startDate,
            ),
          )
        : undefined,
    [activities],
  );

  // activities in the custom range
  const inRange = useMemo(
    () =>
      dateRange
        ? activities.filter((a) => {
            const t = new Date(a.startDate).getTime();
            return t >= dateRange.start && t < dateRange.end + DAY_MS;
          })
        : activities,
    [activities, dateRange],
  );

  // weekly beens
  const weeks = useMemo(() => {
    if (dateRange) {
      return aggregateBins(
        inRange,
        typeFilter,
        'week',
        new Date(dateRange.start),
        startOfBin(new Date(dateRange.end), 'week'),
      );
    }
    if (isAll) {
      // "All": every week from the first activity to now
      return aggregateBins(
        activities,
        typeFilter,
        'week',
        earliestDate ?? new Date(),
        startOfBin(new Date(), 'week'),
      );
    }
    return aggregateWeeks(activities, n, typeFilter);
  }, [activities, inRange, dateRange, isAll, earliestDate, n, typeFilter]);

  // mobile KPI carousel + bars: last 12 weeks by default (unfiltered — the
  // mobile screen has no type filter), or the custom range when one is set
  const mobileWeeks = useMemo(() => {
    if (dateRange) {
      return aggregateBins(
        inRange,
        'ALL',
        'week',
        new Date(dateRange.start),
        startOfBin(new Date(dateRange.end), 'week'),
      );
    }
    return aggregateWeeks(activities, 12, 'ALL');
  }, [dateRange, inRange, activities]);

  const chartGranularity: Granularity =
    (rangeActive && rangeDays > MONTHLY_THRESHOLD_DAYS) ||
    (!rangeActive && isAll)
      ? 'month'
      : 'week';

  const chartBins = useMemo(() => {
    if (dateRange) {
      if (chartGranularity === 'week') return weeks;
      return aggregateBins(
        inRange,
        typeFilter,
        'month',
        new Date(dateRange.start),
        startOfBin(new Date(dateRange.end), 'month'),
      );
    }
    if (isAll && earliestDate) {
      // cap the chart at the last 70 weeks so months don't get squeezed;
      // stats/list still cover everything
      const chartFrom = startOfBin(new Date(), 'week');
      chartFrom.setDate(chartFrom.getDate() - 7 * (CHART_MAX_WEEKS - 1));
      return aggregateBins(
        activities,
        typeFilter,
        'month',
        earliestDate > chartFrom ? earliestDate : chartFrom,
        startOfBin(new Date(), 'month'),
      );
    }
    return weeks;
  }, [
    dateRange,
    chartGranularity,
    weeks,
    inRange,
    isAll,
    earliestDate,
    activities,
    typeFilter,
  ]);

  const totals = useMemo(() => {
    const runs = weeks.flatMap((w) => w.runs);
    return {
      km: weeks.reduce((s, w) => s + w.km, 0),
      sec: weeks.reduce((s, w) => s + w.sec, 0),
      count: runs.length,
      elev: runs.reduce((s, a) => s + (a.elevationGainM ?? 0), 0),
    };
  }, [weeks]);

  const typeCounts = useMemo(() => {
    const periodStart = weeks[0]?.start;
    const scoped = dateRange
      ? inRange
      : periodStart
        ? activities.filter((a) => new Date(a.startDate) >= periodStart)
        : [];
    const counts: Record<string, number> = { ALL: scoped.length };
    for (const a of scoped) {
      counts[a.workoutType] = (counts[a.workoutType] ?? 0) + 1;
    }
    return counts;
  }, [activities, inRange, dateRange, weeks]);

  const weekGroups = useMemo(
    () => [...weeks].reverse().filter((w) => w.count > 0),
    [weeks],
  );
  const totalWeekPages = Math.max(
    1,
    Math.ceil(weekGroups.length / WEEKS_PER_PAGE),
  );
  // clamp instead of trusting state: a refetch or filter change can shrink the list
  const currentWeekPage = Math.min(weekPage, totalWeekPages);
  // mobile appends older weeks ("load more") instead of swapping pages
  const shownGroups = isMobile
    ? weekGroups.slice(0, currentWeekPage * WEEKS_PER_PAGE)
    : weekGroups.slice(
        (currentWeekPage - 1) * WEEKS_PER_PAGE,
        currentWeekPage * WEEKS_PER_PAGE,
      );
  const olderWeeks = Math.max(
    0,
    weekGroups.length - currentWeekPage * WEEKS_PER_PAGE,
  );

  const avgPace = totals.km > 0 ? totals.sec / totals.km : null;

  const applyRange = (range: DateRange | null) => {
    setDateRange(range);
    setWeekPage(1);
  };

  if (error) {
    return (
      <p className="p-10 text-center text-[13.5px] text-neg">
        {t('common:error', { message: error })}
      </p>
    );
  }

  return (
    <div className="grid grid-cols-1 px-5 pt-[18px] pb-[44px] tabular-nums md:grid-cols-[264px_1fr] md:gap-11 md:p-10">
      {/* the Rail (period subtitle, type filter, sync panel) is desktop-only */}
      <div className="hidden md:block">
        <Rail
          subtitle={
            dateRange
              ? formatRangeLabel(dateRange)
              : isAll
                ? t('rail.allRuns')
                : t('rail.lastNWeeks', { count: n })
          }
          totals={totals}
          avgPace={avgPace}
          typeFilter={typeFilter}
          onTypeFilter={(type) => {
            setTypeFilter(type);
            setWeekPage(1);
          }}
          typeCounts={typeCounts}
          onSynced={() => setRefreshKey((k) => k + 1)}
        />
      </div>

      {/* right panel: detail view swaps in-place with the list. Mobile
          bleeds past the grid's px-5 so the push reaches the screen edge */}
      <div className="min-w-0">
        <DrillStack
          depth={detailId ? 1 : 0}
          viewKey={detailId ? `activity:${detailId}` : 'list'}
          className="max-md:-mx-5"
          screenClassName="max-md:px-5"
        >
          {detailId ? (
            <ActivityDetailView id={detailId} onBack={closeDetail} />
          ) : (
            // chart line draws / bars grow / week groups rise, once per session
            <div ref={enterRef} data-enter={enterState}>
              <div className="hidden md:block">
                <WeeklyChart
                  bins={chartBins}
                  granularity={chartGranularity}
                  totalKm={totals.km}
                  period={period}
                  onPeriodChange={(p) => {
                    setPeriod(p);
                    setWeekPage(1);
                    setDateRange(null);
                  }}
                  onSelect={
                    isAll && !rangeActive
                      ? (ms) => {
                          const s = new Date(ms);
                          applyRange({
                            start: ms,
                            end: new Date(
                              s.getFullYear(),
                              s.getMonth() + 1,
                              0,
                            ).getTime(),
                          });
                        }
                      : undefined
                  }
                >
                  <DateRangePicker
                    range={dateRange}
                    onChange={applyRange}
                    minDate={earliestDate}
                  />
                </WeeklyChart>
              </div>

              <MobileWeeklySummary weeks={mobileWeeks}>
                <DateRangePicker
                  range={dateRange}
                  onChange={applyRange}
                  minDate={earliestDate}
                  maxMonths={3}
                />
              </MobileWeeklySummary>

              {dateRange && (
                <RangeChip
                  label={formatRangeLabel(dateRange)}
                  count={totals.count}
                  km={totals.km}
                  days={rangeDays}
                  onClear={() => applyRange(null)}
                />
              )}

              <ActivityList
                loading={loading}
                groups={shownGroups}
                onOpenDetail={openDetail}
                currentPage={currentWeekPage}
                totalPages={totalWeekPages}
                onPageChange={setWeekPage}
                olderWeeks={olderWeeks}
                onLoadMore={() => setWeekPage(currentWeekPage + 1)}
                allModeFooter={
                  isAll && !rangeActive
                    ? olderWeeks > 0
                      ? `${t('list.olderWeeks', { count: olderWeeks })} · ${t('list.selectMonth')}`
                      : t('list.selectMonth')
                    : null
                }
              />
            </div>
          )}
        </DrillStack>
      </div>
    </div>
  );
}

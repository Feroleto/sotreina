import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useActivities } from '@/lib/useActivities';
import {
  formatDuration,
  formatDistance,
  formatMonthShortYear,
  formatNumber,
  formatPace,
} from '@/lib/activityFormat';
import RunCalendar from './RunCalendar';
import PersonalRecordsCard from './PersonalRecordsCard';
import ShoesSection from './ShoesSection';
import { LoadingSwap, Skeleton } from '@/components/Skeleton';
import { PoweredByStrava } from '@/components/StravaBrand';
import { distanceLabel } from '@/lib/units';

// mobile 2×2 hairline grid (Redesign Corrida 17b "Monolito": no cards,
// numbers in Geist Mono) — right column and second row draw the dividers
function MobileTotalCard({
  label,
  value,
  sub,
  index,
}: {
  label: string;
  value: string;
  sub?: string;
  index: number;
}) {
  return (
    <div
      className={`py-3.5 ${index % 2 === 1 ? 'border-l border-border pl-3.5' : ''} ${
        index >= 2 ? 'border-t border-border' : ''
      }`}
    >
      <div className="text-[12px] text-muted-foreground">{label}</div>
      <div className="mt-1 font-mono text-[20px] font-medium text-foreground">
        {value}
      </div>
      {sub && (
        <div className="mt-[2px] text-[11.5px] text-muted-foreground">
          {sub}
        </div>
      )}
    </div>
  );
}

function TotalTile({
  label,
  value,
  sub,
  bordered,
}: {
  label: string;
  value: string;
  sub?: string;
  bordered: boolean;
}) {
  return (
    <div className={`px-[22px] ${bordered ? 'border-l border-border' : ''}`}>
      <div className="text-[10.5px] font-semibold tracking-[.07em] text-muted-foreground uppercase">
        {label}
      </div>
      <div className="mt-[5px] text-[26px] font-bold tracking-[-.02em] text-foreground">
        {value}
      </div>
      {sub && (
        <div className="mt-[3px] text-[11.5px] text-muted-foreground">
          {sub}
        </div>
      )}
    </div>
  );
}

// mobile 2×2 cards / desktop 4 divided tiles, same footprint as the totals
function TotalsSkeleton() {
  return (
    <>
      <div className="grid grid-cols-2 gap-3 md:hidden">
        {[0, 1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-[72px]" />
        ))}
      </div>
      <div className="mt-6 hidden grid-cols-4 md:grid">
        {[0, 1, 2, 3].map((i) => (
          <div
            key={i}
            className={`px-[22px] ${i > 0 ? 'border-l border-border' : ''}`}
          >
            <Skeleton className="h-[12px] w-[60%]" />
            <Skeleton className="mt-[9px] h-[30px] w-[75%]" />
            <Skeleton className="mt-2 h-[12px] w-[50%]" />
          </div>
        ))}
      </div>
    </>
  );
}

export default function RunOverviewPage() {
  const { t } = useTranslation('overview');
  const { activities, loading, error } = useActivities();
  // snapshot "now" once per mount rather than calling Date.now() during
  // render/useMemo (React purity rule) — a stats page doesn't need
  // second-by-second freshness here
  const [now] = useState(() => Date.now());

  const totals = useMemo(() => {
    if (activities.length === 0) return null;

    const totalKm = activities.reduce((s, a) => s + (a.distanceKm ?? 0), 0);
    const totalSec = activities.reduce((s, a) => s + a.movingTimeSec, 0);
    const totalElev = activities.reduce(
      (s, a) => s + (a.elevationGainM ?? 0),
      0,
    );
    const bestElev = activities.reduce(
      (m, a) => Math.max(m, a.elevationGainM ?? 0),
      0,
    );
    const earliest = activities.reduce(
      (min, a) => (a.startDate < min ? a.startDate : min),
      activities[0].startDate,
    );
    const earliestDate = new Date(earliest);
    const weeks = Math.max(
      1,
      (now - earliestDate.getTime()) / (7 * 24 * 60 * 60 * 1000),
    );

    return {
      count: activities.length,
      since: formatMonthShortYear(earliestDate),
      totalKm,
      kmPerWeek: totalKm / weeks,
      totalSec,
      avgPaceSecKm: totalKm > 0 ? totalSec / totalKm : null,
      totalElev,
      bestElev,
    };
  }, [activities, now]);

  if (error) {
    return (
      <p className="p-10 text-center text-[13.5px] text-neg">
        {t('common:error', { message: error })}
      </p>
    );
  }

  return (
    <div className="px-[22px] pt-5 pb-[44px] tabular-nums md:p-[30px_34px_34px]">
      {/* on mobile the section title lives in the header (MobileChrome) */}
      <div className="hidden md:block">
        <h1 className="text-[19px] font-semibold tracking-[-.01em] text-foreground">
          {t('title')}
        </h1>
        <p className="mt-[2px] text-[12.5px] text-muted-foreground">
          {t('subtitle')}
        </p>
      </div>

      <LoadingSwap loading={loading} skeleton={<TotalsSkeleton />}>
        {/* mobile totals — 2×2 hairline grid instead of the 4 desktop tiles */}
        <div className="grid grid-cols-2 border-y border-border md:hidden">
          <MobileTotalCard
            index={0}
            label={t('tiles.distance')}
            value={`${formatDistance(totals?.totalKm ?? 0)} ${distanceLabel()}`}
            sub={
              totals
                ? t('tiles.kmPerWeek', {
                    unit: distanceLabel(),
                    km: formatDistance(totals.kmPerWeek),
                  })
                : undefined
            }
          />
          <MobileTotalCard
            index={1}
            label={t('tiles.activities')}
            value={String(totals?.count ?? 0)}
            sub={totals ? t('tiles.since', { date: totals.since }) : undefined}
          />
          <MobileTotalCard
            index={2}
            label={t('tiles.avgPaceLabel')}
            value={formatPace(totals?.avgPaceSecKm ?? null)}
          />
          <MobileTotalCard
            index={3}
            label={t('tiles.totalTime')}
            value={formatDuration(totals?.totalSec ?? 0)}
          />
        </div>

        <div className="mt-6 hidden grid-cols-4 md:grid">
          <TotalTile
            label={t('tiles.totalRuns')}
            bordered={false}
            value={String(totals?.count ?? 0)}
            sub={totals ? t('tiles.since', { date: totals.since }) : undefined}
          />
          <TotalTile
            label={t('tiles.distance')}
            bordered
            value={`${formatDistance(totals?.totalKm ?? 0)} ${distanceLabel()}`}
            sub={
              totals
                ? t('tiles.kmPerWeek', {
                    unit: distanceLabel(),
                    km: formatDistance(totals.kmPerWeek),
                  })
                : undefined
            }
          />
          <TotalTile
            label={t('tiles.time')}
            bordered
            value={formatDuration(totals?.totalSec ?? 0)}
            sub={
              totals
                ? t('tiles.avgPace', { pace: formatPace(totals.avgPaceSecKm) })
                : undefined
            }
          />
          <TotalTile
            label={t('tiles.elevation')}
            bordered
            value={`${formatNumber(Math.round(totals?.totalElev ?? 0))} m`}
            sub={
              totals
                ? t('tiles.bestElevation', {
                    value: formatNumber(Math.round(totals.bestElev)),
                  })
                : undefined
            }
          />
        </div>
      </LoadingSwap>

      <div className="mt-[26px] grid grid-cols-1 items-stretch gap-6 md:grid-cols-[340px_1fr] md:gap-[18px]">
        <RunCalendar activities={activities} />
        <PersonalRecordsCard activities={activities} />
      </div>

      <div className="mt-[26px]">
        <ShoesSection />
      </div>

      <PoweredByStrava className="mt-8 justify-center" />
    </div>
  );
}

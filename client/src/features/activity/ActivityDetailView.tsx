import { lazy, Suspense, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  WORKOUT_META,
  formatDurationShort,
  formatKm,
  formatMinSec,
  formatPace,
  lapLabels,
} from '@/lib/activityFormat';
import { currentIntlLocale } from '@/lib/dateLocale';
import type { ActivityDetail } from '@/lib/types';
import { apiFetch } from '@/lib/api';
import { PoweredByStrava } from '@/components/StravaBrand';
import { DelayedSkeleton, Skeleton } from '@/components/Skeleton';

// lazy so Leaflet is only fetched when a GPS activity detail is opened
const RouteMap = lazy(() => import('./RouteMap'));
// lazy so the editor's fetch/form logic only loads when actually opened
const LapEditorPanel = lazy(() => import('./lap-editor/LapEditorPanel'));

const MAP_W = 640;
const MAP_H = 240;

function formatDateFull(iso: string): string {
  const d = new Date(iso);
  const locale = currentIntlLocale();
  const date = d.toLocaleDateString(locale, {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
  });
  const time = d.toLocaleTimeString(locale, {
    hour: '2-digit',
    minute: '2-digit',
  });
  return `${date.charAt(0).toUpperCase()}${date.slice(1)} · ${time}`;
}

function StatCard({
  label,
  value,
  desktopOnly,
}: {
  label: string;
  value: string;
  desktopOnly?: boolean;
}) {
  return (
    <div
      className={`rounded-xl border border-border bg-card px-[15px] py-[13px] transition-[background] duration-[250ms] ${
        desktopOnly ? 'hidden md:block' : ''
      }`}
    >
      <div className="text-[11px] tracking-[.03em] uppercase text-muted-foreground">
        {label}
      </div>
      <div className="mt-[5px] text-[17px] font-semibold text-foreground">
        {value}
      </div>
    </div>
  );
}

interface ActivityDetailViewProps {
  id: string;
  onBack: () => void;
}

export default function ActivityDetailView({
  id,
  onBack,
}: ActivityDetailViewProps) {
  const { t } = useTranslation('activity');
  const [activity, setActivity] = useState<ActivityDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [editorOpen, setEditorOpen] = useState(false);

  useEffect(() => {
    setActivity(null);
    apiFetch(`/activities/${id}`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data: ActivityDetail) => setActivity(data))
      .catch((err) => setError(err.message));
  }, [id]);

  if (error) {
    return (
      <p className="py-10 text-center text-[13.5px] text-neg">
        {t('common:error', { message: error })}
      </p>
    );
  }
  if (!activity) {
    // same layout as the loaded view, with the real back button so the user
    // isn't stuck while a slow detail loads
    return (
      <div>
        <div className="mb-5 flex items-center justify-between">
          <button
            onClick={onBack}
            className="cursor-pointer rounded-[9px] bg-chip py-[7px] pr-[13px] pl-2.5 text-[13px] font-medium text-foreground hover:bg-grid-ax"
          >
            {t('return')}
          </button>
        </div>
        <DelayedSkeleton>
          <Skeleton className="h-[26px] w-[55%]" />
          <Skeleton className="mt-2 h-[13px] w-[35%]" />
          <div className="mt-[22px] grid grid-cols-2 gap-2.5 md:grid-cols-4">
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-[66px] rounded-xl" />
            ))}
          </div>
          <Skeleton className="mt-[22px] aspect-8/3 rounded-[var(--rad)]" />
        </DelayedSkeleton>
      </div>
    );
  }

  const meta = WORKOUT_META[activity.workoutType];
  const timedLaps = activity.laps.filter((l) => l.avgPaceSecKm > 0);
  const fastestPace =
    timedLaps.length > 0
      ? Math.min(...timedLaps.map((l) => l.avgPaceSecKm))
      : null;
  const labels = lapLabels(activity.laps, t);

  // desktopOnly trims the mobile grid to the 6 headline cards
  const stats: [string, string, boolean?][] = [
    [
      t('stats.distance'),
      activity.distanceKm != null ? `${formatKm(activity.distanceKm)} km` : '—',
    ],
    [t('stats.time'), formatDurationShort(activity.movingTimeSec)],
    [t('stats.pace'), formatPace(activity.paceRawSecKm)],
    [
      t('stats.elevation'),
      activity.elevationGainM != null
        ? `${Math.round(activity.elevationGainM)} m`
        : '—',
    ],
    [
      t('stats.avgHr'),
      activity.averageBpm != null
        ? `${Math.round(activity.averageBpm)} bpm`
        : '—',
    ],
    [
      t('stats.maxHr'),
      activity.maxBpm != null ? `${Math.round(activity.maxBpm)} bpm` : '—',
      true,
    ],
    [
      t('stats.cadence'),
      activity.averageCadence != null
        ? `${Math.round(activity.averageCadence)} spm`
        : '—',
    ],
    [t('stats.bestPace'), formatPace(fastestPace), true],
  ];

  return (
    <div className="content-fade-in">
      <div className="mb-5 flex items-center justify-between">
        <button
          onClick={onBack}
          className="cursor-pointer rounded-[9px] bg-chip py-[7px] pr-[13px] pl-2.5 text-[13px] font-medium text-foreground hover:bg-grid-ax"
        >
          {t('return')}
        </button>
        <div
          className="rounded-full px-2.5 py-1 text-[11.5px] font-semibold"
          style={{ background: meta?.badgeBg, color: meta?.badgeColor }}
        >
          {meta ? t(`common:${meta.labelKey}`) : activity.workoutType}
        </div>
      </div>

      <div className="text-[22px] font-semibold tracking-[-.02em] text-foreground">
        {activity.name}
      </div>
      <div className="mt-[3px] flex flex-wrap items-baseline gap-x-3 text-[13px] text-muted-foreground">
        {formatDateFull(activity.startDate)}
        {/* brand guidelines: this exact text (not translated), legible and
            marked as a link via bold weight or Strava orange #FC5200 */}
        <a
          href={`https://www.strava.com/activities/${activity.stravaId}`}
          target="_blank"
          rel="noopener noreferrer"
          className="font-semibold text-[#FC5200] hover:underline"
        >
          View on Strava
        </a>
      </div>

      <div className="mt-[22px] grid grid-cols-2 gap-2.5 md:grid-cols-4">
        {stats.map(([label, value, desktopOnly]) => (
          <StatCard
            key={label}
            label={label}
            value={value}
            desktopOnly={desktopOnly}
          />
        ))}
      </div>

      <div className="mt-[22px] overflow-hidden rounded-[var(--rad)] border border-border bg-card transition-[background] duration-[250ms]">
        {activity.summaryPolyline ? (
          <Suspense fallback={<div className="aspect-8/3 w-full" />}>
            <RouteMap polyline={activity.summaryPolyline} />
          </Suspense>
        ) : (
          <svg viewBox={`0 0 ${MAP_W} ${MAP_H}`} className="block w-full">
            {[80, 160, 240, 320, 400, 480, 560].map((x) => (
              <line
                key={x}
                x1={x}
                y1="0"
                x2={x}
                y2={MAP_H}
                stroke="var(--border)"
              />
            ))}
            {[60, 120, 180].map((y) => (
              <line
                key={y}
                x1="0"
                y1={y}
                x2={MAP_W}
                y2={y}
                stroke="var(--border)"
              />
            ))}
            <text
              x={MAP_W / 2}
              y={MAP_H / 2 + 4}
              textAnchor="middle"
              fontSize="13"
              fill="var(--muted-foreground)"
            >
              {t('noGps')}
            </text>
          </svg>
        )}
      </div>

      <div className="mt-7 flex items-baseline justify-between border-b border-grid-ax pb-[9px]">
        <div className="text-xs font-semibold tracking-[.04em] uppercase text-muted-foreground">
          {t('laps.title')}
        </div>
        <div className="text-[12.5px] text-muted-foreground">
          {t('laps.count', { count: activity.laps.length })}
        </div>
      </div>
      {activity.laps.length > 0 && (
        <>
          <div className="flex items-center gap-1.5 px-0.5 pt-[9px] pb-[7px] text-[11px] tracking-[.03em] uppercase text-muted-foreground md:gap-[13px]">
            <div className="w-[22px]">{t('laps.index')}</div>
            <div className="w-[84px] md:w-[110px]">{t('laps.lap')}</div>
            <div className="hidden flex-1 md:block" />
            <div className="w-[58px] text-right md:w-[66px]">
              {t('laps.dist')}
            </div>
            <div className="w-11 text-right md:w-14">{t('laps.time')}</div>
            <div className="w-14 text-right md:w-16">{t('laps.pace')}</div>
            <div className="hidden w-11 text-right md:block">
              {t('laps.spm')}
            </div>
            <div className="w-11 text-right">{t('laps.avgHr')}</div>
            <div className="hidden w-11 text-right md:block">
              {t('laps.maxHr')}
            </div>
          </div>
          {activity.laps.map((lap, i) => (
            <div
              key={lap.id}
              className="flex items-center gap-1.5 border-b border-border px-0.5 py-2.5 md:gap-[13px]"
            >
              <div className="w-[22px] text-[12.5px] text-muted-foreground">
                {lap.lapIndex}
              </div>
              <div className="w-[84px] truncate text-[13.5px] font-medium text-foreground md:w-[110px]">
                {labels[i]}
              </div>
              <div className="hidden h-1.5 flex-1 overflow-hidden rounded-[3px] bg-chip md:block">
                {fastestPace != null && lap.avgPaceSecKm > 0 && (
                  <div
                    className="h-full rounded-[3px]"
                    style={{
                      width: `${((fastestPace / lap.avgPaceSecKm) * 100).toFixed(0)}%`,
                      background:
                        'color-mix(in oklab, var(--acc) 75%, transparent)',
                    }}
                  />
                )}
              </div>
              <div className="w-[58px] text-right text-[13px] text-muted-foreground md:w-[66px]">
                {(lap.distanceM / 1000).toFixed(2)} km
              </div>
              <div className="w-11 text-right text-[13px] text-muted-foreground md:w-14">
                {formatMinSec(lap.movingDurationSec)}
              </div>
              <div className="w-14 text-right text-[13.5px] font-semibold text-foreground md:w-16">
                {formatPace(lap.avgPaceSecKm).replace(' /km', '')}
              </div>
              <div className="hidden w-11 text-right text-[13px] text-muted-foreground md:block">
                {lap.avgCadence != null && lap.avgCadence > 0
                  ? Math.round(lap.avgCadence)
                  : '-'}
              </div>
              <div className="w-11 text-right text-[13px] text-muted-foreground">
                {lap.avgHr > 0 ? Math.round(lap.avgHr) : '—'}
              </div>
              <div className="hidden w-11 text-right text-[13px] text-muted-foreground md:block">
                {lap.maxHr != null && lap.maxHr > 0
                  ? Math.round(lap.maxHr)
                  : '—'}
              </div>
            </div>
          ))}
        </>
      )}
      <div className="mt-3 flex justify-end">
        <button
          onClick={() => setEditorOpen(true)}
          className="cursor-pointer rounded-[9px] bg-chip py-[7px] px-[13px] text-[13px] font-medium text-foreground hover:bg-grid-ax"
        >
          {t('laps.edit')}
        </button>
      </div>

      <PoweredByStrava className="mt-8 justify-center" />

      {editorOpen && (
        <Suspense fallback={null}>
          <LapEditorPanel
            activity={activity}
            onClose={() => setEditorOpen(false)}
            onSaved={(updated) => {
              setActivity(updated);
              setEditorOpen(false);
            }}
          />
        </Suspense>
      )}
    </div>
  );
}

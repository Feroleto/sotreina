import type { CSSProperties } from 'react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDayMonth, formatDistance } from '@/lib/activityFormat';
import { sliceByPeriod, type AnalysisPeriod } from './period';
import type { WeekMetrics } from './useTrainingMetrics';
import AnalysisCard from './AnalysisCard';
import ChartGrid from './ChartGrid';
import HoverStrip from './HoverStrip';
import AxisLabels from './AxisLabels';

const VB_W = 520;
const VB_H = 230;
const TOP_Y = 28;
const AXIS_Y = 200;
const PLOT_H = AXIS_Y - TOP_Y;

function pctZ2(ws: WeekMetrics[]): number {
  const km = ws.reduce((s, w) => s + w.km, 0);
  const z2 = ws.reduce((s, w) => s + w.z2Km, 0);
  return km > 0 ? (z2 / km) * 100 : 0;
}

export default function Z2StackedChart({
  weeks,
  hasMaxHr = true,
}: {
  weeks: WeekMetrics[];
  /** false when the user hasn't configured a max HR yet — the Z2 upper bound
   * is a 150bpm placeholder in that case, not a real %maxHR cutoff */
  hasMaxHr?: boolean;
}) {
  const { t } = useTranslation('analysis');
  const [period, setPeriod] = useState<AnalysisPeriod>('12');
  const [hover, setHover] = useState<number | null>(null);

  const visible = sliceByPeriod(weeks, period);
  const n = visible.length;
  const maxKm = Math.max(1, ...visible.map((w) => w.km));
  const noHrData = visible.reduce((s, w) => s + w.hrKm, 0) === 0;

  const x = (i: number) => ((i + 0.5) / n) * VB_W;
  const y = (v: number) => AXIS_Y - (v / maxKm) * PLOT_H;
  const barW = Math.min(46, (VB_W / Math.max(n, 1)) * 0.6);

  const cur = pctZ2(visible.slice(-4));
  const prev = pctZ2(visible.slice(-8, -4));
  // three tiers of confidence for the Z2 cutoff itself: real Strava zone
  // data (no caveat) > maxHr-derived 70% estimate > 150bpm placeholder. Bars
  // and the % shown stay distance-based (z2Km/km) in all three cases — real
  // zone data only upgrades this trailing caveat, not the visual encoding
  const allWeeksHaveRealZ2 =
    visible.length > 0 && visible.every((w) => w.z2TimeSec !== null);
  const tierCaveat = allWeeksHaveRealZ2
    ? ''
    : hasMaxHr
      ? t('z2Stacked.tierEstimatedMaxHr')
      : t('z2Stacked.tierPlaceholder');
  const insight =
    (noHrData
      ? t('z2Stacked.insightNoHr')
      : t('z2Stacked.insight', {
          pct: pctZ2(visible).toFixed(0),
          trend: t(`z2Stacked.trend.${cur >= prev ? 'rising' : 'falling'}`),
        })) + tierCaveat;

  const hov = hover !== null && visible[hover] ? hover : null;
  const hoverReading =
    hov !== null
      ? (() => {
          const w = visible[hov];
          const pct = w.km > 0 ? (w.z2Km / w.km) * 100 : 0;
          return t('z2Stacked.hoverReading', {
            date: formatDayMonth(w.start),
            z2km: formatDistance(w.z2Km, 'KM'),
            km: formatDistance(w.km, 'KM'),
            pct: pct.toFixed(0),
          });
        })()
      : null;

  return (
    <AnalysisCard
      title={t('z2Stacked.title')}
      period={period}
      onPeriodChange={setPeriod}
      insight={insight}
      hoverReading={hoverReading}
    >
      <div className="relative mt-[10px]">
        <svg viewBox={`0 0 ${VB_W} ${VB_H}`} className="block w-full">
          <ChartGrid width={VB_W} top={TOP_Y} bottom={AXIS_Y} />

          <g>
            <circle cx={VB_W - 132} cy={16} r={3.5} fill="var(--pos)" />
            <text
              x={VB_W - 124}
              y={19.5}
              fontSize="10"
              fill="var(--muted-foreground)"
            >
              {t('z2Stacked.legendZ2')}
            </text>
            <circle
              cx={VB_W - 96}
              cy={16}
              r={3.5}
              fill="var(--neg)"
              fillOpacity={0.45}
            />
            <text
              x={VB_W - 88}
              y={19.5}
              fontSize="10"
              fill="var(--muted-foreground)"
            >
              {t('z2Stacked.legendAboveZ2')}
            </text>
          </g>

          {visible.map((w, i) => {
            const isHover = hov === i;
            const z2Top = y(w.z2Km);
            const totalTop = y(w.km);
            return (
              <g key={w.start.getTime()}>
                <rect
                  className="chart-bar"
                  style={{ '--i': i } as CSSProperties}
                  x={x(i) - barW / 2}
                  y={z2Top}
                  width={barW}
                  height={Math.max(0, AXIS_Y - z2Top)}
                  fill="var(--pos)"
                />
                <rect
                  className="chart-bar"
                  style={{ '--i': i } as CSSProperties}
                  x={x(i) - barW / 2}
                  y={totalTop}
                  width={barW}
                  height={Math.max(0, z2Top - totalTop)}
                  fill="var(--neg)"
                  opacity={isHover ? 0.75 : 0.45}
                />
                {n <= 13 && w.km > 0 && (
                  <text
                    x={x(i)}
                    y={totalTop - 6}
                    fontSize="10"
                    textAnchor="middle"
                    fill="var(--muted-foreground)"
                  >
                    {formatDistance(w.km, 'KM')}
                  </text>
                )}
              </g>
            );
          })}
        </svg>
        <HoverStrip
          count={n}
          onEnter={setHover}
          onLeave={() => setHover(null)}
        />
      </div>
      <AxisLabels dates={visible.map((w) => w.start)} />
    </AnalysisCard>
  );
}

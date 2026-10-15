import type { CSSProperties } from 'react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { ActivityLapPoint } from '@/lib/types';
import { sliceByPeriod, type AnalysisPeriod } from './period';
import type { WeekMetrics } from './useTrainingMetrics';
import AnalysisCard from './AnalysisCard';
import ChartGrid from './ChartGrid';
import HoverStrip from './HoverStrip';

const VB_W = 520;
const VB_H = 230;
const TOP_Y = 28;
const AXIS_Y = 200;
const PLOT_H = AXIS_Y - TOP_Y;

interface PaceBin {
  label: string;
  test: (paceSecKm: number) => boolean;
}

const BINS: PaceBin[] = [
  { label: '<5:00', test: (p) => p < 300 },
  { label: '5:00–5:30', test: (p) => p >= 300 && p < 330 },
  { label: '5:30–6:00', test: (p) => p >= 330 && p < 360 },
  { label: '6:00–6:30', test: (p) => p >= 360 && p < 390 },
  { label: '>6:30', test: (p) => p >= 390 },
];

export default function PaceZoneHistogram({
  laps,
  weeks,
}: {
  laps: ActivityLapPoint[];
  weeks: WeekMetrics[];
}) {
  const { t } = useTranslation('analysis');
  const [period, setPeriod] = useState<AnalysisPeriod>('12');
  const [hover, setHover] = useState<number | null>(null);

  const visibleWeeks = sliceByPeriod(weeks, period);
  const cutoff = visibleWeeks[0]?.start ?? new Date(0);
  // bucketed per lap, not per run — an interval workout's hard-rep laps and
  // its warmup/cooldown laps land in different bins instead of collapsing
  // into the whole run's single average pace
  const lapsInPeriod = laps.filter(
    (l) => new Date(l.activityStartDate) >= cutoff,
  );

  const kmPerBin = BINS.map((bin) =>
    lapsInPeriod
      .filter((l) => bin.test(l.avgPaceSecKm))
      .reduce((s, l) => s + l.distanceM / 1000, 0),
  );
  const countPerBin = BINS.map(
    (bin) => lapsInPeriod.filter((l) => bin.test(l.avgPaceSecKm)).length,
  );

  const n = BINS.length;
  const maxKm = Math.max(1, ...kmPerBin);
  const totalKm = kmPerBin.reduce((s, v) => s + v, 0);

  const x = (i: number) => ((i + 0.5) / n) * VB_W;
  const y = (v: number) => AXIS_Y - (v / maxKm) * PLOT_H;
  const barW = Math.min(64, (VB_W / n) * 0.55);

  const maxBinIdx = kmPerBin.reduce(
    (best, v, i) => (v > kmPerBin[best] ? i : best),
    0,
  );
  const insight =
    totalKm > 0
      ? t('paceZoneHistogram.insight', {
          pct: ((kmPerBin[maxBinIdx] / totalKm) * 100).toFixed(0),
          label: BINS[maxBinIdx].label,
        })
      : t('paceZoneHistogram.insightEmpty');

  const hov = hover !== null ? hover : null;
  const hoverReading =
    hov !== null
      ? t('paceZoneHistogram.hoverReading', {
          label: BINS[hov].label,
          km: kmPerBin[hov].toFixed(1),
          laps: t('paceZoneHistogram.lapsCount', { count: countPerBin[hov] }),
        })
      : null;

  return (
    <AnalysisCard
      title={t('paceZoneHistogram.title')}
      period={period}
      onPeriodChange={setPeriod}
      insight={insight}
      hoverReading={hoverReading}
    >
      <div className="relative mt-[10px]">
        <svg viewBox={`0 0 ${VB_W} ${VB_H}`} className="block w-full">
          <ChartGrid width={VB_W} top={TOP_Y} bottom={AXIS_Y} />
          {BINS.map((bin, i) => (
            <g key={bin.label}>
              <rect
                className="chart-bar"
                style={{ '--i': i } as CSSProperties}
                x={x(i) - barW / 2}
                y={y(kmPerBin[i])}
                width={barW}
                height={Math.max(0, AXIS_Y - y(kmPerBin[i]))}
                rx={2.5}
                fill="var(--acc)"
                opacity={hov === i ? 1 : 0.72}
              />
              {kmPerBin[i] > 0 && (
                <text
                  x={x(i)}
                  y={y(kmPerBin[i]) - 6}
                  fontSize="10"
                  textAnchor="middle"
                  fill="var(--muted-foreground)"
                >
                  {kmPerBin[i].toFixed(1)}
                </text>
              )}
              <text
                x={x(i)}
                y={AXIS_Y + 16}
                fontSize="10.5"
                textAnchor="middle"
                fill="var(--muted-foreground)"
              >
                {bin.label}
              </text>
            </g>
          ))}
        </svg>
        <HoverStrip count={n} onEnter={setHover} onLeave={() => setHover(null)} />
      </div>
    </AnalysisCard>
  );
}

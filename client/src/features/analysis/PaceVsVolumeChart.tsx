import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDayMonth, formatMinSec } from '@/lib/activityFormat';
import { pearson, linreg } from './statsMath';
import { sliceByPeriod, type AnalysisPeriod } from './period';
import type { WeekMetrics } from './useTrainingMetrics';
import AnalysisCard from './AnalysisCard';
import ChartGrid from './ChartGrid';
import HoverStrip from './HoverStrip';

const VB_W = 520;
const VB_H = 230;
const TOP_Y = 30;
const AXIS_Y = 190;
const PLOT_H = AXIS_Y - TOP_Y;
const PAD_X = 24;
const PLOT_W = VB_W - PAD_X * 2;

export default function PaceVsVolumeChart({ weeks }: { weeks: WeekMetrics[] }) {
  const { t } = useTranslation('analysis');
  const [period, setPeriod] = useState<AnalysisPeriod>('12');
  const [hover, setHover] = useState<number | null>(null);

  const visible = sliceByPeriod(weeks, period).filter(
    (w): w is WeekMetrics & { pace: number } => w.pace !== null,
  );
  const n = visible.length;

  const kms = visible.map((w) => w.km);
  const paces = visible.map((w) => w.pace);
  const minKm = n ? Math.min(...kms) : 0;
  const maxKm = n ? Math.max(...kms, minKm + 1) : 1;
  const minPace = n ? Math.min(...paces) : 0;
  const maxPace = n ? Math.max(...paces, minPace + 10) : 1;

  const x = (km: number) => PAD_X + ((km - minKm) / (maxKm - minKm || 1)) * PLOT_W;
  // inverted: faster (lower) pace maps to the top of the plot
  const y = (pace: number) =>
    TOP_Y + ((pace - minPace) / (maxPace - minPace || 1)) * PLOT_H;

  const { m, b } = linreg(kms, paces);
  const regY1 = y(m * minKm + b);
  const regY2 = y(m * maxKm + b);

  const r = pearson(kms, paces);
  const verdict =
    n < 2 ? 'notEnough' : r > 0.25 ? 'slower' : r < -0.25 ? 'faster' : 'noTradeoff';
  const insight = t(`paceVsVolume.insight.${verdict}`);

  const hov = hover !== null && visible[hover] ? hover : null;
  const hoverReading =
    hov !== null
      ? t('paceVsVolume.hoverReading', {
          date: formatDayMonth(visible[hov].start),
          km: visible[hov].km.toFixed(1),
          pace: formatMinSec(visible[hov].pace),
        })
      : null;

  return (
    <AnalysisCard
      title={t('paceVsVolume.title')}
      period={period}
      onPeriodChange={setPeriod}
      insight={insight}
      hoverReading={hoverReading}
    >
      <div className="relative mt-[10px]">
        <svg viewBox={`0 0 ${VB_W} ${VB_H}`} className="block w-full">
          <ChartGrid width={VB_W} top={TOP_Y} bottom={AXIS_Y} />

          <text x={4} y={TOP_Y + 4} fontSize="10" fill="var(--muted-foreground)">
            {n ? formatMinSec(minPace) : ''}
          </text>
          <text x={4} y={AXIS_Y} fontSize="10" fill="var(--muted-foreground)">
            {n ? formatMinSec(maxPace) : ''}
          </text>
          <text
            x={VB_W - 4}
            y={16}
            fontSize="9.5"
            textAnchor="end"
            fill="var(--muted-foreground)"
          >
            {t('paceVsVolume.axisAgeLegend')}
          </text>
          <text
            x={VB_W / 2}
            y={VB_H - 4}
            fontSize="10"
            textAnchor="middle"
            fill="var(--muted-foreground)"
          >
            {t('paceVsVolume.axisLabel')}
          </text>

          {n >= 2 && (
            <line
              className="chart-fade"
              x1={x(minKm)}
              y1={regY1}
              x2={x(maxKm)}
              y2={regY2}
              stroke="var(--neg)"
              strokeOpacity={0.55}
              strokeWidth={1.5}
              strokeDasharray="4 3"
            />
          )}

          {visible.map((w, i) => {
            const t = n > 1 ? i / (n - 1) : 1;
            const isHover = hov === i;
            return (
              <circle
                className="chart-fade"
                key={w.start.getTime()}
                cx={x(w.km)}
                cy={y(w.pace)}
                r={isHover ? 7 : 5.5}
                style={{
                  fill: `color-mix(in oklab, var(--acc) ${(t * 100).toFixed(0)}%, var(--dot-easy))`,
                }}
                stroke="var(--card)"
                strokeWidth={1.5}
              />
            );
          })}
        </svg>
        <HoverStrip count={n} onEnter={setHover} onLeave={() => setHover(null)} />
      </div>
    </AnalysisCard>
  );
}

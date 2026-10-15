import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDayMonth } from '@/lib/activityFormat';
import { smoothPath } from '@/lib/chartPath';
import { mean } from './statsMath';
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

export default function TrainingLoadChart({ weeks }: { weeks: WeekMetrics[] }) {
  const { t } = useTranslation('analysis');
  const [period, setPeriod] = useState<AnalysisPeriod>('12');
  const [hover, setHover] = useState<number | null>(null);

  const visible = sliceByPeriod(weeks, period);
  const n = visible.length;
  const maxLoad = Math.max(1e-9, ...visible.map((w) => w.load));
  const noHrData = visible.reduce((s, w) => s + w.hrKm, 0) === 0;

  const x = (i: number) => ((i + 0.5) / n) * VB_W;
  const y = (v: number) => AXIS_Y - (v / maxLoad) * PLOT_H;

  const pts: [number, number][] = visible.map((w, i) => [x(i), y(w.load)]);
  const linePath = n >= 2 ? smoothPath(pts) : '';
  const areaPath =
    n >= 2
      ? `${linePath} L ${pts[n - 1][0].toFixed(1)} ${AXIS_Y} L ${pts[0][0].toFixed(1)} ${AXIS_Y} Z`
      : '';

  const avg = mean(visible.map((w) => w.load));
  const lastWeek = visible.at(-1)?.load ?? 0;
  const pct = avg > 0 ? ((lastWeek - avg) / avg) * 100 : 0;
  const insight =
    t('trainingLoad.insight', {
      avg: avg.toFixed(1),
      sign: pct >= 0 ? '+' : '',
      pct: pct.toFixed(0),
    }) + (noHrData ? t('trainingLoad.insightNoHr') : '');

  const hov = hover !== null && visible[hover] ? hover : null;
  const hoverReading =
    hov !== null
      ? t('trainingLoad.hoverReading', {
          date: formatDayMonth(visible[hov].start),
          load: Math.round(visible[hov].load),
          runs: t('trainingLoad.runsCount', { count: visible[hov].count }),
        })
      : null;

  return (
    <AnalysisCard
      title={t('trainingLoad.title')}
      period={period}
      onPeriodChange={setPeriod}
      insight={insight}
      hoverReading={hoverReading}
    >
      <div className="relative mt-[10px]">
        <svg viewBox={`0 0 ${VB_W} ${VB_H}`} className="block w-full">
          <defs>
            <linearGradient id="load-grad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="var(--acc)" stopOpacity="0.11" />
              <stop offset="1" stopColor="var(--acc)" stopOpacity="0" />
            </linearGradient>
          </defs>
          <ChartGrid width={VB_W} top={TOP_Y} bottom={AXIS_Y} />
          {areaPath && <path className="chart-fade" d={areaPath} fill="url(#load-grad)" />}
          {linePath && (
            <path
              className="chart-line"
              pathLength={1}
              d={linePath}
              fill="none"
              stroke="var(--acc)"
              strokeWidth={2.2}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          )}
          {visible.map((w, i) => (
            <circle
              className="chart-fade"
              key={w.start.getTime()}
              cx={x(i)}
              cy={y(w.load)}
              r={hov === i ? 4 : 2.5}
              fill="var(--acc)"
              stroke="var(--card)"
              strokeWidth={1.5}
            />
          ))}
        </svg>
        <HoverStrip count={n} onEnter={setHover} onLeave={() => setHover(null)} />
      </div>
      <AxisLabels dates={visible.map((w) => w.start)} />
    </AnalysisCard>
  );
}

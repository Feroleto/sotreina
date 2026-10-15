import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDayMonth } from '@/lib/activityFormat';
import { smoothPath } from '@/lib/chartPath';
import { mean } from './statsMath';
import { type AnalysisPeriod } from './period';
import type { DecouplingPoint } from './useDecoupling';
import AnalysisCard from './AnalysisCard';
import ChartGrid from './ChartGrid';
import HoverStrip from './HoverStrip';
import AxisLabels from './AxisLabels';

const VB_W = 900;
const VB_H = 170;
const TOP_Y = 20;
const AXIS_Y = 146;
const PLOT_H = AXIS_Y - TOP_Y;
const GOOD_MAX = 5;
const HIGH_MIN = 10;

// points are per-activity (not per-week), so the usual sliceByPeriod (last N
// items) doesn't map cleanly — filter by an actual date cutoff instead, same
// weeks-back semantics as the other cards' period selector
function cutoffDate(period: AnalysisPeriod): Date | null {
  if (period === 'all') return null;
  const d = new Date();
  d.setDate(d.getDate() - Number(period) * 7);
  return d;
}

export default function DecouplingTrendChart({
  points,
}: {
  points: DecouplingPoint[];
}) {
  const { t } = useTranslation('analysis');
  const [period, setPeriod] = useState<AnalysisPeriod>('12');
  const [hover, setHover] = useState<number | null>(null);

  const from = cutoffDate(period);
  const visible = from ? points.filter((p) => p.date >= from) : points;
  const n = visible.length;
  const values = visible.map((p) => p.decouplingPct);

  const yMax = Math.max(HIGH_MIN * 1.2, ...values) * 1.15;
  const yMin = Math.min(0, ...values) * 1.15;
  const range = yMax - yMin || 1;

  const x = (i: number) => ((i + 0.5) / Math.max(n, 1)) * VB_W;
  const y = (v: number) => AXIS_Y - ((v - yMin) / range) * PLOT_H;

  const linePath = n >= 2 ? smoothPath(visible.map((p, i) => [x(i), y(p.decouplingPct)])) : '';

  const avg = mean(values);
  const highCount = values.filter((v) => v > HIGH_MIN).length;
  const insight =
    n === 0
      ? t('cardiacDrift.insightEmpty')
      : t('cardiacDrift.insight', {
          avg: avg.toFixed(1),
          runs: t('cardiacDrift.runsCount', { count: n }),
        }) +
        (highCount > 0
          ? t('cardiacDrift.insightHighSuffix', { count: highCount })
          : '');

  const hov = hover !== null && visible[hover] !== undefined ? hover : null;
  const hoverReading =
    hov !== null
      ? t('cardiacDrift.hoverReading', {
          date: formatDayMonth(visible[hov].date),
          value: visible[hov].decouplingPct.toFixed(1),
        })
      : null;

  return (
    <AnalysisCard
      title={t('cardiacDrift.title')}
      period={period}
      onPeriodChange={setPeriod}
      insight={insight}
      hoverReading={hoverReading}
      fullWidth
    >
      {n === 0 ? (
        <p className="mt-4 py-8 text-center text-[12.5px] text-muted-foreground">
          {t('cardiacDrift.emptyState')}
        </p>
      ) : (
        <>
          <div className="relative mt-[10px]">
            <svg viewBox={`0 0 ${VB_W} ${VB_H}`} className="block w-full">
              <rect
                x={0}
                y={y(GOOD_MAX)}
                width={VB_W}
                height={Math.max(0, AXIS_Y - y(GOOD_MAX))}
                fill="var(--pos-bg)"
              />
              <ChartGrid width={VB_W} top={TOP_Y} bottom={AXIS_Y} />
              <text x={6} y={y(GOOD_MAX) - 4} fontSize="10" fill="var(--pos)">
                {t('cardiacDrift.goodLine', { max: GOOD_MAX })}
              </text>
              <line
                x1={0}
                y1={y(HIGH_MIN)}
                x2={VB_W}
                y2={y(HIGH_MIN)}
                stroke="var(--neg)"
                strokeOpacity={0.5}
                strokeDasharray="2 3"
              />
              <text x={VB_W - 4} y={y(HIGH_MIN) - 4} fontSize="10" textAnchor="end" fill="var(--neg)">
                {t('cardiacDrift.highLine', { min: HIGH_MIN })}
              </text>

              {linePath && (
                <path
                  className="chart-line"
                  pathLength={1}
                  d={linePath}
                  fill="none"
                  stroke="var(--acc)"
                  strokeWidth={2}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              )}
              {visible.map((p, i) => (
                <circle
                  className="chart-fade"
                  key={p.activityId}
                  cx={x(i)}
                  cy={y(p.decouplingPct)}
                  r={hov === i ? 4 : 2.5}
                  fill={p.decouplingPct > HIGH_MIN ? 'var(--neg)' : 'var(--acc)'}
                  stroke="var(--card)"
                  strokeWidth={1.5}
                />
              ))}
            </svg>
            <HoverStrip count={n} onEnter={setHover} onLeave={() => setHover(null)} />
          </div>
          <AxisLabels dates={visible.map((p) => p.date)} width={860} />
        </>
      )}
    </AnalysisCard>
  );
}

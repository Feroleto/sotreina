import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDayMonth } from '@/lib/activityFormat';
import { smoothPath } from '@/lib/chartPath';
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
const BAND_FROM = 0.8;
const BAND_TO = 1.3;

// consecutive non-null runs of acwr; a gap (early weeks with no chronic
// baseline yet) splits the line into segments
function segments(values: (number | null)[]): number[][] {
  const segs: number[][] = [];
  let current: number[] = [];
  values.forEach((v, i) => {
    if (v === null) {
      if (current.length) segs.push(current);
      current = [];
    } else {
      current.push(i);
    }
  });
  if (current.length) segs.push(current);
  return segs;
}

type AcwrStatus = 'below' | 'safe' | 'high';

function acwrStatus(acwr: number): AcwrStatus {
  if (acwr < BAND_FROM) return 'below';
  if (acwr <= BAND_TO) return 'safe';
  return 'high';
}

export default function AcwrChart({ weeks }: { weeks: WeekMetrics[] }) {
  const { t } = useTranslation('analysis');
  const [period, setPeriod] = useState<AnalysisPeriod>('12');
  const [hover, setHover] = useState<number | null>(null);

  const visible = sliceByPeriod(weeks, period);
  const n = visible.length;
  const values = visible.map((w) => w.acwr);
  const finite = values.filter((v): v is number => v !== null);
  const yMax = Math.max(1e-9, ...finite, BAND_TO) * 1.15;

  const x = (i: number) => ((i + 0.5) / n) * VB_W;
  const y = (v: number) => AXIS_Y - (v / yMax) * PLOT_H;

  const segs = segments(values);
  const paths = segs
    .filter((seg) => seg.length >= 2)
    .map((seg) => smoothPath(seg.map((i) => [x(i), y(values[i] as number)])));
  const lonePoints = segs.filter((seg) => seg.length === 1).map(([i]) => i);

  const cur = visible.at(-1)?.acwr ?? null;
  const insight =
    cur === null
      ? t('acwr.insightNoData')
      : t('acwr.insightCurrent', {
          value: cur.toFixed(2),
          status: t(`acwr.status.${acwrStatus(cur)}`),
        });

  const hov = hover !== null && visible[hover] ? hover : null;
  const hoverReading =
    hov !== null
      ? t('acwr.hoverReading', {
          date: formatDayMonth(visible[hov].start),
          value: values[hov] !== null ? (values[hov] as number).toFixed(2) : '—',
        })
      : null;

  return (
    <AnalysisCard
      title={t('acwr.title')}
      period={period}
      onPeriodChange={setPeriod}
      insight={insight}
      hoverReading={hoverReading}
    >
      <div className="relative mt-[10px]">
        <svg viewBox={`0 0 ${VB_W} ${VB_H}`} className="block w-full">
          <rect
            x={0}
            y={y(BAND_TO)}
            width={VB_W}
            height={Math.max(0, y(BAND_FROM) - y(BAND_TO))}
            fill="var(--pos-bg)"
          />
          <ChartGrid width={VB_W} top={TOP_Y} bottom={AXIS_Y} />
          <text x={6} y={y(BAND_TO) + 12} fontSize="10" fill="var(--pos)">
            {t('acwr.bandLabel')}
          </text>
          <line
            x1={0}
            y1={y(1.0)}
            x2={VB_W}
            y2={y(1.0)}
            stroke="var(--grid-ax)"
            strokeDasharray="2 3"
          />
          {paths.map((d, k) => (
            <path
              className="chart-line"
              pathLength={1}
              key={k}
              d={d}
              fill="none"
              stroke="var(--acc)"
              strokeWidth={2}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          ))}
          {visible.map(
            (w, i) =>
              values[i] !== null && (
                <circle
                  className="chart-fade"
                  key={w.start.getTime()}
                  cx={x(i)}
                  cy={y(values[i] as number)}
                  r={hov === i ? 4 : lonePoints.includes(i) ? 3 : 2.5}
                  fill="var(--acc)"
                  stroke="var(--card)"
                  strokeWidth={1.5}
                />
              ),
          )}
        </svg>
        <HoverStrip count={n} onEnter={setHover} onLeave={() => setHover(null)} />
      </div>
      <AxisLabels dates={visible.map((w) => w.start)} />
    </AnalysisCard>
  );
}

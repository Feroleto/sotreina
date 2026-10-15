import { useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import {
  formatDayMonth,
  formatKm,
  formatMonthLong,
  formatMonthShort,
} from '@/lib/activityFormat';
import SegmentedControl from '@/components/SegmentedControl';
import { smoothPath } from '@/lib/chartPath';

export interface BinAgg {
  start: Date;
  km: number;
  sec: number;
  count: number;
}

export type Granularity = 'week' | 'month';

export type Period = '4' | '8' | '12' | 'all';

// second tuple element is a dashboard.json key, translated at render time
const PERIOD_KEYS: [Period, string][] = [
  ['4', 'chart.periods.4'],
  ['8', 'chart.periods.8'],
  ['12', 'chart.periods.12'],
  ['all', 'chart.periods.all'],
];

const VB_W = 720;
const VB_H = 210;
const AXIS_Y = 196;
const PLOT_H = 170;

function formatWeekRange(start: Date): string {
  const end = new Date(
    start.getFullYear(),
    start.getMonth(),
    start.getDate() + 6,
  );
  return `${formatDayMonth(start)} – ${formatDayMonth(end)}`;
}

interface WeeklyChartProps {
  bins: BinAgg[];
  granularity: Granularity;
  totalKm: number;
  period: Period;
  onPeriodChange: (p: Period) => void;
  /** presente apenas quando os bins são clicáveis (modo mensal do "Tudo") */
  onSelect?: (startMs: number) => void;
  /** controles extras no header, depois do segmented (ex.: date range picker) */
  children?: ReactNode;
}

export default function WeeklyChart({
  bins,
  granularity,
  totalKm,
  period,
  onPeriodChange,
  onSelect,
  children,
}: WeeklyChartProps) {
  const { t } = useTranslation('dashboard');
  const [hover, setHover] = useState<number | null>(null);
  const periods: [Period, string][] = PERIOD_KEYS.map(([k, key]) => [
    k,
    t(key),
  ]);

  const monthly = granularity === 'month';
  const n = bins.length;
  const maxKm = Math.max(1, ...bins.map((b) => b.km));
  const pts: [number, number][] = bins.map((b, i) => [
    ((i + 0.5) / n) * VB_W,
    AXIS_Y - (b.km / maxKm) * PLOT_H,
  ]);
  const linePath = smoothPath(pts);
  const areaPath =
    n >= 2
      ? `${linePath} L ${pts[n - 1][0].toFixed(1)} ${AXIS_Y} L ${pts[0][0].toFixed(1)} ${AXIS_Y} Z`
      : '';
  const labelEvery = monthly ? 1 : Math.max(1, Math.ceil(n / 8));

  const hov = hover !== null && bins[hover] ? hover : null;
  const hoverReading =
    hov !== null
      ? monthly
        ? `${formatMonthLong(bins[hov].start)} · ${formatKm(bins[hov].km)} km · ${t('list.runsCount', { count: bins[hov].count })}`
        : `${formatWeekRange(bins[hov].start)} · ${formatKm(bins[hov].km)} km`
      : null;
  const totalReading = t('chart.kmInPeriod', { km: formatKm(totalKm) });

  return (
    <div className="mb-9 rounded-[var(--rad)] border border-border bg-card px-7 pt-6 pb-4 transition-[background] duration-[250ms]">
      <div className="mb-1.5 flex items-center justify-between">
        <div className="text-sm font-semibold text-foreground">
          {monthly ? t('chart.monthlyDistance') : t('chart.weeklyDistance')}
        </div>
        <div className="flex items-center gap-3.5">
          <div className="text-[12.5px] text-muted-foreground">
            {totalReading}
          </div>
          <SegmentedControl
            size="compact"
            items={periods}
            active={period}
            onPick={onPeriodChange}
          />
          {children}
        </div>
      </div>

      <div className="relative">
        <svg viewBox={`0 0 ${VB_W} ${VB_H}`} className="block w-full">
          <defs>
            <linearGradient id="weekly-grad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="var(--acc)" stopOpacity="0.22" />
              <stop offset="1" stopColor="var(--acc)" stopOpacity="0" />
            </linearGradient>
          </defs>
          <line x1="0" y1="26" x2={VB_W} y2="26" stroke="var(--border)" />
          <line x1="0" y1="111" x2={VB_W} y2="111" stroke="var(--border)" />
          <line
            x1="0"
            y1={AXIS_Y}
            x2={VB_W}
            y2={AXIS_Y}
            stroke="var(--grid-ax)"
          />
          <text x="4" y="21" fontSize="10.5" fill="var(--muted-foreground)">
            {Math.round(maxKm)} km
          </text>
          <text x="4" y="106" fontSize="10.5" fill="var(--muted-foreground)">
            {Math.round(maxKm / 2)} km
          </text>
          {areaPath && (
            <path className="chart-fade" d={areaPath} fill="url(#weekly-grad)" />
          )}
          {linePath && (
            <path
              className="chart-line"
              pathLength={1}
              d={linePath}
              fill="none"
              stroke="var(--acc)"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          )}
        </svg>

        {hov !== null && (
          <>
            <div
              className="pointer-events-none absolute top-2 bottom-[7%] w-0 border-l border-dashed border-grid-ax"
              style={{ left: `${(((hov + 0.5) / n) * 100).toFixed(2)}%` }}
            />
            <div
              className="pointer-events-none absolute h-[9px] w-[9px] rounded-full border-2 border-card bg-acc"
              style={{
                left: `${(((hov + 0.5) / n) * 100).toFixed(2)}%`,
                top: `${((pts[hov][1] / VB_H) * 100).toFixed(2)}%`,
                margin: '-4.5px 0 0 -4.5px',
              }}
            />
            <div
              className="pointer-events-none absolute z-10 -translate-x-1/2 -translate-y-[calc(100%+10px)] rounded-md border border-border bg-card px-2.5 py-1.5 text-[11.5px] whitespace-nowrap text-foreground shadow-md"
              style={{
                left: `clamp(56px, ${(((hov + 0.5) / n) * 100).toFixed(2)}%, calc(100% - 56px))`,
                top: `${((pts[hov][1] / VB_H) * 100).toFixed(2)}%`,
              }}
            >
              {hoverReading}
            </div>
          </>
        )}

        <div className="absolute inset-0 flex">
          {bins.map((b, i) => (
            <div
              key={b.start.getTime()}
              className={`flex-1${onSelect ? ' cursor-pointer' : ''}`}
              onMouseEnter={() => setHover(i)}
              onMouseLeave={() => setHover(null)}
              onClick={onSelect ? () => onSelect(b.start.getTime()) : undefined}
            />
          ))}
        </div>
      </div>

      <div className="mt-1 flex pb-1.5">
        {bins.map((b, i) => (
          <div
            key={b.start.getTime()}
            className="flex-1 text-center text-[11px] text-muted-foreground"
          >
            {i % labelEvery === 0
              ? monthly
                ? formatMonthShort(b.start)
                : formatDayMonth(b.start)
              : ''}
          </div>
        ))}
      </div>
    </div>
  );
}

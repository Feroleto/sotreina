import type { CSSProperties } from 'react';
import { useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import {
  formatDayMonth,
  formatDuration,
  formatKm,
  formatPace,
} from '@/lib/activityFormat';
import type { BinAgg } from './WeeklyChart';
import { endOfWeek } from './bins';

function KpiCard({
  label,
  value,
  sub,
}: {
  label: string;
  value: string;
  sub: string;
}) {
  return (
    <div className="w-[150px] flex-none rounded-[14px] border border-border bg-card px-[15px] py-3.5">
      <div className="text-[10.5px] font-semibold tracking-[.07em] text-muted-foreground uppercase">
        {label}
      </div>
      <div className="mt-1 text-[20px] font-bold tracking-[-.02em] text-foreground">
        {value}
      </div>
      <div className="mt-[2px] text-[11px] text-muted-foreground">{sub}</div>
    </div>
  );
}

interface MobileWeeklySummaryProps {
  /** the last 12 weeks, ascending, zero-filled — or the custom range when one is set */
  weeks: BinAgg[];
  /** header slot in the bars card, top-right (the custom date range trigger) */
  children?: ReactNode;
}

/** mobile replacement for the area chart: KPI carousel + compact week bars */
export default function MobileWeeklySummary({
  weeks,
  children,
}: MobileWeeklySummaryProps) {
  const { t } = useTranslation('dashboard');
  // tap toggles the selected bar and its reading line
  const [selected, setSelected] = useState<number | null>(null);

  const km = weeks.reduce((s, w) => s + w.km, 0);
  const sec = weeks.reduce((s, w) => s + w.sec, 0);
  const count = weeks.reduce((s, w) => s + w.count, 0);
  const maxKm = Math.max(1, ...weeks.map((w) => w.km));
  const n = weeks.length;

  const sel = selected !== null && weeks[selected] ? selected : null;
  const reading =
    sel !== null
      ? t('chart.barReading', {
          range: `${formatDayMonth(weeks[sel].start)} – ${formatDayMonth(endOfWeek(weeks[sel].start))}`,
          km: formatKm(weeks[sel].km),
        })
      : t('chart.barHint', { km: formatKm(km), count: n });

  return (
    <div className="md:hidden">
      {/* KPI carousel — edge-bleed horizontal scroll */}
      <div className="no-scrollbar -mx-5 flex gap-3 overflow-x-auto px-5">
        <KpiCard
          label={t('kpis.distance')}
          value={`${formatKm(km)} km`}
          sub={t('kpis.weeksCount', { count: n })}
        />
        <KpiCard
          label={t('kpis.avgPace')}
          value={formatPace(km > 0 ? sec / km : null)}
          sub={t('kpis.weeksCount', { count: n })}
        />
        <KpiCard
          label={t('kpis.activities')}
          value={String(count)}
          sub={t('kpis.perWeek', {
            value: (count / Math.max(1, n)).toFixed(1),
          })}
        />
        <KpiCard
          label={t('kpis.time')}
          value={formatDuration(sec)}
          sub={t('kpis.moving')}
        />
      </div>

      {/* compact week bars */}
      <div className="mt-3 mb-5 rounded-[14px] border border-border bg-card p-4">
        <div className="flex items-start justify-between gap-2">
          <div
            className={`min-w-0 flex-1 text-[12.5px] ${
              sel !== null ? 'text-foreground' : 'text-muted-foreground'
            }`}
          >
            {reading}
          </div>
          <div className="flex-none">{children}</div>
        </div>
        <div className="mt-3 flex h-[120px] items-end gap-1">
          {weeks.map((w, i) => (
            <button
              key={w.start.getTime()}
              onClick={() => setSelected((cur) => (cur === i ? null : i))}
              aria-label={`${formatDayMonth(w.start)} · ${formatKm(w.km)} km`}
              className="flex h-full flex-1 cursor-pointer items-end"
            >
              <span
                className="chart-bar w-full rounded-t-[4px]"
                style={
                  {
                    '--i': i,
                    height: `${((w.km / maxKm) * 100).toFixed(1)}%`,
                    background:
                      sel === i
                        ? 'color-mix(in oklab, var(--acc) 70%, white)'
                        : 'var(--acc)',
                  } as CSSProperties
                }
              />
            </button>
          ))}
        </div>
        <div className="mt-0 flex gap-1 border-t border-border pt-1">
          {weeks.map((w, i) => (
            <div
              key={w.start.getTime()}
              className="flex-1 text-center text-[9.5px] text-muted-foreground"
            >
              {i % 3 === 0 ? formatDayMonth(w.start) : ''}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

import type { CSSProperties } from 'react';
import { useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import {
  formatDayMonth,
  formatDurationShort,
  formatKm,
  formatMonthShort,
  formatPace,
} from '@/lib/activityFormat';
import type { BinAgg } from './WeeklyChart';
import { endOfWeek } from './bins';

interface MobileWeeklySummaryProps {
  /** the current (partial) week — the hero number */
  thisWeek: BinAgg;
  /** the week before it, the hero's point of comparison */
  lastWeek: BinAgg;
  /** the last 12 weeks, ascending, zero-filled — or the custom range when one is set */
  weeks: BinAgg[];
  /** volume header slot, top-right (the custom date range trigger) */
  children?: ReactNode;
}

function Stat({
  label,
  value,
  first,
}: {
  label: string;
  value: string;
  first?: boolean;
}) {
  return (
    <div className={first ? 'py-3.5' : 'border-l border-border py-3.5 pl-3.5'}>
      <div className="text-[12px] text-muted-foreground">{label}</div>
      <div className="mt-1 font-mono text-[20px] font-medium text-foreground">
        {value}
      </div>
    </div>
  );
}

/**
 * mobile replacement for the rail + area chart — Redesign Corrida 17b
 * "Monolito": no cards, hairlines, numbers in Geist Mono, accent only on
 * progress, the current week's bar and the active state
 */
export default function MobileWeeklySummary({
  thisWeek,
  lastWeek,
  weeks,
  children,
}: MobileWeeklySummaryProps) {
  const { t } = useTranslation('dashboard');
  // tap toggles the selected bar and its reading line
  const [selected, setSelected] = useState<number | null>(null);

  const maxKm = Math.max(1, ...weeks.map((w) => w.km));
  const totalKm = weeks.reduce((s, w) => s + w.km, 0);
  const sel = selected !== null && weeks[selected] ? selected : null;
  const reading =
    sel !== null
      ? t('chart.barReading', {
          range: `${formatDayMonth(weeks[sel].start)} – ${formatDayMonth(endOfWeek(weeks[sel].start))}`,
          km: formatKm(weeks[sel].km),
        })
      : t('chart.barHint', { km: formatKm(totalKm), count: weeks.length });

  // progress against last week — no target exists in the data, so the
  // previous week is the bar the current one is measured against
  const pct =
    lastWeek.km > 0 ? Math.round((thisWeek.km / lastWeek.km) * 100) : null;

  return (
    <div className="md:hidden">
      <div className="mt-3 text-[13px] text-muted-foreground">
        {t('hero.thisWeek', {
          range: `${formatDayMonth(thisWeek.start)} – ${formatDayMonth(endOfWeek(thisWeek.start))}`,
        })}
      </div>

      <div className="mt-[22px] flex items-baseline gap-2">
        <span className="font-mono text-[64px] leading-none font-medium tracking-[-.05em] text-foreground">
          {formatKm(thisWeek.km)}
        </span>
        <span className="text-[17px] text-muted-foreground">km</span>
      </div>

      <div className="mt-3 flex justify-between text-[12.5px] text-muted-foreground">
        <span>
          {lastWeek.km > 0
            ? t('hero.lastWeek', { km: formatKm(lastWeek.km) })
            : t('hero.noLastWeek')}
        </span>
        {pct !== null && (
          <span className="font-medium text-foreground">{pct}%</span>
        )}
      </div>
      {pct !== null && (
        <div className="mt-[7px] h-[3px] rounded-[2px] bg-border">
          {/* revealed by clip-path (same as MacroBar), not width */}
          <div
            className="macro-fill h-full bg-acc"
            style={{
              clipPath: `inset(0 ${100 - Math.min(100, pct)}% 0 0 round 2px)`,
            }}
          />
        </div>
      )}

      <div className="mt-[22px] grid grid-cols-3 border-y border-border">
        <Stat
          first
          label={t('kpis.activities')}
          value={String(thisWeek.count)}
        />
        <Stat
          label={t('kpis.avgPace')}
          // the label already says pace; the unit would crowd the column
          value={formatPace(
            thisWeek.km > 0 ? thisWeek.sec / thisWeek.km : null,
          ).replace(' /km', '')}
        />
        <Stat
          label={t('kpis.time')}
          value={formatDurationShort(thisWeek.sec)}
        />
      </div>

      <div className="mt-6 flex items-center justify-between gap-2">
        <div className="text-[14px] font-semibold text-foreground">
          {t('chart.weeklyVolume')}
        </div>
        <div className="flex-none">{children}</div>
      </div>
      <div
        className={`mt-1 text-[12px] ${
          sel !== null ? 'text-foreground' : 'text-muted-foreground'
        }`}
      >
        {reading}
      </div>

      <div className="mt-3.5 flex h-[110px] items-end gap-[7px]">
        {weeks.map((w, i) => {
          const isLast = i === weeks.length - 1;
          return (
            <button
              key={w.start.getTime()}
              onClick={() => setSelected((cur) => (cur === i ? null : i))}
              aria-label={`${formatDayMonth(w.start)} · ${formatKm(w.km)} km`}
              aria-pressed={sel === i}
              className="flex h-full flex-1 cursor-pointer items-end"
            >
              <span
                className="chart-bar w-full rounded-[3px]"
                style={
                  {
                    '--i': i,
                    // a zero week still shows a sliver, so the grid of
                    // weeks reads as continuous
                    height: `${Math.max(2, (w.km / maxKm) * 100).toFixed(1)}%`,
                    background:
                      sel === i
                        ? 'var(--foreground)'
                        : isLast
                          ? 'var(--acc)'
                          : 'var(--bar)',
                  } as CSSProperties
                }
              />
            </button>
          );
        })}
      </div>
      {/* month label under the first bar of each month */}
      <div className="mt-2 flex gap-[7px]">
        {weeks.map((w, i) => {
          const newMonth =
            i === 0 || w.start.getMonth() !== weeks[i - 1].start.getMonth();
          return (
            <div
              key={w.start.getTime()}
              className="min-w-0 flex-1 overflow-visible font-mono text-[10.5px] whitespace-nowrap text-muted-foreground"
            >
              {newMonth ? formatMonthShort(w.start) : ''}
            </div>
          );
        })}
      </div>

      <div className="mt-6 mb-1.5 text-[14px] font-semibold text-foreground">
        {t('hero.recent')}
      </div>
    </div>
  );
}

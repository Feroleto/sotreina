import type { CSSProperties } from 'react';
import { useTranslation } from 'react-i18next';
import { Check, Pencil } from 'lucide-react';
import type { PageId } from '@/features/nav/navConfig';
import type { DayValue } from './todayStatus';

export interface SingleAreaRow {
  key: string;
  name: string;
  detail: string;
  value: string;
  page: PageId;
}

export interface TodaySingleAreaProps {
  /** the day's status line: check + title + sub, value on the right */
  status: { done: boolean; title: string; sub: string; value?: string };
  /** the big number against its goal ("Esta semana · 32,4 km") */
  period: {
    label: string;
    value: string;
    unit: string;
    pct: number;
    over: boolean;
    goal: string;
    remaining: string;
  };
  days: DayValue[];
  daysLegend: string;
  dayInitial: (date: string) => string;
  recent: SingleAreaRow[];
  /** where the status line leads (the area's landing page) */
  areaPage: PageId;
  /** opens the weekly goals; absent for Dieta (edited from Perfil) */
  onEditGoal?: () => void;
  onNavigate: (page: PageId) => void;
}

/**
 * "Hoje" when the user keeps a single area (Redesign 21c): the page becomes
 * that area's summary — today's status, the period against its goal, one bar
 * per day and the area's recent entries. Purely presentational: TodayPage
 * derives every string and number
 */
export default function TodaySingleArea({
  status,
  period,
  days,
  daysLegend,
  dayInitial,
  recent,
  areaPage,
  onEditGoal,
  onNavigate,
}: TodaySingleAreaProps) {
  const { t } = useTranslation('today');
  const max = Math.max(...days.map((d) => d.value), 0);

  return (
    <>
      <button
        type="button"
        onClick={() => onNavigate(areaPage)}
        className="mt-[22px] flex w-full cursor-pointer items-center gap-3 border-y border-border py-4 text-left"
      >
        {status.done ? (
          <span className="flex h-[22px] w-[22px] flex-none items-center justify-center rounded-full bg-acc text-acc-fg">
            <Check className="h-3 w-3" strokeWidth={3} aria-hidden="true" />
          </span>
        ) : (
          <span className="block h-[22px] w-[22px] flex-none rounded-full border-[1.5px] border-muted-foreground" />
        )}
        <div className="min-w-0 flex-1">
          <div className="truncate text-[14.5px] font-medium text-foreground">
            {status.title}
          </div>
          {status.sub && (
            <div className="mt-0.5 truncate text-[12px] text-muted-foreground">
              {status.sub}
            </div>
          )}
        </div>
        {status.value && (
          <div className="flex-none font-mono text-[14.5px] font-medium text-foreground">
            {status.value}
          </div>
        )}
      </button>

      <div className="mt-[26px] flex items-center justify-between">
        <div className="text-[13px] text-muted-foreground">{period.label}</div>
        {onEditGoal && (
          <button
            type="button"
            onClick={onEditGoal}
            aria-label={t('areas.editGoals')}
            title={t('areas.editGoals')}
            className="-my-3 -mr-2 flex h-11 w-11 cursor-pointer items-center justify-center text-muted-foreground hover:text-foreground"
          >
            <Pencil className="h-4 w-4" strokeWidth={1.8} />
          </button>
        )}
      </div>
      <div className="enter-rise mt-2 flex items-baseline gap-2">
        <span className="font-mono text-[64px] leading-none font-medium tracking-[-.05em] text-foreground">
          {period.value}
        </span>
        <span className="text-[17px] text-muted-foreground">{period.unit}</span>
      </div>
      <div className="mt-4 h-1 rounded-[2px] bg-border">
        <div
          className={`macro-fill h-full ${period.over ? 'bg-neg' : 'bg-acc'}`}
          style={{ clipPath: `inset(0 ${100 - period.pct}% 0 0 round 2px)` }}
        />
      </div>
      <div className="mt-2 flex justify-between gap-3 text-[12px] text-muted-foreground">
        <span>{period.goal}</span>
        <span className={period.over ? 'text-neg' : undefined}>
          {period.remaining}
        </span>
      </div>

      <div className="mt-[26px] flex items-baseline justify-between">
        <div className="text-[14px] font-semibold text-foreground">
          {t('days.title')}
        </div>
        <div className="text-[12px] text-muted-foreground">{daysLegend}</div>
      </div>
      <div className="mt-3.5 flex h-[84px] items-end gap-2.5">
        {days.map((d, i) => (
          <div
            key={d.date}
            role="img"
            aria-label={`${dayInitial(d.date)}: ${d.value}`}
            className="chart-bar flex h-full flex-1 flex-col justify-end"
            style={{ '--i': i } as CSSProperties}
          >
            <div
              className={`min-h-[3px] rounded-[3px] ${i === days.length - 1 ? 'bg-acc' : 'bg-bar'}`}
              style={{ height: max > 0 ? `${(d.value / max) * 100}%` : 0 }}
            />
          </div>
        ))}
      </div>
      <div className="mt-2 flex gap-2.5" aria-hidden="true">
        {days.map((d) => (
          <div
            key={d.date}
            className="flex-1 text-center font-mono text-[10.5px] text-muted-foreground"
          >
            {dayInitial(d.date)}
          </div>
        ))}
      </div>

      <div className="mt-6 text-[14px] font-semibold text-foreground">
        {t('single.recent')}
      </div>
      <div className="mt-1.5">
        {recent.map((row, i) => (
          <button
            key={row.key}
            type="button"
            onClick={() => onNavigate(row.page)}
            className="enter-rise flex w-full cursor-pointer items-center gap-3 border-b border-border py-[13px] text-left"
            style={{ '--i': i } as CSSProperties}
          >
            <div className="min-w-0 flex-1">
              <div className="truncate text-[14.5px] font-medium text-foreground">
                {row.name}
              </div>
              <div className="mt-0.5 truncate text-[12px] text-muted-foreground">
                {row.detail}
              </div>
            </div>
            <div className="flex-none font-mono text-[14.5px] font-medium text-foreground">
              {row.value}
            </div>
          </button>
        ))}
        {recent.length === 0 && (
          <p className="border-b border-border py-6 text-center text-[13px] text-muted-foreground">
            {t('single.empty')}
          </p>
        )}
      </div>
    </>
  );
}

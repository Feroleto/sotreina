import type { CSSProperties } from 'react';
import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { WorkoutHistoryItem } from '@/lib/types';
import { formatMonthDay } from '@/lib/activityFormat';
import { currentIntlLocale } from '@/lib/dateLocale';
import { useEntrance } from '@/lib/useEntrance';

interface GymCalendarProps {
  items: WorkoutHistoryItem[];
}

function midnight(d: Date): Date {
  const c = new Date(d);
  c.setHours(0, 0, 0, 0);
  return c;
}
function monthStart(d: Date): Date {
  const c = midnight(d);
  c.setDate(1);
  return c;
}
function addMonths(d: Date, k: number): Date {
  const c = new Date(d);
  c.setMonth(c.getMonth() + k);
  return c;
}
function lastDayOfMonth(m: Date): Date {
  return new Date(m.getFullYear(), m.getMonth() + 1, 0);
}
function sameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}
function dayKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}
function formatTons(kg: number): string {
  return (kg / 1000).toFixed(1);
}

// month-grid calendar for finished workouts — same shape as
// overview/RunCalendar.tsx (month nav bounded by the earliest session,
// Monday-first week, tap-to-select day reading in the footer), sized down
// per this screen's spec (34px cells / 28px day circle vs. Run's 40/32) and
// scoped to gym.json's own i18n keys instead of reaching into 'overview'
export default function GymCalendar({ items }: GymCalendarProps) {
  const { t } = useTranslation('gym');
  // training days fade in week by week, once per session; month navigation
  // afterwards is instant
  const { attach: enterRef, state: enterState } = useEntrance('gym/overview:calendar', { ready: items.length > 0 });
  const weekdays = t('overview.calendar.weekdaysMin', { returnObjects: true }) as string[];

  const earliestDate = useMemo(
    () =>
      items.length > 0
        ? new Date(
            items.reduce(
              (min, w) => (w.startedAt < min ? w.startedAt : min),
              items[0].startedAt,
            ),
          )
        : undefined,
    [items],
  );

  const [visibleMonth, setVisibleMonth] = useState<Date>(() => monthStart(new Date()));
  const [hoverDay, setHoverDay] = useState<string | null>(null);
  const [selectedDay, setSelectedDay] = useState<string | null>(null);

  const minMonth = earliestDate ? monthStart(earliestDate) : null;
  const maxMonth = monthStart(new Date());
  const canPrev = !minMonth || visibleMonth.getTime() > minMonth.getTime();
  const canNext = visibleMonth.getTime() < maxMonth.getTime();

  const byDay = useMemo(() => {
    const map = new Map<string, WorkoutHistoryItem[]>();
    for (const w of items) {
      const d = new Date(w.startedAt);
      if (
        d.getFullYear() !== visibleMonth.getFullYear() ||
        d.getMonth() !== visibleMonth.getMonth()
      ) {
        continue;
      }
      const key = dayKey(d);
      const list = map.get(key) ?? [];
      list.push(w);
      map.set(key, list);
    }
    return map;
  }, [items, visibleMonth]);

  const monthTotals = useMemo(() => {
    let count = 0;
    let volumeKg = 0;
    for (const list of byDay.values()) {
      count += list.length;
      volumeKg += list.reduce((s, w) => s + w.volumeKg, 0);
    }
    return { count, volumeKg };
  }, [byDay]);

  const today = midnight(new Date());
  const offset = (visibleMonth.getDay() + 6) % 7; // week starts on Monday
  const total = lastDayOfMonth(visibleMonth).getDate();
  const cells: (number | null)[] = [
    ...Array(offset).fill(null),
    ...Array.from({ length: total }, (_, i) => i + 1),
  ];

  const monthLabel = visibleMonth.toLocaleDateString(currentIntlLocale(), {
    month: 'long',
    year: 'numeric',
  });

  const activeDay = hoverDay ?? selectedDay;
  const dayList = activeDay ? byDay.get(activeDay) : undefined;
  const footer = dayList
    ? dayList.length > 1
      ? t('overview.calendar.dayMultiWorkouts', {
          count: dayList.length,
          volume: formatTons(dayList.reduce((s, w) => s + w.volumeKg, 0)),
        })
      : t('overview.calendar.daySingleWorkout', {
          date: formatMonthDay(new Date(dayList[0].startedAt)),
          name: dayList[0].templateName ?? t('start.freeWorkout'),
          volume: formatTons(dayList[0].volumeKg),
        })
    : t('overview.calendar.monthSummary', {
        count: monthTotals.count,
        volume: formatTons(monthTotals.volumeKg),
        month: visibleMonth.toLocaleDateString(currentIntlLocale(), { month: 'long' }),
      });

  return (
    <div ref={enterRef} data-enter={enterState} className="rounded-[14px] border border-border bg-card p-[16px] max-md:rounded-none max-md:border-x-0 max-md:border-b-0 max-md:bg-transparent max-md:px-0">
      <div className="flex items-center justify-between">
        <div className="text-[13.5px] font-semibold text-foreground">{monthLabel}</div>
        <div className="flex gap-1">
          <button
            type="button"
            onClick={() => {
              setSelectedDay(null);
              setVisibleMonth(addMonths(visibleMonth, -1));
            }}
            disabled={!canPrev}
            aria-label={t('overview.calendar.previousMonth')}
            className="flex h-[26px] w-[26px] cursor-pointer items-center justify-center rounded-[7px] bg-chip text-muted-foreground disabled:cursor-default disabled:opacity-30"
          >
            ‹
          </button>
          <button
            type="button"
            onClick={() => {
              setSelectedDay(null);
              setVisibleMonth(addMonths(visibleMonth, 1));
            }}
            disabled={!canNext}
            aria-label={t('overview.calendar.nextMonth')}
            className="flex h-[26px] w-[26px] cursor-pointer items-center justify-center rounded-[7px] bg-chip text-muted-foreground disabled:cursor-default disabled:opacity-30"
          >
            ›
          </button>
        </div>
      </div>

      <div className="mt-3 grid grid-cols-7">
        {weekdays.map((w, i) => (
          <div
            key={i}
            className="flex h-5 items-center justify-center text-[10px] font-semibold text-muted-foreground"
          >
            {w}
          </div>
        ))}
      </div>

      <div className="grid grid-cols-7" onMouseLeave={() => setHoverDay(null)}>
        {cells.map((day, i) => {
          if (day == null) {
            return <div key={`empty-${i}`} className="h-[34px]" />;
          }
          const date = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth(), day);
          const key = dayKey(date);
          const list = byDay.get(key);
          const hasWorkout = !!list && list.length > 0;
          const isToday = sameDay(date, today);
          const isFuture = date.getTime() > today.getTime();

          return (
            <div
              key={key}
              className="flex h-[34px] cursor-pointer items-center justify-center"
              onMouseEnter={() => hasWorkout && setHoverDay(key)}
              onClick={() => {
                if (!hasWorkout) return;
                setHoverDay(null);
                setSelectedDay((cur) => (cur === key ? null : key));
              }}
            >
              <div
                className={`flex h-[28px] w-[28px] items-center justify-center rounded-full text-[12.5px] ${
                  hasWorkout
                    ? 'enter-fade bg-acc font-semibold text-acc-fg'
                    : isToday
                      ? 'border-[1.5px] border-acc text-foreground'
                      : isFuture
                        ? 'text-muted-foreground opacity-40'
                        : 'font-normal text-foreground'
                }`}
                style={{ '--i': Math.floor(i / 7) } as CSSProperties}
              >
                {day}
              </div>
            </div>
          );
        })}
      </div>

      <div className="mt-3 border-t border-border pt-3 text-[12px] text-muted-foreground">
        {footer}
      </div>
    </div>
  );
}

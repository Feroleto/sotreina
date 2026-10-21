import type { CSSProperties } from 'react';
import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { Activity } from '@/lib/types';
import { formatKm, formatMonthDay, formatPace } from '@/lib/activityFormat';
import { currentIntlLocale } from '@/lib/dateLocale';
import { useEntrance } from '@/lib/useEntrance';

interface RunCalendarProps {
  activities: Activity[];
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

export default function RunCalendar({ activities }: RunCalendarProps) {
  const { t } = useTranslation('overview');
  // training days fade in week by week, once per session; month navigation
  // afterwards is instant
  const { attach: enterRef, state: enterState } = useEntrance(
    'run/overview:calendar',
    { ready: activities.length > 0 },
  );
  const weekdays = t('calendar.weekdaysMin', {
    returnObjects: true,
  }) as string[];
  const earliestDate = useMemo(
    () =>
      activities.length > 0
        ? new Date(
            activities.reduce(
              (min, a) => (a.startDate < min ? a.startDate : min),
              activities[0].startDate,
            ),
          )
        : undefined,
    [activities],
  );

  const [visibleMonth, setVisibleMonth] = useState<Date>(() =>
    monthStart(new Date()),
  );
  const [hoverDay, setHoverDay] = useState<string | null>(null);
  // touch: tapping an active day toggles its reading in the footer (no hover)
  const [selectedDay, setSelectedDay] = useState<string | null>(null);

  const minMonth = earliestDate ? monthStart(earliestDate) : null;
  const maxMonth = monthStart(new Date());
  const canPrev = !minMonth || visibleMonth.getTime() > minMonth.getTime();
  const canNext = visibleMonth.getTime() < maxMonth.getTime();

  const byDay = useMemo(() => {
    const map = new Map<string, Activity[]>();
    for (const a of activities) {
      const d = new Date(a.startDate);
      if (
        d.getFullYear() !== visibleMonth.getFullYear() ||
        d.getMonth() !== visibleMonth.getMonth()
      ) {
        continue;
      }
      const key = dayKey(d);
      const list = map.get(key) ?? [];
      list.push(a);
      map.set(key, list);
    }
    return map;
  }, [activities, visibleMonth]);

  const monthTotals = useMemo(() => {
    let count = 0;
    let km = 0;
    for (const list of byDay.values()) {
      count += list.length;
      km += list.reduce((s, a) => s + (a.distanceKm ?? 0), 0);
    }
    return { count, km };
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
  const hoverList = activeDay ? byDay.get(activeDay) : undefined;
  const footer = hoverList
    ? hoverList.length > 1
      ? t('calendar.dayMultiRuns', {
          count: hoverList.length,
          km: formatKm(hoverList.reduce((s, a) => s + (a.distanceKm ?? 0), 0)),
        })
      : t('calendar.daySingleRun', {
          date: formatMonthDay(new Date(hoverList[0].startDate)),
          name: hoverList[0].name,
          km: formatKm(hoverList[0].distanceKm ?? 0),
          pace: formatPace(hoverList[0].paceRawSecKm),
        })
    : t('calendar.monthSummary', {
        count: monthTotals.count,
        km: formatKm(monthTotals.km),
        month: visibleMonth.toLocaleDateString(currentIntlLocale(), {
          month: 'long',
        }),
      });

  return (
    <div
      ref={enterRef}
      data-enter={enterState}
      className="rounded-[12px] border border-border bg-card p-[18px] max-md:rounded-none max-md:border-x-0 max-md:border-b-0 max-md:bg-transparent max-md:px-0"
    >
      <div className="flex items-center justify-between">
        <div className="text-[13.5px] font-semibold text-foreground">
          {monthLabel}
        </div>
        <div className="flex gap-1">
          <button
            onClick={() => {
              setSelectedDay(null);
              setVisibleMonth(addMonths(visibleMonth, -1));
            }}
            disabled={!canPrev}
            aria-label={t('calendar.previousMonth')}
            className="flex h-8 w-8 cursor-pointer items-center justify-center rounded-[7px] bg-chip text-muted-foreground disabled:cursor-default disabled:opacity-30 md:h-6 md:w-6"
          >
            ‹
          </button>
          <button
            onClick={() => {
              setSelectedDay(null);
              setVisibleMonth(addMonths(visibleMonth, 1));
            }}
            disabled={!canNext}
            aria-label={t('calendar.nextMonth')}
            className="flex h-8 w-8 cursor-pointer items-center justify-center rounded-[7px] bg-chip text-muted-foreground disabled:cursor-default disabled:opacity-30 md:h-6 md:w-6"
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
            return <div key={`empty-${i}`} className="h-10 md:h-[35px]" />;
          }
          const date = new Date(
            visibleMonth.getFullYear(),
            visibleMonth.getMonth(),
            day,
          );
          const key = dayKey(date);
          const list = byDay.get(key);
          const hasActivity = !!list && list.length > 0;
          const isToday = sameDay(date, today);
          const isFuture = date.getTime() > today.getTime();

          return (
            <div
              key={key}
              className="flex h-10 cursor-pointer items-center justify-center md:h-[35px]"
              onMouseEnter={() => hasActivity && setHoverDay(key)}
              onClick={() => {
                if (!hasActivity) return;
                setHoverDay(null);
                setSelectedDay((cur) => (cur === key ? null : key));
              }}
            >
              <div
                className={`flex h-8 w-8 items-center justify-center rounded-full text-[13px] md:h-[30px] md:w-[30px] md:text-[12.5px] ${
                  hasActivity
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

import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDayMonth, formatMonthLong } from '@/lib/activityFormat';
import { DAY_MS } from './bins';

export interface DateRange {
  // midnight first activity
  start: number;
  // midnight last activity
  end: number;
}

interface DateRangePickerProps {
  range: DateRange | null;
  onChange: (range: DateRange | null) => void;
  // limits date navigation between activities date range
  minDate?: Date;
  // caps the span of a selected range (calendar months) — presets longer
  // than this are hidden and manual picks beyond it clamp to the anchor day
  maxMonths?: number;
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

// first tuple element is a dashboard.json key, translated at render time
function buildPresets(): [string, DateRange][] {
  const today = midnight(new Date());
  const thisM = monthStart(today);
  const lastM = addMonths(thisM, -1);
  const threeAgo = new Date(today);
  threeAgo.setMonth(threeAgo.getMonth() - 3);
  const y = today.getFullYear();
  return [
    [
      'dateRange.thisMonth',
      { start: thisM.getTime(), end: lastDayOfMonth(thisM).getTime() },
    ],
    [
      'dateRange.lastMonth',
      { start: lastM.getTime(), end: lastDayOfMonth(lastM).getTime() },
    ],
    [
      'dateRange.last3Months',
      { start: threeAgo.getTime(), end: today.getTime() },
    ],
    [
      'dateRange.thisYear',
      { start: new Date(y, 0, 1).getTime(), end: today.getTime() },
    ],
    [
      'dateRange.lastYear',
      {
        start: new Date(y - 1, 0, 1).getTime(),
        end: new Date(y - 1, 11, 31).getTime(),
      },
    ],
  ];
}

function CalendarIcon() {
  return (
    <svg
      width="11"
      height="11"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="3" y="4" width="18" height="18" rx="2" />
      <line x1="16" y1="2" x2="16" y2="6" />
      <line x1="8" y1="2" x2="8" y2="6" />
      <line x1="3" y1="10" x2="21" y2="10" />
    </svg>
  );
}

export default function DateRangePicker({
  range,
  onChange,
  minDate,
  maxMonths,
}: DateRangePickerProps) {
  const { t } = useTranslation('dashboard');
  const weekdays = t('dateRange.weekdaysShort', {
    returnObjects: true,
  }) as string[];
  const [open, setOpen] = useState(false);
  // fist month — default: last month (second month = current month)
  const [visibleMonth, setVisibleMonth] = useState<Date>(() =>
    addMonths(monthStart(new Date()), -1),
  );
  const [pendingStart, setPendingStart] = useState<number | null>(null);
  const [hoverDate, setHoverDate] = useState<number | null>(null);
  const rootRef = useRef<HTMLDivElement>(null);

  const close = () => {
    setOpen(false);
    setPendingStart(null);
    setHoverDate(null);
  };

  const toggle = () => {
    if (open) {
      close();
      return;
    }
    setVisibleMonth(
      range
        ? monthStart(new Date(range.start))
        : addMonths(monthStart(new Date()), -1),
    );
    setPendingStart(null);
    setOpen(true);
  };

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) {
        close();
      }
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') close();
    };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  // clamps the far end of a selection to maxMonths away from the anchor
  // (the first day clicked) instead of letting the picked span grow past it
  const clampToMax = (anchor: number, other: number): DateRange => {
    if (!maxMonths) {
      return { start: Math.min(anchor, other), end: Math.max(anchor, other) };
    }
    if (other >= anchor) {
      const cap = addMonths(new Date(anchor), maxMonths).getTime() - DAY_MS;
      return { start: anchor, end: Math.min(other, cap) };
    }
    const cap = addMonths(new Date(anchor), -maxMonths).getTime() + DAY_MS;
    return { start: Math.max(other, cap), end: anchor };
  };

  const beyondMax = (ts: number): boolean => {
    if (!maxMonths || pendingStart == null) return false;
    if (ts >= pendingStart) {
      const cap = addMonths(new Date(pendingStart), maxMonths).getTime() - DAY_MS;
      return ts > cap;
    }
    const cap = addMonths(new Date(pendingStart), -maxMonths).getTime() + DAY_MS;
    return ts < cap;
  };

  const paint: DateRange | null =
    pendingStart != null
      ? clampToMax(pendingStart, hoverDate ?? pendingStart)
      : range;

  const presets = buildPresets().filter(
    ([, preset]) =>
      !maxMonths || preset.end - preset.start <= maxMonths * 31 * DAY_MS,
  );

  const minMonth = minDate ? monthStart(minDate) : null;
  const maxMonth = monthStart(new Date());
  const canPrev = !minMonth || visibleMonth.getTime() > minMonth.getTime();
  const canNext = addMonths(visibleMonth, 1).getTime() < maxMonth.getTime();
  // mobile shows a single month, so "next" is allowed up to the current month
  const canNextMobile = visibleMonth.getTime() < maxMonth.getTime();

  const clickDay = (ts: number) => {
    if (pendingStart == null) {
      setPendingStart(ts);
      return;
    }
    onChange(clampToMax(pendingStart, ts));
    close();
  };

  const hint =
    pendingStart != null
      ? t('dateRange.selectLastDate')
      : range
        ? `${formatDayMonth(new Date(range.start))} – ${formatDayMonth(new Date(range.end))}`
        : t('dateRange.selectStartDate');

  const renderMonth = (month: Date, side: 'first' | 'second') => {
    const offset = (month.getDay() + 6) % 7; // week starts on monday
    const total = lastDayOfMonth(month).getDate();
    const cells: (number | null)[] = [
      ...Array(offset).fill(null),
      ...Array.from({ length: total }, (_, i) => i + 1),
    ];
    return (
      <div className="w-full md:w-[216px]">
        <div className="flex items-center justify-between">
          {side === 'first' ? (
            <button
              onClick={() => setVisibleMonth(addMonths(visibleMonth, -1))}
              disabled={!canPrev}
              aria-label={t('dateRange.previousMonth')}
              className="h-8 w-8 cursor-pointer rounded-[7px] text-muted-foreground hover:bg-chip disabled:cursor-default disabled:opacity-30 disabled:hover:bg-transparent md:h-[26px] md:w-[26px]"
            >
              ‹
            </button>
          ) : (
            <span className="w-[26px]" />
          )}
          <div className="text-[12.5px] font-semibold text-foreground">
            {formatMonthLong(month)}
          </div>
          {side === 'second' ? (
            <button
              onClick={() => setVisibleMonth(addMonths(visibleMonth, 1))}
              disabled={!canNext}
              aria-label={t('dateRange.nextMonth')}
              className="h-[26px] w-[26px] cursor-pointer rounded-[7px] text-muted-foreground hover:bg-chip disabled:cursor-default disabled:opacity-30 disabled:hover:bg-transparent"
            >
              ›
            </button>
          ) : (
            <>
              {/* mobile shows only this month, so it needs its own "next" */}
              <button
                onClick={() => setVisibleMonth(addMonths(visibleMonth, 1))}
                disabled={!canNextMobile}
                aria-label={t('dateRange.nextMonth')}
                className="h-8 w-8 cursor-pointer rounded-[7px] text-muted-foreground hover:bg-chip disabled:cursor-default disabled:opacity-30 disabled:hover:bg-transparent md:hidden"
              >
                ›
              </button>
              <span className="hidden w-[26px] md:block" />
            </>
          )}
        </div>
        <div className="mt-2 grid grid-cols-7">
          {weekdays.map((w) => (
            <div
              key={w}
              className="flex h-5 items-center justify-center text-[10px] uppercase text-muted-foreground"
            >
              {w}
            </div>
          ))}
          {cells.map((day, i) => {
            if (day == null) return <div key={`empty-${i}`} />;
            const ts = new Date(
              month.getFullYear(),
              month.getMonth(),
              day,
            ).getTime();
            const isEdge =
              paint != null && (ts === paint.start || ts === paint.end);
            const inMid = paint != null && ts > paint.start && ts < paint.end;
            const outOfMax = !isEdge && !inMid && beyondMax(ts);
            return (
              <button
                key={ts}
                onClick={() => clickDay(ts)}
                onMouseEnter={() => setHoverDate(ts)}
                className={`flex h-10 cursor-pointer items-center justify-center text-[13px] md:h-[27px] md:text-[12px] ${
                  isEdge
                    ? 'rounded-[8px] font-semibold text-acc-fg'
                    : inMid
                      ? 'text-foreground'
                      : outOfMax
                        ? 'rounded-[7px] text-muted-foreground opacity-40'
                        : 'rounded-[7px] text-foreground hover:bg-chip'
                }`}
                style={
                  isEdge
                    ? { background: 'var(--acc)' }
                    : inMid
                      ? {
                          background:
                            'color-mix(in oklab, var(--acc) 10%, transparent)',
                        }
                      : undefined
                }
              >
                {day}
              </button>
            );
          })}
        </div>
      </div>
    );
  };

  return (
    <div ref={rootRef} className="relative">
      <button
        onClick={toggle}
        className={`flex min-h-9 cursor-pointer items-center gap-1.5 rounded-[8px] border px-[11px] py-[5px] text-[11.5px] font-medium md:min-h-0 ${
          range ? 'border-transparent' : 'text-muted-foreground'
        }`}
        style={
          range
            ? {
                background: 'color-mix(in oklab, var(--acc) 10%, transparent)',
                color: 'var(--acc-tx)',
              }
            : { borderColor: 'var(--grid-ax)' }
        }
      >
        <CalendarIcon />
        {range
          ? `${formatDayMonth(new Date(range.start))} – ${formatDayMonth(new Date(range.end))}`
          : t('dateRange.custom')}
      </button>

      {open && (
        <>
          {/* mobile bottom-sheet scrim */}
          <div
            className="fixed inset-0 z-40 bg-[rgba(8,12,20,.35)] md:hidden"
            onClick={close}
          />
          <div
            className="fixed inset-x-0 bottom-0 z-50 rounded-t-[20px] border bg-card p-5 pb-[calc(20px+env(safe-area-inset-bottom))] md:absolute md:inset-x-auto md:bottom-auto md:top-[calc(100%+10px)] md:right-0 md:rounded-[14px] md:p-4"
            style={{
              borderColor: 'var(--grid-ax)',
              boxShadow: '0 12px 32px rgba(8,12,20,.16)',
            }}
          >
            {/* mobile: presets on top, single-month calendar below */}
            <div className="flex flex-col md:flex-row">
              <div className="flex flex-row flex-wrap gap-1.5 border-b border-border pb-3 md:w-[132px] md:flex-col md:gap-1 md:border-b-0 md:border-r md:pb-0 md:pr-3">
                {presets.map(([key, preset]) => (
                  <button
                    key={key}
                    onClick={() => {
                      onChange(preset);
                      close();
                    }}
                    className="cursor-pointer rounded-full bg-chip px-3 py-2 text-left text-[12.5px] font-medium text-foreground hover:bg-chip md:rounded-[8px] md:bg-transparent md:px-[10px] md:py-[7px]"
                  >
                    {t(key)}
                  </button>
                ))}
              </div>
              <div
                className="flex gap-[22px] pt-3 md:pl-4 md:pt-0"
                onMouseLeave={() => setHoverDate(null)}
              >
                {renderMonth(visibleMonth, 'first')}
                <div className="hidden md:block">
                  {renderMonth(addMonths(visibleMonth, 1), 'second')}
                </div>
              </div>
            </div>

            <div className="mt-3 flex items-center justify-between border-t border-border pt-3">
              <div className="text-[12px] text-muted-foreground">{hint}</div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => {
                    onChange(null);
                    setPendingStart(null);
                    setHoverDate(null);
                  }}
                  className="cursor-pointer rounded-[8px] px-2.5 py-[5px] text-[12px] font-medium text-muted-foreground hover:text-foreground"
                >
                  {t('dateRange.clean')}
                </button>
                <button
                  onClick={close}
                  className="cursor-pointer rounded-[8px] bg-chip px-2.5 py-[5px] text-[12px] font-medium text-foreground hover:bg-grid-ax"
                >
                  {t('dateRange.close')}
                </button>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

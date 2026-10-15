import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import SegmentedControl from '@/components/SegmentedControl';
import { currentIntlLocale } from '@/lib/dateLocale';
import type { DailyHistoryPoint } from '@/lib/types';
import { useDietHistory } from './useDietHistory';
import { useNutritionGoal } from './useNutritionGoal';
import { capitalize } from './constants';
import { DelayedSkeleton, Skeleton } from '@/components/Skeleton';

const CHART_HEIGHT = 140;

function shortLabel(date: string): string {
  return `${date.slice(8, 10)}/${date.slice(5, 7)}`;
}

function longLabel(date: string): string {
  const d = new Date(`${date}T00:00:00`);
  const text = d.toLocaleDateString(currentIntlLocale(), {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  });
  return capitalize(text);
}

function Chart({
  points,
  selectedDate,
  kcalGoal,
  rangeDays,
  onSelect,
}: {
  points: DailyHistoryPoint[];
  selectedDate: string;
  kcalGoal: number;
  rangeDays: 7 | 14;
  onSelect: (date: string) => void;
}) {
  const maxValue = Math.max(...points.map((p) => p.totalKcal), kcalGoal, 1);
  const goalPct = (kcalGoal / maxValue) * 100;
  const labelStep = rangeDays === 14 ? 2 : 1;

  return (
    <div className="mt-4">
      <div className="relative" style={{ height: CHART_HEIGHT }}>
        <div
          className="absolute right-0 left-0 border-t border-dashed"
          style={{ bottom: `${goalPct}%`, borderColor: 'var(--muted-foreground)' }}
        />
        <div className="flex h-full items-end gap-1.5">
          {points.map((p) => {
            const isSelected = p.date === selectedDate;
            const heightPct = Math.max(2, (p.totalKcal / maxValue) * 100);
            const color = isSelected
              ? 'var(--acc)'
              : p.totalKcal > kcalGoal
                ? 'color-mix(in oklab, var(--neg) 55%, transparent)'
                : 'color-mix(in oklab, var(--acc) 35%, transparent)';
            return (
              <button
                key={p.date}
                type="button"
                onClick={() => onSelect(p.date)}
                aria-label={p.date}
                className="h-full flex-1 cursor-pointer"
              >
                <span
                  className="block w-full rounded-t-[4px]"
                  style={{ height: `${heightPct}%`, backgroundColor: color }}
                />
              </button>
            );
          })}
        </div>
      </div>
      <div className="mt-1.5 flex gap-1.5">
        {points.map((p, i) => (
          <div
            key={p.date}
            className="flex-1 text-center text-[10.5px] text-muted-foreground tabular-nums"
          >
            {i % labelStep === 0 ? shortLabel(p.date) : ''}
          </div>
        ))}
      </div>
    </div>
  );
}

export default function DietHistoryPage() {
  const { t } = useTranslation('diet');
  const [rangeDays, setRangeDays] = useState<'7' | '14'>('7');
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const days = Number(rangeDays) as 7 | 14;
  const { points, loading } = useDietHistory(days);
  const { goal } = useNutritionGoal();
  const kcalGoal = goal?.dailyKcalGoal ?? 2000;

  useEffect(() => {
    if (points.length > 0) {
      setSelectedDate((current) =>
        current && points.some((p) => p.date === current)
          ? current
          : points[points.length - 1]!.date,
      );
    }
  }, [points]);

  const selected = points.find((p) => p.date === selectedDate) ?? points[points.length - 1];

  return (
    <div className="px-5 pt-[76px] pb-8">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-[25px] font-bold tracking-[-.02em] text-foreground">
            {t('history.title')}
          </h1>
          <p className="mt-0.5 text-[12.5px] text-muted-foreground">{t('history.subtitle')}</p>
        </div>
        <SegmentedControl
          items={[
            ['7', t('history.range7')],
            ['14', t('history.range14')],
          ]}
          active={rangeDays}
          onPick={setRangeDays}
        />
      </div>

      <div className="mt-5 rounded-[16px] border border-border bg-card p-[20px]">
        {selected && (
          <p className="text-[13px] font-medium text-foreground">
            {longLabel(selected.date)} · {Math.round(selected.totalKcal)} {t('history.kcal')} · P{' '}
            {Math.round(selected.totalProtein)}g · C {Math.round(selected.totalCarbs)}g · G{' '}
            {Math.round(selected.totalFat)}g
          </p>
        )}
        {loading && points.length === 0 && (
          <DelayedSkeleton>
            <Skeleton style={{ height: CHART_HEIGHT }} className="rounded-[10px]" />
          </DelayedSkeleton>
        )}
        {!loading && points.length > 0 && (
          <Chart
            points={points}
            selectedDate={selectedDate ?? ''}
            kcalGoal={kcalGoal}
            rangeDays={days}
            onSelect={setSelectedDate}
          />
        )}
      </div>

      <div className="mt-6">
        <div className="mb-2 px-1 text-[14px] font-semibold text-foreground">
          {t('history.daysTitle')}
        </div>
        <div className="rounded-[14px] border border-border bg-card">
          {[...points]
            .reverse()
            .map((p, i) => {
              const isSelected = p.date === selectedDate;
              const isOver = p.totalKcal > kcalGoal;
              return (
                <button
                  key={p.date}
                  type="button"
                  onClick={() => setSelectedDate(p.date)}
                  className={`flex w-full cursor-pointer items-center justify-between px-4 py-3 text-left hover:bg-chip ${
                    i > 0 ? 'border-t border-border' : ''
                  } ${isSelected ? 'bg-chip' : ''}`}
                >
                  <div>
                    <div className="text-[13px] font-medium text-foreground">
                      {longLabel(p.date)}
                    </div>
                    <div className="text-[11px] text-muted-foreground">
                      P {Math.round(p.totalProtein)}g · C {Math.round(p.totalCarbs)}g · G{' '}
                      {Math.round(p.totalFat)}g
                    </div>
                  </div>
                  <span
                    className="text-[13px] font-semibold tabular-nums"
                    style={{ color: isOver ? 'var(--neg)' : 'var(--foreground)' }}
                  >
                    {Math.round(p.totalKcal)} {t('history.kcal')}
                  </span>
                </button>
              );
            })}
        </div>
      </div>
    </div>
  );
}

import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Dumbbell, Search } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import type { ExerciseListItem, ExercisePersonalRecord } from '@/lib/types';
import { formatMonthDay } from '@/lib/activityFormat';
import ExercisePicker from './ExercisePicker';
import { formatWeight, weightLabel } from '@/lib/units';

// Personal Records card for GymOverviewPage.tsx — search-driven rather than
// a fixed list of named lifts: there's no "heaviest set ever" endpoint per
// well-known exercise name to resolve reliably (multiple library entries
// share words like "Squat"/"Bench Press"), so instead the user picks the
// exact exercise (same ExercisePicker.tsx used to add an exercise to a
// workout) and GET /exercises/:id/personal-record answers with the real
// heaviest set ever logged for it, plus which workout it happened in
export default function GymPersonalRecordCard() {
  const { t } = useTranslation('gym');
  const [pickerOpen, setPickerOpen] = useState(false);
  const [exercise, setExercise] = useState<ExerciseListItem | null>(null);
  const [record, setRecord] = useState<ExercisePersonalRecord | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!exercise) return;
    let cancelled = false;
    setLoading(true);
    apiFetch(`/exercises/${exercise.id}/personal-record`)
      .then((res) => (res.ok ? res.text() : ''))
      .then((text) => {
        if (!cancelled)
          setRecord(text ? (JSON.parse(text) as ExercisePersonalRecord) : null);
      })
      .catch(() => {
        if (!cancelled) setRecord(null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [exercise]);

  return (
    <div className="rounded-[14px] border border-border bg-card p-[16px_18px] max-md:rounded-none max-md:border-x-0 max-md:border-b-0 max-md:bg-transparent max-md:px-0">
      <div className="flex items-center justify-between">
        <div className="text-[13.5px] font-semibold text-foreground">
          {t('overview.records.title')}
        </div>
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          aria-label={t('overview.records.searchLabel')}
          className="flex h-7 w-7 cursor-pointer items-center justify-center rounded-[8px] bg-chip text-muted-foreground hover:text-foreground"
        >
          <Search className="h-3.5 w-3.5" strokeWidth={1.8} />
        </button>
      </div>

      {!exercise && (
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className="mt-3 flex w-full cursor-pointer items-center justify-center rounded-[10px] border border-dashed border-border py-[14px] text-[12.5px] font-medium text-muted-foreground hover:border-acc hover:text-acc-tx"
        >
          {t('overview.records.emptyPrompt')}
        </button>
      )}

      {exercise && (
        <div className="mt-2">
          {loading && (
            <p className="py-2 text-[12.5px] text-muted-foreground">
              {t('loading')}
            </p>
          )}

          {!loading && record && (
            <button
              type="button"
              onClick={() => setPickerOpen(true)}
              className="flex w-full cursor-pointer items-center gap-3 py-1 text-left"
            >
              <div
                className="flex h-9 w-9 flex-none items-center justify-center rounded-[10px] text-acc"
                style={{
                  background:
                    'color-mix(in oklab, var(--acc) 10%, transparent)',
                }}
              >
                <Dumbbell className="h-4 w-4" strokeWidth={1.8} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13.5px] font-semibold text-foreground">
                  {exercise.name}
                </div>
                <div className="mt-0.5 truncate text-[11.5px] text-muted-foreground">
                  {t('overview.records.recordMeta', {
                    date: formatMonthDay(new Date(record.startedAt)),
                    workout: record.templateName ?? t('start.freeWorkout'),
                  })}
                </div>
              </div>
              <div className="flex-none text-right">
                <div className="text-[15px] font-bold text-foreground">
                  {formatWeight(record.weightKg)} {weightLabel()}
                </div>
                <div className="mt-0.5 text-[11px] text-muted-foreground">
                  {record.reps != null
                    ? t('overview.records.repsValue', { reps: record.reps })
                    : '—'}
                </div>
              </div>
            </button>
          )}

          {!loading && !record && (
            <button
              type="button"
              onClick={() => setPickerOpen(true)}
              className="flex w-full cursor-pointer items-center gap-3 py-1 text-left"
            >
              <div className="flex h-9 w-9 flex-none items-center justify-center rounded-[10px] bg-chip text-muted-foreground">
                <Dumbbell className="h-4 w-4" strokeWidth={1.8} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13.5px] font-semibold text-foreground">
                  {exercise.name}
                </div>
                <div className="mt-0.5 text-[11.5px] text-muted-foreground">
                  {t('overview.records.noRecordYet')}
                </div>
              </div>
            </button>
          )}
        </div>
      )}

      {pickerOpen && (
        <ExercisePicker
          onClose={() => setPickerOpen(false)}
          onPick={(ex) => {
            setExercise(ex);
            setRecord(null);
            setPickerOpen(false);
          }}
        />
      )}
    </div>
  );
}

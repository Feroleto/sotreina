import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ChevronLeft, Minus, Plus } from 'lucide-react';
import type { Area, WeeklyGoals } from '@/lib/types';
import { distanceLabel, goalFromDisplay, goalToDisplay } from '@/lib/units';

// ranges mirror UsersController (MIN/MAX_WEEKLY_*_GOAL)
const RUN_KM_MIN = 1;
const RUN_KM_MAX = 300;
const WORKOUTS_MIN = 1;
const WORKOUTS_MAX = 14;

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function GoalRow({
  label,
  unit,
  value,
  min,
  max,
  onChange,
}: {
  label: string;
  unit: string;
  value: number;
  min: number;
  max: number;
  onChange: (v: number) => void;
}) {
  const { t } = useTranslation('today');
  return (
    <div className="flex items-center gap-3 border-b border-border py-4">
      <div className="min-w-0 flex-1">
        <div className="text-[14.5px] font-medium text-foreground">{label}</div>
        <div className="mt-0.5 text-[12px] text-muted-foreground">{unit}</div>
      </div>
      <button
        type="button"
        onClick={() => onChange(clamp(value - 1, min, max))}
        disabled={value <= min}
        aria-label={t('goals.decrease')}
        className="flex h-9 w-9 cursor-pointer items-center justify-center rounded-full bg-chip text-foreground hover:bg-grid-ax disabled:cursor-default disabled:opacity-40"
      >
        <Minus className="h-4 w-4" strokeWidth={2} />
      </button>
      <span className="w-[48px] text-center font-mono text-[20px] font-medium text-foreground">
        {value}
      </span>
      <button
        type="button"
        onClick={() => onChange(clamp(value + 1, min, max))}
        disabled={value >= max}
        aria-label={t('goals.increase')}
        className="flex h-9 w-9 cursor-pointer items-center justify-center rounded-full bg-chip text-foreground hover:bg-grid-ax disabled:cursor-default disabled:opacity-40"
      >
        <Plus className="h-4 w-4" strokeWidth={2} />
      </button>
    </div>
  );
}

interface WeeklyGoalsPageProps {
  goals: WeeklyGoals;
  /** only the steppers of these areas show (both are still saved as-is) */
  areas?: readonly Area[];
  onBack: () => void;
  onSave: (next: WeeklyGoals) => Promise<void>;
}

/** steppers for the weekly targets "Por área" measures against — same shape as Dieta's GoalPage */
export default function WeeklyGoalsPage({
  goals,
  areas = ['RUN', 'GYM'],
  onBack,
  onSave,
}: WeeklyGoalsPageProps) {
  const { t } = useTranslation('today');
  // the stepper works in whole display units (km or mi); the DB keeps whole km
  const initialRun = goalToDisplay(goals.weeklyRunKmGoal);
  const [run, setRun] = useState(initialRun);
  const [workouts, setWorkouts] = useState(goals.weeklyWorkoutsGoal);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    try {
      await onSave({
        // untouched → resend the stored km as-is, so a round trip through
        // miles never nudges a goal nobody edited
        weeklyRunKmGoal:
          run === initialRun ? goals.weeklyRunKmGoal : goalFromDisplay(run),
        weeklyWorkoutsGoal: workouts,
      });
    } catch {
      setError(t('goals.error'));
      setSaving(false);
    }
  };

  return (
    <div className="px-5 pt-[18px] pb-8 tabular-nums md:max-w-[640px]">
      <div className="mb-2 flex items-center gap-3">
        <button
          type="button"
          onClick={onBack}
          aria-label={t('goals.back')}
          className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-[9px] text-muted-foreground hover:bg-chip hover:text-foreground"
        >
          <ChevronLeft className="h-4.5 w-4.5" strokeWidth={1.8} />
        </button>
        <h1 className="text-[15px] font-semibold text-foreground">
          {t('goals.title')}
        </h1>
      </div>
      <p className="text-[12.5px] text-muted-foreground">
        {t('goals.subtitle')}
      </p>

      <div className="mt-3 border-t border-border">
        {areas.includes('RUN') && (
          <GoalRow
            label={t('goals.runKm')}
            unit={t('goals.runKmUnit', { unit: distanceLabel() })}
            value={run}
            min={RUN_KM_MIN}
            max={goalToDisplay(RUN_KM_MAX)}
            onChange={setRun}
          />
        )}
        {areas.includes('GYM') && (
          <GoalRow
            label={t('goals.workouts')}
            unit={t('goals.workoutsUnit')}
            value={workouts}
            min={WORKOUTS_MIN}
            max={WORKOUTS_MAX}
            onChange={setWorkouts}
          />
        )}
      </div>

      {error && <p className="mt-3 text-[12px] text-neg">{error}</p>}

      <button
        type="button"
        onClick={() => void handleSave()}
        disabled={saving}
        className="press mt-6 w-full cursor-pointer rounded-[11px] bg-acc px-4 py-3 text-[14px] font-semibold text-acc-fg disabled:cursor-default disabled:opacity-70"
      >
        {saving ? t('goals.saving') : t('goals.save')}
      </button>
    </div>
  );
}

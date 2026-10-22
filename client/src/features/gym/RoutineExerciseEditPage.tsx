import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, Minus, Plus } from 'lucide-react';
import type { TemplateExerciseTargets } from '@/lib/types';
import type { WorkingExercise } from './useRoutineEditor';
import {
  REST_FIRST_SEC,
  REST_MAX_SEC,
  REST_MIN_SEC,
  REST_STEP_SEC,
  formatRestSeconds,
} from './routineFormat';

const MIN_SETS = 1;
const MAX_SETS = 10;
const MIN_REPS = 1;
const MAX_REPS = 50;

const DEFAULT_SETS = 3;
const DEFAULT_REPS_MIN = 10;
const DEFAULT_REPS_MAX = 12;

interface RoutineExerciseEditPageProps {
  exercise: WorkingExercise;
  onBack: () => void;
  onChange: (targets: TemplateExerciseTargets) => void;
}

// mobile-only, full-screen "Editar exercício" — opened by tapping an
// already-added exercise card in the routine builder (RoutineEditPage.tsx),
// except its remove "×" and drag handle. Edits are live (no draft state,
// same "commit as you go" model as the rest of the builder): every stepper
// tap both updates the local number immediately (optimistic — edit mode's
// onChange is a network PATCH, and without this the stepper would visibly
// lag behind the tap) and calls onChange, same pattern already used by
// RoutineExerciseRow.tsx's inputs.
export default function RoutineExerciseEditPage({
  exercise,
  onBack,
  onChange,
}: RoutineExerciseEditPageProps) {
  const { t } = useTranslation('gym');
  const [sets, setSets] = useState(exercise.targetSets ?? DEFAULT_SETS);
  const [repsMin, setRepsMin] = useState(exercise.targetRepsMin ?? DEFAULT_REPS_MIN);
  const [repsMax, setRepsMax] = useState(exercise.targetRepsMax ?? DEFAULT_REPS_MAX);
  // undefined = no per-exercise rest, the timer's remembered length applies
  const [rest, setRest] = useState(exercise.restSeconds);

  // resync local numbers when the exercise prop changes for a reason outside
  // this component's own edits (e.g. a reorder's server response touching
  // this same row) — adjusted during render rather than via effect, per
  // React's guidance for state that must track a prop (avoids the
  // render→effect→render cascade a useEffect version would cause)
  const [prevTargets, setPrevTargets] = useState(exercise);
  if (
    exercise.targetSets !== prevTargets.targetSets ||
    exercise.targetRepsMin !== prevTargets.targetRepsMin ||
    exercise.targetRepsMax !== prevTargets.targetRepsMax ||
    exercise.restSeconds !== prevTargets.restSeconds
  ) {
    setPrevTargets(exercise);
    setSets(exercise.targetSets ?? DEFAULT_SETS);
    setRepsMin(exercise.targetRepsMin ?? DEFAULT_REPS_MIN);
    setRepsMax(exercise.targetRepsMax ?? DEFAULT_REPS_MAX);
    setRest(exercise.restSeconds);
  }

  const canDecreaseSets = sets > MIN_SETS;
  const canIncreaseSets = sets < MAX_SETS;
  const canDecreaseRepsMin = repsMin > MIN_REPS;
  const canIncreaseRepsMin = repsMin < repsMax && repsMin < MAX_REPS;
  const canDecreaseRepsMax = repsMax > repsMin && repsMax > MIN_REPS;
  const canIncreaseRepsMax = repsMax < MAX_REPS;

  const canIncreaseRest = rest == null || rest < REST_MAX_SEC;

  // "−" at the minimum steps back to "Padrão" rather than stopping there
  function decreaseRest() {
    if (rest == null) return;
    const next = rest - REST_STEP_SEC < REST_MIN_SEC ? undefined : rest - REST_STEP_SEC;
    setRest(next);
    onChange({ restSeconds: next });
  }
  function increaseRest() {
    if (!canIncreaseRest) return;
    const next = rest == null ? REST_FIRST_SEC : rest + REST_STEP_SEC;
    setRest(next);
    onChange({ restSeconds: next });
  }

  function decreaseSets() {
    if (!canDecreaseSets) return;
    const next = sets - 1;
    setSets(next);
    onChange({ targetSets: next });
  }
  function increaseSets() {
    if (!canIncreaseSets) return;
    const next = sets + 1;
    setSets(next);
    onChange({ targetSets: next });
  }
  function decreaseRepsMin() {
    if (!canDecreaseRepsMin) return;
    const next = repsMin - 1;
    setRepsMin(next);
    onChange({ targetRepsMin: next });
  }
  function increaseRepsMin() {
    if (!canIncreaseRepsMin) return;
    const next = repsMin + 1;
    setRepsMin(next);
    onChange({ targetRepsMin: next });
  }
  function decreaseRepsMax() {
    if (!canDecreaseRepsMax) return;
    const next = repsMax - 1;
    setRepsMax(next);
    onChange({ targetRepsMax: next });
  }
  function increaseRepsMax() {
    if (!canIncreaseRepsMax) return;
    const next = repsMax + 1;
    setRepsMax(next);
    onChange({ targetRepsMax: next });
  }

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-page-bg md:hidden">
      <div className="flex items-center gap-3 border-b border-border bg-card px-[18px] pt-[calc(12px+env(safe-area-inset-top))] pb-3">
        <button
          type="button"
          onClick={onBack}
          aria-label={t('routines.back')}
          className="cursor-pointer text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" strokeWidth={1.8} />
        </button>
        <h1 className="flex-1 text-[16px] font-semibold text-foreground">
          {t('editor.editExercise.title')}
        </h1>
        <button
          type="button"
          onClick={onBack}
          className="cursor-pointer text-[13.5px] font-semibold text-acc-tx"
        >
          {t('editor.done')}
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-[18px_20px_32px]">
        <div className="truncate text-[16px] font-semibold text-foreground">
          {exercise.exerciseName}
        </div>

        <div className="mt-[20px] rounded-[14px] border border-border bg-card p-[16px]">
          <div className="text-center text-[11px] font-medium tracking-[.05em] text-muted-foreground uppercase">
            {t('editor.editExercise.seriesLabel')}
          </div>
          <div className="mt-3 flex items-center justify-center gap-6">
            <button
              type="button"
              onClick={decreaseSets}
              disabled={!canDecreaseSets}
              aria-label={t('editor.editExercise.decreaseSets')}
              className="flex h-[34px] w-[34px] cursor-pointer items-center justify-center rounded-full bg-chip text-foreground disabled:cursor-not-allowed disabled:opacity-30"
            >
              <Minus className="h-4 w-4" strokeWidth={2.2} />
            </button>
            <span className="w-10 text-center text-[26px] font-bold text-foreground">
              {sets}
            </span>
            <button
              type="button"
              onClick={increaseSets}
              disabled={!canIncreaseSets}
              aria-label={t('editor.editExercise.increaseSets')}
              className="flex h-[34px] w-[34px] cursor-pointer items-center justify-center rounded-full bg-chip text-foreground disabled:cursor-not-allowed disabled:opacity-30"
            >
              <Plus className="h-4 w-4" strokeWidth={2.2} />
            </button>
          </div>
        </div>

        <div className="mt-[14px] rounded-[14px] border border-border bg-card p-[16px]">
          <div className="text-center text-[11px] font-medium tracking-[.05em] text-muted-foreground uppercase">
            {t('editor.editExercise.repsLabel')}
          </div>
          <div className="mt-1 text-center text-[11.5px] text-muted-foreground">
            {t('editor.editExercise.repsHint')}
          </div>
          <div className="mt-3 flex items-center justify-center gap-3">
            <button
              type="button"
              onClick={decreaseRepsMin}
              disabled={!canDecreaseRepsMin}
              aria-label={t('editor.editExercise.decreaseRepsMin')}
              className="flex h-[30px] w-[30px] cursor-pointer items-center justify-center rounded-full bg-chip text-foreground disabled:cursor-not-allowed disabled:opacity-30"
            >
              <Minus className="h-3.5 w-3.5" strokeWidth={2.2} />
            </button>
            <span className="w-8 text-center text-[20px] font-bold text-foreground">
              {repsMin}
            </span>
            <button
              type="button"
              onClick={increaseRepsMin}
              disabled={!canIncreaseRepsMin}
              aria-label={t('editor.editExercise.increaseRepsMin')}
              className="flex h-[30px] w-[30px] cursor-pointer items-center justify-center rounded-full bg-chip text-foreground disabled:cursor-not-allowed disabled:opacity-30"
            >
              <Plus className="h-3.5 w-3.5" strokeWidth={2.2} />
            </button>

            <span className="px-1 text-[14px] text-muted-foreground">–</span>

            <button
              type="button"
              onClick={decreaseRepsMax}
              disabled={!canDecreaseRepsMax}
              aria-label={t('editor.editExercise.decreaseRepsMax')}
              className="flex h-[30px] w-[30px] cursor-pointer items-center justify-center rounded-full bg-chip text-foreground disabled:cursor-not-allowed disabled:opacity-30"
            >
              <Minus className="h-3.5 w-3.5" strokeWidth={2.2} />
            </button>
            <span className="w-8 text-center text-[20px] font-bold text-foreground">
              {repsMax}
            </span>
            <button
              type="button"
              onClick={increaseRepsMax}
              disabled={!canIncreaseRepsMax}
              aria-label={t('editor.editExercise.increaseRepsMax')}
              className="flex h-[30px] w-[30px] cursor-pointer items-center justify-center rounded-full bg-chip text-foreground disabled:cursor-not-allowed disabled:opacity-30"
            >
              <Plus className="h-3.5 w-3.5" strokeWidth={2.2} />
            </button>
          </div>
        </div>

        <div className="mt-[14px] rounded-[14px] border border-border bg-card p-[16px]">
          <div className="text-center text-[11px] font-medium tracking-[.05em] text-muted-foreground uppercase">
            {t('editor.editExercise.restLabel')}
          </div>
          <div className="mt-1 text-center text-[11.5px] text-muted-foreground">
            {t('editor.editExercise.restHint')}
          </div>
          <div className="mt-3 flex items-center justify-center gap-6">
            <button
              type="button"
              onClick={decreaseRest}
              disabled={rest == null}
              aria-label={t('editor.editExercise.decreaseRest')}
              className="flex h-[34px] w-[34px] cursor-pointer items-center justify-center rounded-full bg-chip text-foreground disabled:cursor-not-allowed disabled:opacity-30"
            >
              <Minus className="h-4 w-4" strokeWidth={2.2} />
            </button>
            <span className="w-20 text-center font-mono text-[22px] font-bold text-foreground">
              {rest == null ? t('editor.editExercise.restDefault') : formatRestSeconds(rest)}
            </span>
            <button
              type="button"
              onClick={increaseRest}
              disabled={!canIncreaseRest}
              aria-label={t('editor.editExercise.increaseRest')}
              className="flex h-[34px] w-[34px] cursor-pointer items-center justify-center rounded-full bg-chip text-foreground disabled:cursor-not-allowed disabled:opacity-30"
            >
              <Plus className="h-4 w-4" strokeWidth={2.2} />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

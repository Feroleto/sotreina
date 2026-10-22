import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ChevronDown, ChevronUp, Trash2 } from 'lucide-react';
import type { TemplateExerciseTargets } from '@/lib/types';
import type { WorkingExercise } from './useRoutineEditor';
import { REST_OPTIONS_SEC, formatRestSeconds } from './routineFormat';

interface RoutineExerciseRowProps {
  exercise: WorkingExercise;
  isFirst: boolean;
  isLast: boolean;
  onMoveUp: () => void;
  onMoveDown: () => void;
  onRemove: () => void;
  onTargetsChange: (targets: TemplateExerciseTargets) => void;
}

export default function RoutineExerciseRow({
  exercise,
  isFirst,
  isLast,
  onMoveUp,
  onMoveDown,
  onRemove,
  onTargetsChange,
}: RoutineExerciseRowProps) {
  const { t } = useTranslation('gym');
  const [sets, setSets] = useState(exercise.targetSets?.toString() ?? '');
  const [repsMin, setRepsMin] = useState(exercise.targetRepsMin?.toString() ?? '');
  const [repsMax, setRepsMax] = useState(exercise.targetRepsMax?.toString() ?? '');

  // keep local inputs in sync when edit mode reloads state from the server
  // (e.g. after a reorder swap touches this row too)
  useEffect(() => {
    setSets(exercise.targetSets?.toString() ?? '');
    setRepsMin(exercise.targetRepsMin?.toString() ?? '');
    setRepsMax(exercise.targetRepsMax?.toString() ?? '');
  }, [exercise.targetSets, exercise.targetRepsMin, exercise.targetRepsMax]);

  const commit = () => {
    onTargetsChange({
      targetSets: sets.trim() ? Number(sets) : undefined,
      targetRepsMin: repsMin.trim() ? Number(repsMin) : undefined,
      targetRepsMax: repsMax.trim() ? Number(repsMax) : undefined,
      restSeconds: exercise.restSeconds,
    });
  };

  // a value set elsewhere (the mobile stepper's 15s steps) that isn't one of
  // the select's options still has to be shown, not silently swapped
  const restOptions =
    exercise.restSeconds != null && !REST_OPTIONS_SEC.includes(exercise.restSeconds)
      ? [...REST_OPTIONS_SEC, exercise.restSeconds].sort((a, b) => a - b)
      : REST_OPTIONS_SEC;

  return (
    <div className="rounded-[14px] border border-border bg-card p-3.5">
      <div className="flex items-center gap-2">
        <div className="flex flex-none flex-col">
          <button
            type="button"
            onClick={onMoveUp}
            disabled={isFirst}
            aria-label={t('editor.moveUp')}
            className="cursor-pointer p-0.5 text-muted-foreground hover:text-foreground disabled:cursor-not-allowed disabled:opacity-30"
          >
            <ChevronUp className="h-3.5 w-3.5" strokeWidth={1.8} />
          </button>
          <button
            type="button"
            onClick={onMoveDown}
            disabled={isLast}
            aria-label={t('editor.moveDown')}
            className="cursor-pointer p-0.5 text-muted-foreground hover:text-foreground disabled:cursor-not-allowed disabled:opacity-30"
          >
            <ChevronDown className="h-3.5 w-3.5" strokeWidth={1.8} />
          </button>
        </div>
        <span className="flex-1 text-[13.5px] font-medium text-foreground">
          {exercise.exerciseName}
        </span>
        <button
          type="button"
          onClick={onRemove}
          aria-label={t('editor.removeExercise')}
          className="cursor-pointer p-1 text-muted-foreground hover:text-neg"
        >
          <Trash2 className="h-3.5 w-3.5" strokeWidth={1.8} />
        </button>
      </div>

      <div className="mt-2.5 flex items-center gap-2">
        <input
          type="number"
          inputMode="numeric"
          value={sets}
          onChange={(e) => setSets(e.target.value)}
          onBlur={commit}
          placeholder={t('editor.setsPlaceholder')}
          aria-label={t('editor.setsPlaceholder')}
          className="h-9 w-16 rounded-[8px] border border-border bg-page-bg px-2 text-[13px] text-foreground outline-none focus:border-acc"
        />
        <input
          type="number"
          inputMode="numeric"
          value={repsMin}
          onChange={(e) => setRepsMin(e.target.value)}
          onBlur={commit}
          placeholder={t('editor.repsMinPlaceholder')}
          aria-label={t('editor.repsMinPlaceholder')}
          className="h-9 w-16 rounded-[8px] border border-border bg-page-bg px-2 text-[13px] text-foreground outline-none focus:border-acc"
        />
        <span className="text-[12px] text-muted-foreground">–</span>
        <input
          type="number"
          inputMode="numeric"
          value={repsMax}
          onChange={(e) => setRepsMax(e.target.value)}
          onBlur={commit}
          placeholder={t('editor.repsMaxPlaceholder')}
          aria-label={t('editor.repsMaxPlaceholder')}
          className="h-9 w-16 rounded-[8px] border border-border bg-page-bg px-2 text-[13px] text-foreground outline-none focus:border-acc"
        />
        <span className="text-[11px] text-muted-foreground">{t('editor.repsUnit')}</span>
        <select
          value={exercise.restSeconds ?? ''}
          onChange={(e) =>
            onTargetsChange({
              targetSets: sets.trim() ? Number(sets) : undefined,
              targetRepsMin: repsMin.trim() ? Number(repsMin) : undefined,
              targetRepsMax: repsMax.trim() ? Number(repsMax) : undefined,
              restSeconds: e.target.value ? Number(e.target.value) : undefined,
            })
          }
          aria-label={t('editor.restPlaceholder')}
          title={t('editor.restPlaceholder')}
          className="ml-auto h-9 rounded-[8px] border border-border bg-page-bg px-2 text-[13px] text-foreground outline-none focus:border-acc"
        >
          <option value="">
            {t('editor.restPlaceholder')}: {t('editor.restDefault')}
          </option>
          {restOptions.map((sec) => (
            <option key={sec} value={sec}>
              {t('editor.restPlaceholder')}: {formatRestSeconds(sec)}
            </option>
          ))}
        </select>
      </div>
    </div>
  );
}

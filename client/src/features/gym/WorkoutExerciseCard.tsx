import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Check, GripVertical, Trash2, X } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import type {
  LastPerformance,
  LastPerformanceSet,
  SetInput,
  WorkoutExercise,
  WorkoutSet,
} from '@/lib/types';
import { formatRepsRange } from './routineFormat';

// exported so ActiveWorkoutBar can mirror the same "no target → 3 rows"
// fallback when totaling sets across the whole workout
export const DEFAULT_SET_COUNT = 3;

interface LoggedSetRowProps {
  index: number;
  set: WorkoutSet;
  busy: boolean;
  onUpdate: (input: SetInput) => void;
  onUncheck: () => void;
}

// an already-logged set — always "completed" (its mere existence in the DB
// means it was done, there's no partial/pending state server-side).
// Weight/reps stay editable (commit on blur via updateSet, same "commita
// conforme faz" convention as RoutineExerciseRow.tsx); unchecking deletes it
function LoggedSetRow({ index, set, busy, onUpdate, onUncheck }: LoggedSetRowProps) {
  const { t } = useTranslation('gym');
  const [weightText, setWeightText] = useState(set.weightKg != null ? String(set.weightKg) : '');
  const [repsText, setRepsText] = useState(set.reps != null ? String(set.reps) : '');

  // resync local text when the set changes for a reason outside this row's
  // own edits (e.g. another mutation refetching the whole workout) —
  // adjusted during render, not via effect, per React's guidance
  const [prevSet, setPrevSet] = useState(set);
  if (set.weightKg !== prevSet.weightKg || set.reps !== prevSet.reps) {
    setPrevSet(set);
    setWeightText(set.weightKg != null ? String(set.weightKg) : '');
    setRepsText(set.reps != null ? String(set.reps) : '');
  }

  function commitWeight() {
    const trimmed = weightText.trim();
    const value = trimmed === '' ? undefined : Number(trimmed);
    if (value !== undefined && (!Number.isFinite(value) || value < 0)) return;
    onUpdate({ weightKg: value });
  }

  function commitReps() {
    const trimmed = repsText.trim();
    const value = trimmed === '' ? undefined : Number(trimmed);
    if (value !== undefined && (!Number.isInteger(value) || value < 0)) return;
    onUpdate({ reps: value });
  }

  return (
    <div className="mt-2 flex items-center gap-1.5">
      <div className="w-[20px] flex-none text-[13px] font-medium text-foreground">{index}</div>
      <div className="w-[56px] flex-none truncate text-[11px] text-muted-foreground">
        {t('train.previousValue', { weight: set.weightKg ?? '—', reps: set.reps ?? '—' })}
      </div>
      <input
        type="number"
        inputMode="decimal"
        value={weightText}
        onChange={(e) => setWeightText(e.target.value)}
        onBlur={commitWeight}
        disabled={busy}
        aria-label={t('entry.weightLabel')}
        className="h-9 min-w-0 flex-1 rounded-[8px] border border-border bg-page-bg px-1.5 text-[16px] font-medium text-foreground outline-none focus:border-acc md:text-[13px]"
      />
      <input
        type="number"
        inputMode="numeric"
        value={repsText}
        onChange={(e) => setRepsText(e.target.value)}
        onBlur={commitReps}
        disabled={busy}
        aria-label={t('entry.repsLabel')}
        className="h-9 min-w-0 flex-1 rounded-[8px] border border-border bg-page-bg px-1.5 text-[16px] font-medium text-foreground outline-none focus:border-acc md:text-[13px]"
      />
      {/* empty spacer — keeps column alignment with EmptySetRow's remove button, which this row never shows */}
      <div className="w-[18px] flex-none" />
      <button
        type="button"
        onClick={onUncheck}
        disabled={busy}
        aria-label={t('train.markUndone')}
        className="press flex h-[26px] w-[26px] flex-none cursor-pointer items-center justify-center rounded-full bg-acc text-acc-fg disabled:cursor-not-allowed disabled:opacity-50"
      >
        <Check className="h-3.5 w-3.5" strokeWidth={2.2} />
      </button>
    </div>
  );
}

interface EmptySetRowProps {
  index: number;
  enabled: boolean;
  isLast: boolean;
  suggestion: LastPerformanceSet | null;
  busy: boolean;
  onLog: (input: SetInput) => void;
  onRemove: () => void;
}

// not-yet-logged row — only the row right after the last real set is
// `enabled` (fill-in is sequential, matching how addSet always creates the
// next setNumber); the rest are inert placeholders. Checking with empty
// inputs falls back to this row's own suggestion (the same set number from
// the last finished session, not just a single repeated value). Only the
// trailing row (isLast) shows a remove button — symmetric with "+ Adicionar
// série" always appending at the end, and avoids ambiguity about which of
// several empty rows should disappear
function EmptySetRow({ index, enabled, isLast, suggestion, busy, onLog, onRemove }: EmptySetRowProps) {
  const { t } = useTranslation('gym');
  const [weightText, setWeightText] = useState('');
  const [repsText, setRepsText] = useState('');

  function handleCheck() {
    if (!enabled || busy) return;
    const weightKg = weightText.trim() ? Number(weightText) : (suggestion?.weightKg ?? undefined);
    const reps = repsText.trim() ? Number(repsText) : (suggestion?.reps ?? undefined);
    onLog({ weightKg, reps });
  }

  const previousText = suggestion
    ? t('train.previousValue', { weight: suggestion.weightKg ?? '—', reps: suggestion.reps ?? '—' })
    : '—';

  return (
    <div className="mt-2 flex items-center gap-1.5">
      <div className="w-[20px] flex-none text-[13px] font-medium text-foreground">{index}</div>
      <div className="w-[56px] flex-none truncate text-[11px] text-muted-foreground">
        {previousText}
      </div>
      <input
        type="number"
        inputMode="decimal"
        value={weightText}
        onChange={(e) => setWeightText(e.target.value)}
        placeholder={suggestion?.weightKg != null ? String(suggestion.weightKg) : ''}
        disabled={!enabled || busy}
        aria-label={t('entry.weightLabel')}
        className="h-9 min-w-0 flex-1 rounded-[8px] border border-border bg-page-bg px-1.5 text-[16px] font-medium text-foreground outline-none focus:border-acc disabled:opacity-40 md:text-[13px]"
      />
      <input
        type="number"
        inputMode="numeric"
        value={repsText}
        onChange={(e) => setRepsText(e.target.value)}
        placeholder={suggestion?.reps != null ? String(suggestion.reps) : ''}
        disabled={!enabled || busy}
        aria-label={t('entry.repsLabel')}
        className="h-9 min-w-0 flex-1 rounded-[8px] border border-border bg-page-bg px-1.5 text-[16px] font-medium text-foreground outline-none focus:border-acc disabled:opacity-40 md:text-[13px]"
      />
      {isLast ? (
        <button
          type="button"
          onClick={onRemove}
          disabled={busy}
          aria-label={t('train.removeSet')}
          className="flex h-[18px] w-[18px] flex-none cursor-pointer items-center justify-center text-muted-foreground hover:text-neg disabled:cursor-not-allowed disabled:opacity-50"
        >
          <X className="h-3.5 w-3.5" strokeWidth={2} />
        </button>
      ) : (
        <div className="w-[18px] flex-none" />
      )}
      <button
        type="button"
        onClick={handleCheck}
        disabled={!enabled || busy}
        aria-label={t('train.markDone')}
        className="flex h-[26px] w-[26px] flex-none cursor-pointer items-center justify-center rounded-full bg-chip text-muted-foreground disabled:cursor-not-allowed disabled:opacity-30"
      >
        <Check className="h-3.5 w-3.5" strokeWidth={2.2} />
      </button>
    </div>
  );
}

interface WorkoutExerciseCardProps {
  workoutExercise: WorkoutExercise;
  busy: boolean;
  onAddSet: (input: SetInput) => void;
  onUpdateSet: (setId: string, input: SetInput) => void;
  onDeleteSet: (setId: string) => void;
  onRemove: () => void;
  // drag-to-reorder — same Pointer Events pattern as the routine builder's
  // mobile card (RoutineEditPage.tsx): cardRef/dataKey let WorkoutSession
  // locate this row via elementFromPoint and measure it for the FLIP
  // animation, isDragging dims it while it's the one being moved, and the
  // handle's onPointerDown is where the drag gesture actually starts
  cardRef?: (el: HTMLDivElement | null) => void;
  dataKey?: string;
  isDragging?: boolean;
  onDragHandlePointerDown?: (e: React.PointerEvent<HTMLButtonElement>) => void;
}

// one exercise within the active workout session (WorkoutSession.tsx) — real
// backend-wired equivalent of the former TrainExerciseCard.tsx mock. Row
// count is target sets (or however many are already logged, if that's more)
// plus any manually added extra rows; "anterior" comes from the real
// GET /exercises/:id/last-performance (same fetch ExerciseEntry.tsx used),
// matched per row index against that session's own sets — not a single
// repeated value. onRemove drops the exercise (and every set already logged
// for it, via the backend's schema cascade) from the workout entirely —
// immediate, no confirmation, same "no undo" convention already used for
// unchecking a single logged set in this same screen
export default function WorkoutExerciseCard({
  workoutExercise,
  busy,
  onAddSet,
  onUpdateSet,
  onDeleteSet,
  onRemove,
  cardRef,
  dataKey,
  isDragging,
  onDragHandlePointerDown,
}: WorkoutExerciseCardProps) {
  const { t } = useTranslation('gym');
  const [lastPerformance, setLastPerformance] = useState<LastPerformance | null>(null);

  useEffect(() => {
    let cancelled = false;
    apiFetch(`/exercises/${workoutExercise.exerciseId}/last-performance`)
      .then((res) => (res.ok ? res.text() : ''))
      .then((text) => {
        if (!cancelled) setLastPerformance(text ? (JSON.parse(text) as LastPerformance) : null);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [workoutExercise.exerciseId]);

  function suggestionForRow(idx: number): LastPerformanceSet | null {
    if (!lastPerformance || lastPerformance.sets.length === 0) return null;
    return lastPerformance.sets[idx] ?? lastPerformance.sets[lastPerformance.sets.length - 1];
  }

  const loggedCount = workoutExercise.sets.length;
  const targetCount = workoutExercise.target?.sets ?? DEFAULT_SET_COUNT;
  // total row count the user is currently asking to see — grows by 1 per
  // "+ Adicionar série" tap, NOT recomputed from loggedCount every render
  // (that was the bug: max(target, loggedCount) + extraRows kept adding
  // extraRows on top of a loggedCount that itself already grew after
  // checking the extra row, so a new empty row kept reappearing forever
  // after the first tap). Grows to loggedCount if that ever gets ahead of it
  // (e.g. more sets already existed than the target when this card mounted)
  const [totalRows, setTotalRows] = useState(() => Math.max(targetCount, loggedCount));
  if (loggedCount > totalRows) {
    setTotalRows(loggedCount);
  }
  const emptyCount = totalRows - loggedCount;

  return (
    <div
      ref={cardRef}
      data-exercise-key={dataKey}
      className={`rounded-[14px] border border-border bg-card p-[14px] ${
        isDragging ? 'opacity-40' : ''
      }`}
    >
      <div className="flex items-center justify-between gap-2">
        {onDragHandlePointerDown && (
          <button
            type="button"
            onPointerDown={onDragHandlePointerDown}
            aria-label={t('editor.reorderExercise')}
            className="flex-none cursor-grab touch-none p-1 text-muted-foreground active:cursor-grabbing"
          >
            <GripVertical className="h-4 w-4" strokeWidth={1.8} />
          </button>
        )}
        <div className="min-w-0 flex-1">
          <h2 className="truncate text-[14.5px] font-semibold text-foreground">
            {workoutExercise.exerciseName}
          </h2>
          {(workoutExercise.target?.repsMin != null || workoutExercise.target?.repsMax != null) && (
            <p className="mt-0.5 text-[11.5px] text-muted-foreground">
              {t('train.targetReps', {
                reps: formatRepsRange(workoutExercise.target?.repsMin, workoutExercise.target?.repsMax),
              })}
            </p>
          )}
        </div>
        <button
          type="button"
          onClick={onRemove}
          disabled={busy}
          aria-label={t('editor.removeExercise')}
          className="flex h-6 w-6 flex-none cursor-pointer items-center justify-center text-neg disabled:cursor-not-allowed disabled:opacity-50"
        >
          <Trash2 className="h-3.5 w-3.5" strokeWidth={1.8} />
        </button>
      </div>

      <div className="mt-3 flex items-center gap-1.5 text-[10px] font-medium tracking-[.04em] text-muted-foreground uppercase">
        <div className="w-[20px] flex-none">{t('train.columnSet')}</div>
        <div className="w-[56px] flex-none">{t('train.columnPrevious')}</div>
        <div className="min-w-0 flex-1">{t('train.columnWeight')}</div>
        <div className="min-w-0 flex-1">{t('train.columnReps')}</div>
        <div className="w-[18px] flex-none" />
        <div className="w-[26px] flex-none" />
      </div>

      {workoutExercise.sets.map((set, idx) => (
        <LoggedSetRow
          key={set.id}
          index={idx + 1}
          set={set}
          busy={busy}
          onUpdate={(input) => onUpdateSet(set.id, input)}
          onUncheck={() => onDeleteSet(set.id)}
        />
      ))}

      {Array.from({ length: emptyCount }).map((_, i) => (
        // keyed by absolute row position (not `i`, which is relative to the
        // empty sub-list and shrinks every time a set is logged) — otherwise
        // React would recycle the enabled row's local draft state into what
        // is now a different logical row once it's promoted to a LoggedSetRow
        <EmptySetRow
          key={`empty-row-${loggedCount + i}`}
          index={loggedCount + i + 1}
          enabled={i === 0}
          isLast={i === emptyCount - 1}
          busy={busy}
          suggestion={suggestionForRow(loggedCount + i)}
          onLog={onAddSet}
          onRemove={() => setTotalRows((n) => Math.max(loggedCount, n - 1))}
        />
      ))}

      <button
        type="button"
        onClick={() => setTotalRows((n) => n + 1)}
        className="mt-2 flex w-full cursor-pointer items-center justify-center rounded-[8px] border border-dashed border-border py-[6px] text-[12px] font-medium text-muted-foreground hover:border-acc hover:text-acc-tx"
      >
        {t('train.addSet')}
      </button>
    </div>
  );
}

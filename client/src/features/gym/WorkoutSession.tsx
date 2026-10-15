import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Menu, X } from 'lucide-react';
import type { ExerciseListItem, SetInput, WorkoutDetail } from '@/lib/types';
import ExercisePicker from './ExercisePicker';
import RoutineExercisePicker from './RoutineExercisePicker';
import WorkoutExerciseCard from './WorkoutExerciseCard';
import RestTimerControl from './RestTimerControl';
import { useRestTimer } from './useRestTimer';
import { primeAudio } from './restAudio';

interface WorkoutSessionProps {
  workout: WorkoutDetail;
  error: string | null;
  busy: boolean;
  onAddExercise: (exerciseId: string) => void;
  onRemoveExercise: (workoutExerciseId: string) => void;
  onReorderExercise: (id: string, beforeId: string) => void;
  onCommitReorderExercises: (originalIds: string[]) => void;
  onAddSet: (workoutExerciseId: string, input: SetInput) => Promise<boolean>;
  onUpdateSet: (workoutExerciseId: string, setId: string, input: SetInput) => void;
  onDeleteSet: (workoutExerciseId: string, setId: string) => void;
  onCheckTemplateDrift: () => Promise<boolean>;
  onFinish: (syncTemplate: boolean) => void;
  onDiscard: () => void;
  // opens the normal nav drawer (MobileChrome's) without touching the
  // running session underneath — lets the user leave this screen through
  // any navigation path instead of only finish/discard
  onOpenDrawer: () => void;
}

function formatElapsed(totalSec: number): string {
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

// Real, persisted workout session — grid of rows per exercise with a check
// to log each set (WorkoutExerciseCard.tsx), replacing the older
// "log one set at a time" form (ExerciseEntry.tsx, deleted). Every row is
// already saved the moment it's checked, so "Finalizar treino" just marks
// the workout done — "Cancelar treino" (onDiscard) is the explicit escape
// hatch for throwing the whole thing away (deletes the Workout row and,
// via schema cascade, every WorkoutExercise/WorkoutSet under it), gated
// behind an inline confirm bar since it's destructive and irreversible.
// Elapsed time comes from the real `workout.startedAt` (survives a refresh
// mid-workout, unlike the mock's client-side Date.now() snapshot)
export default function WorkoutSession({
  workout,
  error,
  busy,
  onAddExercise,
  onRemoveExercise,
  onReorderExercise,
  onCommitReorderExercises,
  onAddSet,
  onUpdateSet,
  onDeleteSet,
  onCheckTemplateDrift,
  onFinish,
  onDiscard,
  onOpenDrawer,
}: WorkoutSessionProps) {
  const { t } = useTranslation('gym');
  const [pickerOpen, setPickerOpen] = useState(false);
  const [confirmingDiscard, setConfirmingDiscard] = useState(false);
  const [elapsedSec, setElapsedSec] = useState(0);
  // gates the "update the routine too?" prompt — 'checking' while the
  // async drift request is in flight (only relevant for a templated
  // workout; a free workout finishes immediately, see handleFinishClick),
  // 'confirm-sync' once a divergence is confirmed
  const [finishStep, setFinishStep] = useState<'idle' | 'checking' | 'confirm-sync'>('idle');
  // one timer per session, not per exercise — rest is always from the
  // workout as a whole, matches how the fixed footer is one shared element
  const restTimer = useRestTimer();

  // Drag-to-reorder exercises — identical Pointer Events mechanism to the
  // routine builder's mobile card (RoutineEditPage.tsx): works for mouse and
  // touch alike, reorders live as the pointer crosses into another card (via
  // elementFromPoint + data-exercise-key), and persists once on drop rather
  // than per crossing.
  const [dragKey, setDragKey] = useState<string | null>(null);
  const dragStartOrder = useRef<string[]>([]);

  useEffect(() => {
    if (!dragKey) return;
    const onMove = (e: PointerEvent) => {
      const el = document
        .elementFromPoint(e.clientX, e.clientY)
        ?.closest<HTMLElement>('[data-exercise-key]');
      const overKey = el?.dataset.exerciseKey;
      if (overKey && overKey !== dragKey) {
        onReorderExercise(dragKey, overKey);
      }
    };
    const onUp = () => {
      onCommitReorderExercises(dragStartOrder.current);
      setDragKey(null);
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('pointercancel', onUp);
    return () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      window.removeEventListener('pointercancel', onUp);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dragKey]);

  // FLIP (First-Last-Invert-Play) animation for the reordering above — same
  // approach as RoutineEditPage.tsx (no animation lib in this project):
  // measures each card before/after a reorder and animates the delta instead
  // of letting React's keyed re-render just snap cards to their new spot.
  const cardRefs = useRef(new Map<string, HTMLDivElement>());
  const cardRects = useRef(new Map<string, DOMRect>());
  const rafIds = useRef(new Map<string, number>());
  const exerciseKeyOrder = workout.exercises.map((we) => we.id).join(',');

  useLayoutEffect(() => {
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    cardRefs.current.forEach((el, key) => {
      const prevRect = cardRects.current.get(key);
      const nextRect = el.getBoundingClientRect();
      if (prevRect && !reduceMotion) {
        const deltaY = prevRect.top - nextRect.top;
        if (deltaY !== 0) {
          const pending = rafIds.current.get(key);
          if (pending !== undefined) cancelAnimationFrame(pending);

          el.style.transition = 'none';
          el.style.transform = `translateY(${deltaY}px)`;
          // double rAF: a single frame can fire before the browser has
          // actually painted the inverted position, silently skipping the
          // transition in some browsers
          const outerId = requestAnimationFrame(() => {
            const innerId = requestAnimationFrame(() => {
              el.style.transition = 'transform 200ms ease';
              el.style.transform = '';
              rafIds.current.delete(key);
            });
            rafIds.current.set(key, innerId);
          });
          rafIds.current.set(key, outerId);
        }
      }
      cardRects.current.set(key, nextRect);
    });
  }, [exerciseKeyOrder]);

  useEffect(() => {
    const startedAtMs = new Date(workout.startedAt).getTime();
    const tick = () => setElapsedSec(Math.floor((Date.now() - startedAtMs) / 1000));
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [workout.startedAt]);

  const handleAddSet = async (workoutExerciseId: string, input: SetInput) => {
    // synchronous, still inside the click's call stack — unlocks playback
    // ahead of the async beep the timer fires later from a setInterval tick
    primeAudio();
    const ok = await onAddSet(workoutExerciseId, input);
    if (ok) restTimer.start();
  };

  // Free workouts (no templateId) and templated ones that never drifted
  // finish immediately, no dialog — only an actually-diverged templated
  // workout (exercise added/removed, reorder, or sets logged differing from
  // the routine's targetSets) surfaces the "update the routine too?" prompt
  const handleFinishClick = async () => {
    if (!workout.templateId) {
      onFinish(false);
      return;
    }
    setFinishStep('checking');
    const diverged = await onCheckTemplateDrift();
    if (diverged) {
      setFinishStep('confirm-sync');
    } else {
      setFinishStep('idle');
      onFinish(false);
    }
  };

  // mobile picker (RoutineExercisePicker) is built for multi-select
  // toggling, but removing an exercise here is a deliberately separate
  // action (the "✕" on each WorkoutExerciseCard row, see onRemoveExercise) —
  // toggling an already-added exercise off from within the picker itself
  // stays a no-op, so adding is the only thing this picker does
  const selectedExerciseIds = new Set(workout.exercises.map((we) => we.exerciseId));
  const handleToggleExercise = (exercise: ExerciseListItem) => {
    if (!selectedExerciseIds.has(exercise.id)) onAddExercise(exercise.id);
  };

  return (
    <div className="flex min-h-screen flex-col pb-[calc(90px+env(safe-area-inset-bottom))] md:pb-6">
      <div className="sticky top-0 z-10 border-b border-border bg-card px-5 py-4">
        <div className="flex items-center justify-between gap-3">
          <button
            type="button"
            onClick={onOpenDrawer}
            aria-label={t('session.openMenu')}
            className="flex h-9 w-9 flex-none cursor-pointer items-center justify-center rounded-[10px] text-foreground hover:bg-chip active:bg-chip md:hidden"
          >
            <Menu className="h-5 w-5" strokeWidth={1.8} />
          </button>
          <h1 className="flex-1 truncate text-[16px] font-semibold text-foreground">
            {workout.templateName ?? t('session.title')}
          </h1>
          <span className="text-[14px] font-semibold tabular-nums text-acc-tx">
            {formatElapsed(elapsedSec)}
          </span>
          <RestTimerControl timer={restTimer} />
          <button
            type="button"
            onClick={() => setConfirmingDiscard(true)}
            disabled={busy || finishStep !== 'idle'}
            aria-label={t('session.discardAria')}
            className="flex h-9 w-9 flex-none cursor-pointer items-center justify-center rounded-[10px] text-foreground hover:bg-chip active:bg-chip disabled:cursor-not-allowed disabled:opacity-50 md:hidden"
          >
            <X className="h-5 w-5" strokeWidth={1.8} />
          </button>
        </div>
        {error && <p className="mt-1 text-[12px] text-neg">{error}</p>}
      </div>

      <div className="flex-1 space-y-3 px-4 py-4">
        {workout.exercises.length === 0 && (
          <p className="py-10 text-center text-[13.5px] text-muted-foreground">
            {t('session.empty')}
          </p>
        )}

        {workout.exercises.map((we) => (
          <WorkoutExerciseCard
            key={we.id}
            workoutExercise={we}
            busy={busy}
            onAddSet={(input) => handleAddSet(we.id, input)}
            onUpdateSet={(setId, input) => onUpdateSet(we.id, setId, input)}
            onDeleteSet={(setId) => onDeleteSet(we.id, setId)}
            onRemove={() => onRemoveExercise(we.id)}
            dataKey={we.id}
            isDragging={dragKey === we.id}
            cardRef={(el) => {
              if (el) cardRefs.current.set(we.id, el);
              else cardRefs.current.delete(we.id);
            }}
            onDragHandlePointerDown={(e) => {
              e.preventDefault();
              e.stopPropagation();
              dragStartOrder.current = workout.exercises.map((we2) => we2.id);
              setDragKey(we.id);
            }}
          />
        ))}

        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className="min-h-[52px] w-full cursor-pointer rounded-[14px] border border-dashed border-border text-[14px] font-medium text-muted-foreground hover:border-acc hover:text-acc-tx"
        >
          {t('session.addExercise')}
        </button>
      </div>

      <div className="fixed inset-x-0 bottom-0 z-10 border-t border-border bg-card px-5 py-3 pb-[calc(12px+env(safe-area-inset-bottom))] md:static md:border-0 md:bg-transparent md:px-4">
        {finishStep === 'confirm-sync' ? (
          <div className="rounded-[14px] bg-chip px-4 py-3">
            <p className="text-[13px] text-foreground">{t('session.syncTemplatePrompt')}</p>
            <div className="mt-2.5 flex items-center gap-2">
              <button
                type="button"
                onClick={() => setFinishStep('idle')}
                className="cursor-pointer rounded-[8px] px-2.5 py-1.5 text-[12.5px] font-medium text-muted-foreground hover:text-foreground"
              >
                {t('session.syncTemplateBack')}
              </button>
              <button
                type="button"
                onClick={() => {
                  setFinishStep('idle');
                  onFinish(false);
                }}
                disabled={busy}
                className="flex-1 cursor-pointer rounded-[8px] border border-border px-2.5 py-1.5 text-[12.5px] font-medium text-foreground disabled:cursor-not-allowed disabled:opacity-50"
              >
                {t('session.syncTemplateKeep')}
              </button>
              <button
                type="button"
                onClick={() => {
                  setFinishStep('idle');
                  onFinish(true);
                }}
                disabled={busy}
                className="press flex-1 cursor-pointer rounded-[8px] bg-acc px-2.5 py-1.5 text-[12.5px] font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
              >
                {t('session.syncTemplateUpdate')}
              </button>
            </div>
          </div>
        ) : confirmingDiscard ? (
          <div className="flex items-center justify-between gap-3 rounded-[14px] bg-chip px-4 py-3">
            <span className="text-[13px] text-foreground">{t('session.discardConfirm')}</span>
            <div className="flex flex-none items-center gap-2">
              <button
                type="button"
                onClick={() => setConfirmingDiscard(false)}
                className="cursor-pointer rounded-[8px] px-2.5 py-1 text-[12.5px] font-medium text-muted-foreground hover:text-foreground"
              >
                {t('session.keepWorkout')}
              </button>
              <button
                type="button"
                onClick={onDiscard}
                disabled={busy}
                className="cursor-pointer rounded-[8px] bg-neg px-2.5 py-1 text-[12.5px] font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
              >
                {t('session.discard')}
              </button>
            </div>
          </div>
        ) : (
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handleFinishClick}
              disabled={busy || finishStep === 'checking'}
              className="press min-h-[56px] flex-[2] cursor-pointer rounded-[14px] bg-acc px-6 text-[16px] font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
            >
              {t('session.finish')}
            </button>
            <button
              type="button"
              onClick={() => setConfirmingDiscard(true)}
              disabled={busy || finishStep === 'checking'}
              className="min-h-[56px] flex-1 cursor-pointer rounded-[14px] bg-neg px-5 text-[14px] font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
            >
              {t('session.cancel')}
            </button>
          </div>
        )}
      </div>

      {pickerOpen && (
        <>
          {/* desktop keeps the plain single-pick ExercisePicker */}
          <div className="hidden md:block">
            <ExercisePicker
              onClose={() => setPickerOpen(false)}
              onPick={(exercise) => {
                onAddExercise(exercise.id);
                setPickerOpen(false);
              }}
            />
          </div>
          {/* mobile matches the routine builder's "add exercise" layout */}
          <div className="md:hidden">
            <RoutineExercisePicker
              selectedExerciseIds={selectedExerciseIds}
              totalSelectedCount={workout.exercises.length}
              onToggle={handleToggleExercise}
              onClose={() => setPickerOpen(false)}
            />
          </div>
        </>
      )}
    </div>
  );
}

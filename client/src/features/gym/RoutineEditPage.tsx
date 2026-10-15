import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, GripVertical, Plus, X } from 'lucide-react';
import type { ExerciseListItem, TemplateExerciseTargets } from '@/lib/types';
import { useRoutineEditor } from './useRoutineEditor';
import RoutineExerciseRow from './RoutineExerciseRow';
import ExercisePicker from './ExercisePicker';
import RoutineExercisePicker from './RoutineExercisePicker';
import RoutineExerciseEditPage from './RoutineExerciseEditPage';
import { formatRepsRange } from './routineFormat';

interface RoutineEditPageProps {
  templateId: string | null;
  onDone: () => void;
  onCancel: () => void;
}

// exercises added via the mobile picker start with this spec, editable later
// via RoutineExerciseEditPage (desktop's inline inputs, untouched, cover the
// equivalent for the desktop builder)
const DEFAULT_NEW_EXERCISE_TARGETS: TemplateExerciseTargets = {
  targetSets: 3,
  targetRepsMin: 10,
  targetRepsMax: 12,
};

export default function RoutineEditPage({ templateId, onDone, onCancel }: RoutineEditPageProps) {
  const { t } = useTranslation('gym');
  const editor = useRoutineEditor(templateId);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [mobilePickerOpen, setMobilePickerOpen] = useState(false);
  // gates the back button behind a confirmation when there are unsaved
  // changes (see useRoutineEditor's isDirty) — same "requestClose" pattern
  // as the lap editor's confirmingClose
  const [confirmingBack, setConfirmingBack] = useState(false);
  const requestBack = () => {
    if (editor.isDirty) {
      setConfirmingBack(true);
      return;
    }
    onCancel();
  };
  // mobile builder only — tapping an already-added exercise card opens
  // RoutineExerciseEditPage for it (sets/reps range), see the card's onClick
  // below; desktop's inline inputs (RoutineExerciseRow.tsx) are untouched
  const [editingExerciseKey, setEditingExerciseKey] = useState<string | null>(null);

  // Mobile builder drag-to-reorder — same Pointer Events pattern as the lap
  // editor's drag handle (LapEditorPanel.tsx): works for both mouse and
  // touch without duplicating code, reorders live as the pointer crosses
  // into another row (via elementFromPoint + data-exercise-key), and
  // persists once on drop rather than per crossing.
  const [dragKey, setDragKey] = useState<string | null>(null);

  useEffect(() => {
    if (!dragKey) return;
    const onMove = (e: PointerEvent) => {
      const el = document
        .elementFromPoint(e.clientX, e.clientY)
        ?.closest<HTMLElement>('[data-exercise-key]');
      const overKey = el?.dataset.exerciseKey;
      if (overKey && overKey !== dragKey) {
        editor.reorderExercise(dragKey, overKey);
      }
    };
    const onUp = () => setDragKey(null);
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

  // FLIP (First-Last-Invert-Play) animation for the reordering above — no
  // animation lib in this project (see index.css's drawer-in for the same
  // "plain CSS transition, no dependency" convention), so this measures each
  // row before/after a reorder and animates the delta instead of letting
  // React's keyed re-render just snap rows to their new spot. rafIds guards
  // against a stale rAF (from an interrupted animation) clobbering a newer
  // one — reorderExercise can fire many times a second while dragging.
  const rowRefs = useRef(new Map<string, HTMLDivElement>());
  const rowRects = useRef(new Map<string, DOMRect>());
  const rafIds = useRef(new Map<string, number>());
  const exerciseKeyOrder = editor.exercises.map((e) => e.key).join(',');

  useLayoutEffect(() => {
    const reduceMotion = window.matchMedia(
      '(prefers-reduced-motion: reduce)',
    ).matches;

    rowRefs.current.forEach((el, key) => {
      const prevRect = rowRects.current.get(key);
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
          // transition in some browsers — two frames guarantees a paint
          // happens between "invert" and "play"
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
      rowRects.current.set(key, nextRect);
    });
  }, [exerciseKeyOrder]);

  const selectedExerciseIds = useMemo(
    () => new Set(editor.exercises.map((e) => e.exerciseId)),
    [editor.exercises],
  );
  const editingExercise = editor.exercises.find((e) => e.key === editingExerciseKey) ?? null;

  if (editor.loading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center text-[13px] text-muted-foreground">
        {t('loading')}
      </div>
    );
  }

  const handleSave = async () => {
    const saved = await editor.save();
    if (saved) onDone();
  };

  // toggling commits immediately — add if not already in the routine,
  // remove if it already is (matched by exerciseId, not the working key)
  const handleToggleExercise = (ex: ExerciseListItem) => {
    const existing = editor.exercises.find((e) => e.exerciseId === ex.id);
    if (existing) {
      editor.removeExercise(existing.key);
    } else {
      editor.addExercise(ex.id, ex.name, DEFAULT_NEW_EXERCISE_TARGETS);
    }
  };

  return (
    <>
      {/* desktop — unchanged from before this pass */}
      <div className="hidden min-h-screen flex-col pb-[calc(90px+env(safe-area-inset-bottom))] md:flex md:pb-6">
        <div className="sticky top-0 z-10 flex items-center gap-3 border-b border-border bg-card px-5 py-4">
          <button
            type="button"
            onClick={requestBack}
            aria-label={t('routines.back')}
            className="cursor-pointer text-muted-foreground hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4" strokeWidth={1.8} />
          </button>
          <h1 className="flex-1 text-[16px] font-semibold text-foreground">
            {editor.isEdit ? t('editor.editTitle') : t('editor.newTitle')}
          </h1>
        </div>

        {confirmingBack && (
          <div className="flex items-center justify-between gap-3 border-b border-border bg-chip px-5 py-3">
            <span className="text-[13px] text-foreground">{t('editor.discardConfirm')}</span>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setConfirmingBack(false)}
                className="cursor-pointer rounded-[8px] px-2.5 py-1 text-[12.5px] font-medium text-muted-foreground hover:text-foreground"
              >
                {t('editor.keepEditing')}
              </button>
              <button
                type="button"
                onClick={onCancel}
                className="cursor-pointer rounded-[8px] bg-neg px-2.5 py-1 text-[12.5px] font-medium text-white"
              >
                {t('editor.discard')}
              </button>
            </div>
          </div>
        )}

        <div className="flex-1 space-y-4 px-4 py-4">
          {editor.error && <p className="text-[12px] text-neg">{editor.error}</p>}

          <label className="block">
            <span className="mb-1 block text-[11px] font-medium text-muted-foreground">
              {t('editor.nameLabel')}
            </span>
            <input
              value={editor.name}
              onChange={(e) => editor.setName(e.target.value)}
              placeholder={t('editor.namePlaceholder')}
              className="h-11 w-full rounded-[10px] border border-border bg-page-bg px-3 text-[14px] text-foreground outline-none focus:border-acc"
            />
          </label>

          <label className="block">
            <span className="mb-1 block text-[11px] font-medium text-muted-foreground">
              {t('editor.descriptionLabel')}
            </span>
            <textarea
              value={editor.description}
              onChange={(e) => editor.setDescription(e.target.value)}
              rows={2}
              placeholder={t('editor.descriptionPlaceholder')}
              className="w-full resize-none rounded-[10px] border border-border bg-page-bg px-3 py-2 text-[13.5px] text-foreground outline-none focus:border-acc"
            />
          </label>

          {editor.exercises.length > 0 && (
            <div className="space-y-2.5">
              {editor.exercises.map((ex, idx) => (
                <RoutineExerciseRow
                  key={ex.key}
                  exercise={ex}
                  isFirst={idx === 0}
                  isLast={idx === editor.exercises.length - 1}
                  onMoveUp={() => editor.move(ex.key, -1)}
                  onMoveDown={() => editor.move(ex.key, 1)}
                  onRemove={() => editor.removeExercise(ex.key)}
                  onTargetsChange={(targets) => editor.updateTargets(ex.key, targets)}
                />
              ))}
            </div>
          )}

          <button
            type="button"
            onClick={() => setPickerOpen(true)}
            className="min-h-[52px] w-full cursor-pointer rounded-[14px] border border-dashed border-border text-[14px] font-medium text-muted-foreground hover:border-acc hover:text-acc-tx"
          >
            {t('session.addExercise')}
          </button>
        </div>

        <div className="fixed inset-x-0 bottom-0 z-10 border-t border-border bg-card px-5 py-3 pb-[calc(12px+env(safe-area-inset-bottom))] md:static md:border-0 md:bg-transparent md:px-4">
          <button
            type="button"
            onClick={handleSave}
            disabled={editor.saving || editor.name.trim().length === 0}
            className="press min-h-[52px] w-full cursor-pointer rounded-[14px] bg-acc px-6 text-[15px] font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
          >
            {editor.saving
              ? t('editor.saving')
              : editor.isEdit
                ? t('editor.save')
                : t('editor.create')}
          </button>
        </div>

        {pickerOpen && (
          <ExercisePicker
            onClose={() => setPickerOpen(false)}
            onPick={(exercise) => {
              editor.addExercise(exercise.id, exercise.name);
              setPickerOpen(false);
            }}
          />
        )}
      </div>

      {/* mobile — new builder, opção 12c */}
      <div className="flex min-h-screen flex-col md:hidden">
        <div className="sticky top-0 z-10 flex items-center gap-3 border-b border-border bg-card px-5 py-4">
          <button
            type="button"
            onClick={requestBack}
            aria-label={t('routines.back')}
            className="cursor-pointer text-muted-foreground hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4" strokeWidth={1.8} />
          </button>
          <h1 className="flex-1 text-[16px] font-semibold text-foreground">
            {editor.isEdit ? t('editor.editTitle') : t('editor.newTitle')}
          </h1>
          <button
            type="button"
            onClick={handleSave}
            disabled={editor.saving || editor.name.trim().length === 0}
            className="cursor-pointer text-[14px] font-semibold text-acc-tx disabled:cursor-not-allowed disabled:opacity-40"
          >
            {editor.saving ? t('editor.saving') : t('editor.saveShort')}
          </button>
        </div>

        {confirmingBack && (
          <div className="flex items-center justify-between gap-3 border-b border-border bg-chip px-5 py-3">
            <span className="text-[13px] text-foreground">{t('editor.discardConfirm')}</span>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setConfirmingBack(false)}
                className="cursor-pointer rounded-[8px] px-2.5 py-1 text-[12.5px] font-medium text-muted-foreground hover:text-foreground"
              >
                {t('editor.keepEditing')}
              </button>
              <button
                type="button"
                onClick={onCancel}
                className="cursor-pointer rounded-[8px] bg-neg px-2.5 py-1 text-[12.5px] font-medium text-white"
              >
                {t('editor.discard')}
              </button>
            </div>
          </div>
        )}

        <div className="flex-1 px-5 pt-[18px] pb-[32px]">
          {editor.error && <p className="mb-3 text-[12px] text-neg">{editor.error}</p>}

          <label className="block">
            <span className="mb-1 block text-[11px] font-medium tracking-[.05em] text-muted-foreground uppercase">
              {t('editor.nameLabelMobile')}
            </span>
            <input
              value={editor.name}
              onChange={(e) => editor.setName(e.target.value)}
              placeholder={t('editor.namePlaceholder')}
              className="w-full rounded-[10px] border border-border bg-card p-[12px_14px] text-[16px] font-semibold text-foreground outline-none focus:border-acc"
            />
          </label>

          <div className="mt-6 flex items-center justify-between">
            <span className="text-[11px] font-medium tracking-[.05em] text-muted-foreground uppercase">
              {t('editor.exercisesHeader')}
            </span>
            <span className="text-[11px] text-muted-foreground">
              {t('editor.exercisesAddedCount', { count: editor.exercises.length })}
            </span>
          </div>

          {editor.exercises.map((ex) => (
            <div
              key={ex.key}
              data-exercise-key={ex.key}
              ref={(el) => {
                if (el) rowRefs.current.set(ex.key, el);
                else rowRefs.current.delete(ex.key);
              }}
              onClick={() => setEditingExerciseKey(ex.key)}
              className={`mt-[10px] flex cursor-pointer items-center gap-3 rounded-[12px] border border-border bg-card p-[12px] ${
                dragKey === ex.key ? 'opacity-40' : ''
              }`}
            >
              <button
                type="button"
                onPointerDown={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  setDragKey(ex.key);
                }}
                aria-label={t('editor.reorderExercise')}
                className="flex-none cursor-grab touch-none p-1 text-muted-foreground active:cursor-grabbing"
              >
                <GripVertical className="h-4 w-4" strokeWidth={1.8} />
              </button>
              <div className="min-w-0 flex-1">
                <div className="truncate text-[14px] font-semibold text-foreground">
                  {ex.exerciseName}
                </div>
                <div className="mt-0.5 text-[11.5px] text-muted-foreground">
                  {t('editor.mobileSpec', {
                    sets: ex.targetSets ?? '—',
                    reps: formatRepsRange(ex.targetRepsMin, ex.targetRepsMax),
                  })}
                </div>
              </div>
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation();
                  editor.removeExercise(ex.key);
                }}
                aria-label={t('editor.removeExercise')}
                className="flex h-[28px] w-[28px] flex-none cursor-pointer items-center justify-center rounded-[8px] bg-chip text-muted-foreground hover:text-neg"
              >
                <X className="h-3.5 w-3.5" strokeWidth={1.8} />
              </button>
            </div>
          ))}

          <button
            type="button"
            onClick={() => setMobilePickerOpen(true)}
            className="mt-[10px] flex w-full cursor-pointer items-center justify-center gap-2 rounded-[12px] border border-dashed border-border p-[14px] text-[14px] font-semibold text-acc-tx hover:border-acc"
          >
            <Plus className="h-4 w-4" strokeWidth={2} />
            {t('editor.addExercise')}
          </button>
        </div>

        {mobilePickerOpen && (
          <RoutineExercisePicker
            selectedExerciseIds={selectedExerciseIds}
            totalSelectedCount={editor.exercises.length}
            onToggle={handleToggleExercise}
            onClose={() => setMobilePickerOpen(false)}
          />
        )}

        {editingExercise && (
          <RoutineExerciseEditPage
            exercise={editingExercise}
            onBack={() => setEditingExerciseKey(null)}
            onChange={(targets) => editor.updateTargets(editingExercise.key, targets)}
          />
        )}
      </div>
    </>
  );
}

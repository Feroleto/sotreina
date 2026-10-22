import { useCallback, useEffect, useRef, useState } from 'react';
import { apiFetch } from '@/lib/api';
import type { TemplateDetail, TemplateExerciseTargets } from '@/lib/types';

export interface WorkingExercise extends TemplateExerciseTargets {
  // server templateExerciseId for rows loaded from an existing template, a
  // local-only key for rows added during this editing session — either way
  // it's only ever used as a React/drag key, never sent back to the server
  // (see save() below, which always POSTs/PATCHes the exerciseId list)
  key: string;
  exerciseId: string;
  exerciseName: string;
}

let localKeySeq = 0;
function nextLocalKey(): string {
  localKeySeq += 1;
  return `local-${localKeySeq}`;
}

// Moves `key` to sit where `beforeKey` currently is — same shape as the lap
// editor's reorderLaps (lapBoundaryMath.ts), called continuously while
// dragging (once per row boundary crossed), not just on drop.
export function reorderWorkingExercises(
  exercises: WorkingExercise[],
  key: string,
  beforeKey: string,
): WorkingExercise[] {
  if (key === beforeKey) return exercises;
  const fromIndex = exercises.findIndex((e) => e.key === key);
  const targetIndex = exercises.findIndex((e) => e.key === beforeKey);
  if (fromIndex === -1 || targetIndex === -1) return exercises;

  const next = exercises.slice();
  const [item] = next.splice(fromIndex, 1);
  const insertAt = next.findIndex((e) => e.key === beforeKey);
  next.splice(insertAt, 0, item!);
  return next;
}

function toWorking(template: TemplateDetail): WorkingExercise[] {
  return template.exercises
    .slice()
    .sort((a, b) => a.order - b.order)
    .map((e) => ({
      key: e.id,
      exerciseId: e.exerciseId,
      exerciseName: e.exerciseName,
      targetSets: e.targetSets,
      targetRepsMin: e.targetRepsMin,
      targetRepsMax: e.targetRepsMax,
      restSeconds: e.restSeconds,
    }));
}

// signature used for dirty-checking the exercise list against what was
// loaded — order matters (a pure reorder is still a change), row identity
// (key) doesn't
function exercisesSignature(exercises: WorkingExercise[]): string {
  return JSON.stringify(
    exercises.map((e) => ({
      exerciseId: e.exerciseId,
      targetSets: e.targetSets ?? null,
      targetRepsMin: e.targetRepsMin ?? null,
      targetRepsMax: e.targetRepsMax ?? null,
      restSeconds: e.restSeconds ?? null,
    })),
  );
}

// Both modes now build the routine entirely in memory and flush once on
// save() — create mode POSTs the whole thing, edit mode PATCHes the whole
// thing (name/description + a wholesale exercises replace, see
// WorkoutTemplatesService.update). No more per-action network calls, so
// closing without saving truly discards everything (see RoutineEditPage's
// requestBack/isDirty), matching what commit-as-you-go could never give you.
export function useRoutineEditor(templateId: string | null) {
  const isEdit = templateId !== null;
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [exercises, setExercises] = useState<WorkingExercise[]>([]);
  // baseline for dirty-checking against — starts empty for create mode
  // (nothing loaded yet) and is stamped once the template loads for edit mode
  const initialMeta = useRef({ name: '', description: '', exercisesSignature: '[]' });
  const [loading, setLoading] = useState(isEdit);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!isEdit) return;
    let cancelled = false;
    apiFetch(`/workout-templates/${templateId}`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json() as Promise<TemplateDetail>;
      })
      .then((t) => {
        if (cancelled) return;
        const working = toWorking(t);
        setName(t.name);
        setDescription(t.description ?? '');
        setExercises(working);
        initialMeta.current = {
          name: t.name,
          description: t.description ?? '',
          exercisesSignature: exercisesSignature(working),
        };
      })
      .catch((e) => {
        if (!cancelled) setError(String(e));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [isEdit, templateId]);

  const addExercise = useCallback(
    // targets is optional and additive — omitted by desktop's ExercisePicker
    // flow, used by the mobile multi-select picker to seed the "3 séries x
    // 12 reps" default on add
    (exerciseId: string, exerciseName: string, targets?: TemplateExerciseTargets) => {
      setExercises((prev) => [
        ...prev,
        { key: nextLocalKey(), exerciseId, exerciseName, ...targets },
      ]);
    },
    [],
  );

  const updateTargets = useCallback((key: string, targets: TemplateExerciseTargets) => {
    setExercises((prev) => prev.map((e) => (e.key === key ? { ...e, ...targets } : e)));
  }, []);

  const removeExercise = useCallback((key: string) => {
    setExercises((prev) => prev.filter((e) => e.key !== key));
  }, []);

  const move = useCallback((key: string, direction: -1 | 1) => {
    setExercises((prev) => {
      const idx = prev.findIndex((e) => e.key === key);
      const swapIdx = idx + direction;
      if (idx === -1 || swapIdx < 0 || swapIdx >= prev.length) return prev;
      const next = prev.slice();
      [next[idx], next[swapIdx]] = [next[swapIdx]!, next[idx]!];
      return next;
    });
  }, []);

  // Local-only reorder, called live while dragging (mobile builder's grip
  // handle) — no network call per crossing, same reasoning as the lap
  // editor's reorderLap: a PATCH per pixel of drag would spam the API.
  // Nothing needs to persist on drop anymore either, since everything flushes
  // together in save() — see RoutineEditPage's pointerup handler.
  const reorderExercise = useCallback((key: string, beforeKey: string) => {
    setExercises((prev) => reorderWorkingExercises(prev, key, beforeKey));
  }, []);

  const save = useCallback(async (): Promise<TemplateDetail | null> => {
    setSaving(true);
    setError(null);
    try {
      const res = await apiFetch(isEdit ? `/workout-templates/${templateId}` : '/workout-templates', {
        method: isEdit ? 'PATCH' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name,
          description: description || null,
          exercises: exercises.map((e) => ({
            exerciseId: e.exerciseId,
            targetSets: e.targetSets,
            targetRepsMin: e.targetRepsMin,
            targetRepsMax: e.targetRepsMax,
            restSeconds: e.restSeconds,
          })),
        }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return (await res.json()) as TemplateDetail;
    } catch (e) {
      setError(String(e));
      return null;
    } finally {
      setSaving(false);
    }
  }, [isEdit, templateId, name, description, exercises]);

  // create mode: anything typed/added is unsaved until save(). edit mode:
  // the whole routine only exists in memory until save() too now, so this
  // compares against the snapshot captured when the template loaded
  const isDirty = isEdit
    ? name !== initialMeta.current.name ||
      description !== initialMeta.current.description ||
      exercisesSignature(exercises) !== initialMeta.current.exercisesSignature
    : name.trim().length > 0 || description.trim().length > 0 || exercises.length > 0;

  return {
    isEdit,
    isDirty,
    name,
    setName,
    description,
    setDescription,
    exercises,
    loading,
    saving,
    error,
    addExercise,
    updateTargets,
    removeExercise,
    move,
    reorderExercise,
    save,
  };
}

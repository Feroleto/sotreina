import { useCallback, useEffect, useRef, useState } from 'react';
import { apiFetch } from '@/lib/api';
import type { FinishedWorkout, SetInput, WorkoutDetail } from '@/lib/types';

// mirrors the /auth/me empty-200 contract (lib/boot.ts): an empty body means
// "no active workout", not an error
async function parseJsonOrNull<T>(res: Response): Promise<T | null> {
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const text = await res.text();
  return text ? (JSON.parse(text) as T) : null;
}

// every mutating endpoint in the workouts API returns the full updated
// WorkoutDetail, so the hook never needs a separate refetch after a mutation.
// Lives at the App.tsx level (not just inside GymWorkoutsPage) so the active
// workout survives navigating away from Academia and can drive the global
// floating mini-bar — `enabled` gates the initial fetch on auth being
// resolved, mirroring lib/boot.ts's has-activities hint, so a logged-out
// visitor doesn't fire a 401 against /workouts/active
export function useActiveWorkout(enabled: boolean) {
  const [workout, setWorkout] = useState<WorkoutDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  // the workout that was just finished, with its summary — drives the
  // post-workout screen (WorkoutSummaryPage) until the user dismisses it.
  // Lives here, next to `workout`, so it survives navigating away and back
  const [lastFinished, setLastFinished] = useState<FinishedWorkout | null>(null);
  // mirrors useRoutineEditor's exercisesRef — commitReorderExercises is
  // invoked from WorkoutSession's pointerup handler, bound once per drag
  // gesture, and would otherwise close over the pre-drag workout state
  const workoutRef = useRef(workout);
  useEffect(() => {
    workoutRef.current = workout;
  }, [workout]);

  useEffect(() => {
    if (!enabled) return;
    let cancelled = false;
    apiFetch('/workouts/active')
      .then((res) => parseJsonOrNull<WorkoutDetail>(res))
      .then((w) => {
        if (!cancelled) setWorkout(w);
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
  }, [enabled]);

  // returns whether the mutation actually succeeded — the rest timer (fase 3)
  // needs this to only start counting down after a set is confirmed logged,
  // not on every click regardless of outcome
  const run = useCallback(async (fn: () => Promise<Response>): Promise<boolean> => {
    setBusy(true);
    setError(null);
    try {
      const res = await fn();
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setWorkout(await res.json());
      return true;
    } catch (e) {
      setError(String(e));
      return false;
    } finally {
      setBusy(false);
    }
  }, []);

  const start = useCallback(
    (templateId?: string) =>
      run(() =>
        apiFetch('/workouts', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(templateId ? { templateId } : {}),
        }),
      ),
    [run],
  );

  const addExercise = useCallback(
    (exerciseId: string) => {
      if (!workout) return Promise.resolve(false);
      return run(() =>
        apiFetch(`/workouts/${workout.id}/exercises`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ exerciseId }),
        }),
      );
    },
    [run, workout],
  );

  const removeExercise = useCallback(
    (workoutExerciseId: string) => {
      if (!workout) return Promise.resolve(false);
      return run(() =>
        apiFetch(`/workouts/${workout.id}/exercises/${workoutExerciseId}`, {
          method: 'DELETE',
        }),
      );
    },
    [run, workout],
  );

  // Local-only reorder, called live while dragging (WorkoutSession's grip
  // handle) — same shape as useRoutineEditor.reorderExercise, no network call
  // per crossing. Persisted once, on drop, via commitReorderExercises below.
  const reorderExercise = useCallback((id: string, beforeId: string) => {
    setWorkout((prev) => {
      if (!prev || id === beforeId) return prev;
      const fromIndex = prev.exercises.findIndex((e) => e.id === id);
      const targetIndex = prev.exercises.findIndex((e) => e.id === beforeId);
      if (fromIndex === -1 || targetIndex === -1) return prev;

      const next = prev.exercises.slice();
      const [item] = next.splice(fromIndex, 1);
      const insertAt = next.findIndex((e) => e.id === beforeId);
      next.splice(insertAt, 0, item!);
      return { ...prev, exercises: next };
    });
  }, []);

  // Called once when the drag ends (pointerup), with the id order captured
  // at drag start — diffs against that pre-drag snapshot and PATCHes one
  // row per moved index; no bulk reorder endpoint exists here (unlike
  // useRoutineEditor, this is a live session — each action still commits
  // immediately, there's no "save" step to batch into)
  const commitReorderExercises = useCallback(async (originalIds: string[]) => {
    const current = workoutRef.current;
    if (!current) return;
    const changedIndexes = current.exercises
      .map((e, idx) => (originalIds[idx] !== e.id ? idx : -1))
      .filter((idx) => idx !== -1);
    if (changedIndexes.length === 0) return;

    setBusy(true);
    setError(null);
    try {
      let lastBody: WorkoutDetail | null = null;
      for (const idx of changedIndexes) {
        const res = await apiFetch(
          `/workouts/${current.id}/exercises/${current.exercises[idx]!.id}`,
          {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ order: idx + 1 }),
          },
        );
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        lastBody = await res.json();
      }
      if (lastBody) setWorkout(lastBody);
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }, []);

  const addSet = useCallback(
    (workoutExerciseId: string, input: SetInput) => {
      if (!workout) return Promise.resolve(false);
      return run(() =>
        apiFetch(`/workouts/${workout.id}/exercises/${workoutExerciseId}/sets`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(input),
        }),
      );
    },
    [run, workout],
  );

  const updateSet = useCallback(
    (workoutExerciseId: string, setId: string, input: SetInput) => {
      if (!workout) return Promise.resolve(false);
      return run(() =>
        apiFetch(`/workouts/${workout.id}/exercises/${workoutExerciseId}/sets/${setId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(input),
        }),
      );
    },
    [run, workout],
  );

  const deleteSet = useCallback(
    (workoutExerciseId: string, setId: string) => {
      if (!workout) return Promise.resolve(false);
      return run(() =>
        apiFetch(`/workouts/${workout.id}/exercises/${workoutExerciseId}/sets/${setId}`, {
          method: 'DELETE',
        }),
      );
    },
    [run, workout],
  );

  // read-only check, called by WorkoutSession right before finishing — true
  // when the session (exercises added/removed, sets logged vs. targetSets,
  // reorder) has drifted from the template it started from, which is what
  // gates the "update the routine too?" prompt. Always false for a free
  // workout (no templateId) — nothing to compare against.
  const checkTemplateDrift = useCallback(async (): Promise<boolean> => {
    if (!workout) return false;
    try {
      const res = await apiFetch(`/workouts/${workout.id}/template-drift`);
      if (!res.ok) return false;
      const body = (await res.json()) as { diverged: boolean };
      return body.diverged;
    } catch {
      return false;
    }
  }, [workout]);

  // syncTemplate mirrors the "update the routine too?" prompt's answer —
  // true replaces the originating WorkoutTemplate's exercises (order + sets
  // performed) server-side before marking the workout finished; false (the
  // default) leaves the template untouched regardless of what changed here
  const finish = useCallback(
    async (syncTemplate = false) => {
      if (!workout) return;
      setBusy(true);
      setError(null);
      try {
        const res = await apiFetch(`/workouts/${workout.id}/finish`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ syncTemplate }),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const finished = (await res.json()) as Partial<FinishedWorkout>;
        // a backend older than the summary (deploy order) just skips the
        // post-workout screen — straight back to the routines, as before
        if (finished.summary) setLastFinished(finished as FinishedWorkout);
        setWorkout(null);
      } catch (e) {
        setError(String(e));
      } finally {
        setBusy(false);
      }
    },
    [workout],
  );

  const dismissSummary = useCallback(() => setLastFinished(null), []);

  // deletes the workout outright (not a finish) — every logged set is gone,
  // not just marked done
  const discard = useCallback(async () => {
    if (!workout) return;
    setBusy(true);
    setError(null);
    try {
      const res = await apiFetch(`/workouts/${workout.id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setWorkout(null);
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  }, [workout]);

  return {
    workout,
    loading,
    error,
    busy,
    start,
    addExercise,
    removeExercise,
    reorderExercise,
    commitReorderExercises,
    addSet,
    updateSet,
    deleteSet,
    checkTemplateDrift,
    finish,
    discard,
    lastFinished,
    dismissSummary,
  };
}

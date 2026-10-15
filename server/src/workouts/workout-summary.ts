// Pure helpers behind PATCH /workouts/:id/finish's `summary` — kept out of
// WorkoutsService so the PR rule can be tested without a Prisma mock.

export interface SetLike {
  weightKg: number | null;
  reps: number | null;
}

export interface WorkoutPersonalRecord {
  exerciseId: string;
  exerciseName: string;
  /** this workout's best set for the exercise */
  weightKg: number;
  reps: number | null;
  /** the record it beat — always present: a first-ever session isn't a PR */
  previousWeightKg: number;
  previousReps: number | null;
}

export interface WorkoutFinishSummary {
  durationSec: number;
  /** sum of weightKg × reps, same formula as historyStats */
  volumeKg: number;
  setCount: number;
  exerciseCount: number;
  personalRecords: WorkoutPersonalRecord[];
}

/**
 * Heaviest set, ties broken by more reps — the same ordering as
 * ExercisesService.personalRecord (weightKg desc, reps desc). Sets without a
 * weight never count (bodyweight-only work has no load record).
 */
export function bestSet<T extends SetLike>(sets: T[]): (T & { weightKg: number }) | null {
  let best: (T & { weightKg: number }) | null = null;
  for (const s of sets) {
    if (s.weightKg == null) continue;
    if (
      !best ||
      s.weightKg > best.weightKg ||
      (s.weightKg === best.weightKg && (s.reps ?? 0) > (best.reps ?? 0))
    ) {
      best = s as T & { weightKg: number };
    }
  }
  return best;
}

/** strictly better than the previous record, under that same ordering */
export function beatsRecord(
  candidate: { weightKg: number; reps: number | null },
  previous: { weightKg: number; reps: number | null },
): boolean {
  if (candidate.weightKg !== previous.weightKg) {
    return candidate.weightKg > previous.weightKg;
  }
  return (candidate.reps ?? 0) > (previous.reps ?? 0);
}

export function summarizeWorkout(
  workout: {
    startedAt: Date;
    exercises: { sets: SetLike[] }[];
  },
  finishedAt: Date,
  personalRecords: WorkoutPersonalRecord[],
): WorkoutFinishSummary {
  let volumeKg = 0;
  let setCount = 0;
  for (const ex of workout.exercises) {
    for (const s of ex.sets) {
      volumeKg += (s.weightKg ?? 0) * (s.reps ?? 0);
      setCount++;
    }
  }
  return {
    durationSec: Math.max(
      0,
      Math.round((finishedAt.getTime() - workout.startedAt.getTime()) / 1000),
    ),
    volumeKg,
    setCount,
    exerciseCount: workout.exercises.length,
    personalRecords,
  };
}

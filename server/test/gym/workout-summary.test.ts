import { describe, it, expect } from 'vitest';
import { beatsRecord, bestSet, summarizeWorkout } from 'src/workouts/workout-summary';

describe('bestSet', () => {
  it('picks the heaviest set, breaking weight ties by reps', () => {
    expect(
      bestSet([
        { weightKg: 80, reps: 8 },
        { weightKg: 85, reps: 3 },
        { weightKg: 85, reps: 5 },
      ]),
    ).toEqual({ weightKg: 85, reps: 5 });
  });

  it('ignores sets without a weight (bodyweight work has no load record)', () => {
    expect(bestSet([{ weightKg: null, reps: 12 }])).toBeNull();
    expect(bestSet([])).toBeNull();
  });
});

describe('beatsRecord', () => {
  it('is a PR when heavier, or same weight for more reps', () => {
    expect(beatsRecord({ weightKg: 85, reps: 1 }, { weightKg: 82.5, reps: 10 })).toBe(true);
    expect(beatsRecord({ weightKg: 85, reps: 6 }, { weightKg: 85, reps: 5 })).toBe(true);
  });

  it('is not a PR when it only ties or falls short', () => {
    expect(beatsRecord({ weightKg: 85, reps: 5 }, { weightKg: 85, reps: 5 })).toBe(false);
    expect(beatsRecord({ weightKg: 80, reps: 20 }, { weightKg: 85, reps: 1 })).toBe(false);
  });
});

describe('summarizeWorkout', () => {
  it('sums volume (weight × reps) and counts sets/exercises', () => {
    const summary = summarizeWorkout(
      {
        startedAt: new Date('2026-07-20T10:00:00Z'),
        exercises: [
          { sets: [{ weightKg: 50, reps: 10 }, { weightKg: null, reps: 8 }] },
          { sets: [] },
        ],
      },
      new Date('2026-07-20T10:45:30Z'),
      [],
    );
    expect(summary).toEqual({
      durationSec: 45 * 60 + 30,
      volumeKg: 500,
      setCount: 2,
      exerciseCount: 2,
      personalRecords: [],
    });
  });
});

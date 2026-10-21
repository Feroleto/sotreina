import { describe, it, expect } from 'vitest';
import {
  buildDays,
  buildFeed,
  buildTotals,
  calendarDaysAgo,
  isDietDone,
  lastNDays,
} from './todayStatus';
import { toISODate } from '@/features/dashboard/bins';
import type {
  Activity,
  FoodLogItem,
  Meal,
  WorkoutHistoryItem,
} from '@/lib/types';

// Wednesday 2026-10-21, 15:00 local — the week starts Monday the 19th
const NOW = new Date(2026, 9, 21, 15, 0, 0);

function local(day: number, hour = 9, month = 9): string {
  return new Date(2026, month, day, hour, 0, 0).toISOString();
}

function run(startDate: string, distanceKm: number): Activity {
  return {
    id: startDate,
    name: 'Run',
    workoutType: 'EASY_OR_LONG',
    startDate,
    distanceKm,
    movingTimeSec: 1800,
    paceRawSecKm: null,
    elevationGainM: null,
    averageBpm: null,
    maxBpm: null,
    averageCadence: null,
  };
}

function workout(
  startedAt: string,
  templateName: string | null = null,
): WorkoutHistoryItem {
  return {
    id: startedAt,
    startedAt,
    finishedAt: startedAt,
    durationSec: 3600,
    exerciseCount: 6,
    volumeKg: 5000,
    templateId: null,
    templateName,
  };
}

function log(
  mealId: string,
  loggedAt: string,
  kcalPer100: number,
  quantity: number,
): FoodLogItem {
  return {
    id: `${mealId}-${loggedAt}-${quantity}`,
    quantity,
    enteredAsServing: false,
    mealId,
    loggedAt,
    food: { kcal: kcalPer100 } as FoodLogItem['food'],
  };
}

describe('isDietDone', () => {
  it('counts the day once it reaches 90% of the goal', () => {
    expect(isDietDone(1800, 2000)).toBe(true);
    expect(isDietDone(1799, 2000)).toBe(false);
    expect(isDietDone(2600, 2000)).toBe(true);
  });

  it('never counts with a zero goal', () => {
    expect(isDietDone(500, 0)).toBe(false);
  });
});

describe('lastNDays', () => {
  it('returns local midnights, oldest first, ending today', () => {
    const days = lastNDays(NOW, 7);
    expect(days).toHaveLength(7);
    expect(toISODate(days[0])).toBe('2026-10-15');
    expect(toISODate(days[6])).toBe('2026-10-21');
    expect(days.every((d) => d.getHours() === 0)).toBe(true);
  });
});

describe('buildDays', () => {
  it('marks each area per local day', () => {
    const days = buildDays({
      activities: [run(local(21, 7), 7.1), run(local(17), 10)],
      workouts: [workout(local(20, 19))],
      dietPoints: [
        {
          date: '2026-10-21',
          totalKcal: 1900,
          totalProtein: 0,
          totalCarbs: 0,
          totalFat: 0,
        },
        {
          date: '2026-10-20',
          totalKcal: 1000,
          totalProtein: 0,
          totalCarbs: 0,
          totalFat: 0,
        },
      ],
      kcalGoal: 2000,
      now: NOW,
    });
    const byDate = Object.fromEntries(days.map((d) => [d.date, d]));
    expect(byDate['2026-10-21']).toEqual({
      date: '2026-10-21',
      run: true,
      gym: false,
      diet: true,
    });
    expect(byDate['2026-10-20']).toEqual({
      date: '2026-10-20',
      run: false,
      gym: true,
      diet: false,
    });
    expect(byDate['2026-10-17'].run).toBe(true);
  });

  it('buckets a late-evening run into its local day, not the UTC one', () => {
    const days = buildDays({
      activities: [run(local(20, 23), 5)],
      workouts: [],
      dietPoints: [],
      kcalGoal: 2000,
      now: NOW,
    });
    expect(days.find((d) => d.date === '2026-10-20')!.run).toBe(true);
    expect(days.find((d) => d.date === '2026-10-21')!.run).toBe(false);
  });
});

describe('buildTotals', () => {
  it('sums today and the Monday-start week separately', () => {
    const totals = buildTotals({
      activities: [
        run(local(21, 7), 7.1),
        run(local(19), 10),
        // Sunday the 18th belongs to last week
        run(local(18), 20),
      ],
      workouts: [
        workout(local(21, 6), 'Treino A'),
        workout(local(20)),
        workout(local(18)),
      ],
      now: NOW,
    });
    expect(totals.runKmToday).toBeCloseTo(7.1);
    expect(totals.runKmWeek).toBeCloseTo(17.1);
    expect(totals.workoutsToday.map((w) => w.templateName)).toEqual([
      'Treino A',
    ]);
    expect(totals.workoutsWeek).toBe(2);
  });
});

describe('buildFeed', () => {
  const meals: Meal[] = [
    { id: 'm1', type: 'BREAKFAST', order: 1, logCount: 0 },
    { id: 'm2', type: 'LUNCH', order: 2, logCount: 0 },
    { id: 'm3', type: 'SNACK', order: 3, logCount: 0 },
  ];

  it('merges the three areas newest first, one row per meal with logs', () => {
    const feed = buildFeed({
      activities: [run(local(21, 7), 7.1)],
      workouts: [workout(local(20, 19), 'Treino C')],
      meals,
      todayLogs: [
        log('m1', local(21, 8), 200, 100),
        log('m2', local(21, 12), 150, 200),
        log('m2', local(21, 13), 100, 100),
      ],
    });
    expect(feed.map((f) => f.kind)).toEqual(['diet', 'diet', 'run', 'gym']);
    const lunch = feed[0];
    expect(lunch.kind === 'diet' && lunch.mealType).toBe('LUNCH');
    expect(lunch.kind === 'diet' && lunch.itemCount).toBe(2);
    expect(lunch.kind === 'diet' && lunch.kcal).toBe(400);
    expect(lunch.at).toBe(local(21, 13));
  });

  it('caps the list', () => {
    const feed = buildFeed({
      activities: Array.from({ length: 8 }, (_, i) => run(local(10 + i), 5)),
      workouts: [],
      meals: [],
      todayLogs: [],
      limit: 3,
    });
    expect(feed).toHaveLength(3);
    expect(feed[0].at).toBe(local(17));
  });
});

describe('calendarDaysAgo', () => {
  it('counts calendar days, not 24h spans', () => {
    expect(calendarDaysAgo(local(21, 1), NOW)).toBe(0);
    expect(calendarDaysAgo(local(20, 23), NOW)).toBe(1);
    expect(calendarDaysAgo(local(14), NOW)).toBe(7);
  });
});

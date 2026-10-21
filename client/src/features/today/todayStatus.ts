import type {
  Activity,
  Area,
  DailyHistoryPoint,
  FoodLogItem,
  Meal,
  MealType,
  WorkoutHistoryItem,
} from '@/lib/types';
import { startOfBin, toISODate } from '@/features/dashboard/bins';

// Pure derivations behind the "Hoje" page (Redesign 18a) — every input is a
// payload some other page already fetches, so nothing here needs an endpoint
// of its own. Every day is a local day: activities and workouts are bucketed
// here in the browser's time zone, and the diet history arrives already cut
// at local midnight (apiFetch sends X-Time-Zone)

/** Dieta counts as done once the day reaches 90% of the kcal goal */
export const DIET_DONE_RATIO = 0.9;

export function isDietDone(kcal: number, kcalGoal: number): boolean {
  return kcalGoal > 0 && kcal >= kcalGoal * DIET_DONE_RATIO;
}

export interface DayStatus {
  /** local YYYY-MM-DD */
  date: string;
  run: boolean;
  gym: boolean;
  diet: boolean;
}

/** the last `n` local days, oldest first, ending today */
export function lastNDays(now: Date, n: number): Date[] {
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  return Array.from({ length: n }, (_, i) => {
    const d = new Date(today);
    d.setDate(d.getDate() - (n - 1 - i));
    return d;
  });
}

export function buildDays(input: {
  activities: Activity[];
  workouts: WorkoutHistoryItem[];
  dietPoints: DailyHistoryPoint[];
  kcalGoal: number;
  now: Date;
  n?: number;
}): DayStatus[] {
  const runDays = new Set(
    input.activities.map((a) => toISODate(new Date(a.startDate))),
  );
  // history-stats only lists finished workouts, so every item counts
  const gymDays = new Set(
    input.workouts.map((w) => toISODate(new Date(w.startedAt))),
  );
  const kcalByDay = new Map(input.dietPoints.map((p) => [p.date, p.totalKcal]));
  return lastNDays(input.now, input.n ?? 7).map((d) => {
    const date = toISODate(d);
    return {
      date,
      run: runDays.has(date),
      gym: gymDays.has(date),
      diet: isDietDone(kcalByDay.get(date) ?? 0, input.kcalGoal),
    };
  });
}

const AREA_KEY = { RUN: 'run', GYM: 'gym', DIET: 'diet' } as const;

/** how many of the user's enabled areas were completed that day */
export function countDone(day: DayStatus, areas: readonly Area[]): number {
  return areas.filter((a) => day[AREA_KEY[a]]).length;
}

export interface DayValue {
  /** local YYYY-MM-DD */
  date: string;
  value: number;
}

/**
 * one number per local day for the single-area Hoje (Redesign 21c): km run,
 * workouts finished, or kcal eaten — the last `n` days, oldest first
 */
export function buildDailyValues(input: {
  area: Area;
  activities: Activity[];
  workouts: WorkoutHistoryItem[];
  dietPoints: DailyHistoryPoint[];
  now: Date;
  n?: number;
}): DayValue[] {
  const byDay = new Map<string, number>();
  const add = (date: string, v: number) =>
    byDay.set(date, (byDay.get(date) ?? 0) + v);
  if (input.area === 'RUN') {
    for (const a of input.activities)
      add(toISODate(new Date(a.startDate)), a.distanceKm ?? 0);
  } else if (input.area === 'GYM') {
    for (const w of input.workouts) add(toISODate(new Date(w.startedAt)), 1);
  } else {
    for (const p of input.dietPoints) add(p.date, p.totalKcal);
  }
  return lastNDays(input.now, input.n ?? 7).map((d) => {
    const date = toISODate(d);
    return { date, value: byDay.get(date) ?? 0 };
  });
}

export interface TodayTotals {
  /** km run today */
  runKmToday: number;
  /** km run in the current Monday-start week */
  runKmWeek: number;
  /** workouts finished today */
  workoutsToday: WorkoutHistoryItem[];
  /** workouts finished in the current Monday-start week */
  workoutsWeek: number;
}

export function buildTotals(input: {
  activities: Activity[];
  workouts: WorkoutHistoryItem[];
  now: Date;
}): TodayTotals {
  const todayKey = toISODate(input.now);
  const weekStart = startOfBin(input.now, 'week');
  const inWeek = (iso: string) => new Date(iso) >= weekStart;
  const isToday = (iso: string) => toISODate(new Date(iso)) === todayKey;

  let runKmToday = 0;
  let runKmWeek = 0;
  for (const a of input.activities) {
    const km = a.distanceKm ?? 0;
    if (isToday(a.startDate)) runKmToday += km;
    if (inWeek(a.startDate)) runKmWeek += km;
  }
  return {
    runKmToday,
    runKmWeek,
    workoutsToday: input.workouts.filter((w) => isToday(w.startedAt)),
    workoutsWeek: input.workouts.filter((w) => inWeek(w.startedAt)).length,
  };
}

export type FeedItem =
  | {
      kind: 'run';
      id: string;
      at: string;
      name: string;
      durationSec: number;
      distanceKm: number;
    }
  | {
      kind: 'gym';
      id: string;
      at: string;
      /** null for a free workout (no routine) */
      name: string | null;
      exerciseCount: number;
      durationSec: number;
    }
  | {
      kind: 'diet';
      id: string;
      at: string;
      mealType: MealType;
      itemCount: number;
      kcal: number;
    };

/**
 * the most recent entries across the three areas, newest first. Diet only
 * contributes today's meals (the page fetches one day of logs): one row per
 * meal that has logs, timestamped by its latest log
 */
export function buildFeed(input: {
  activities: Activity[];
  workouts: WorkoutHistoryItem[];
  meals: Meal[];
  todayLogs: FoodLogItem[];
  /** only these areas contribute (default: all three) */
  areas?: readonly Area[];
  limit?: number;
}): FeedItem[] {
  const items: FeedItem[] = [];
  for (const a of input.activities) {
    items.push({
      kind: 'run',
      id: a.id,
      at: a.startDate,
      name: a.name,
      durationSec: a.movingTimeSec,
      distanceKm: a.distanceKm ?? 0,
    });
  }
  for (const w of input.workouts) {
    items.push({
      kind: 'gym',
      id: w.id,
      at: w.finishedAt,
      name: w.templateName,
      exerciseCount: w.exerciseCount,
      durationSec: w.durationSec,
    });
  }
  for (const meal of input.meals) {
    const logs = input.todayLogs.filter((l) => l.mealId === meal.id);
    if (logs.length === 0) continue;
    items.push({
      kind: 'diet',
      id: meal.id,
      at: logs.reduce(
        (latest, l) => (l.loggedAt > latest ? l.loggedAt : latest),
        logs[0].loggedAt,
      ),
      mealType: meal.type,
      itemCount: logs.length,
      kcal: Math.round(
        logs.reduce((sum, l) => sum + (l.food.kcal * l.quantity) / 100, 0),
      ),
    });
  }
  const kinds = new Set(
    (input.areas ?? (['RUN', 'GYM', 'DIET'] as const)).map((a) => AREA_KEY[a]),
  );
  return items
    .filter((item) => kinds.has(item.kind))
    .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime())
    .slice(0, input.limit ?? 5);
}

/** whole local calendar days between `iso` and `now` — 0 today, 1 yesterday */
export function calendarDaysAgo(iso: string, now: Date): number {
  const day = new Date(iso);
  day.setHours(0, 0, 0, 0);
  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  return Math.max(
    0,
    Math.round((today.getTime() - day.getTime()) / 86_400_000),
  );
}

export interface Activity {
  id: string;
  name: string;
  workoutType: string;
  startDate: string;
  distanceKm: number | null;
  movingTimeSec: number;
  paceRawSecKm: number | null;
  elevationGainM: number | null;
  averageBpm: number | null;
  maxBpm: number | null;
  averageCadence: number | null;
}

export interface ActivitiesResponse {
  items: Activity[];
  total: number;
}

// RUN/WORKOUT/REST/STEADY/WARMUP/COOLDOWN are user-editable via the lap
// editor; ACTIVITY is a detector-only fallback (no distinct effort found)
// and only ever appears read-only on laps synced before manual editing
export type LapType =
  | 'RUN'
  | 'WORKOUT'
  | 'REST'
  | 'STEADY'
  | 'WARMUP'
  | 'COOLDOWN'
  | 'ACTIVITY';

export interface ActivityLap {
  id: string;
  lapIndex: number;
  lapType: LapType;
  startSec: number;
  endSec: number;
  movingDurationSec: number;
  distanceM: number;
  avgPaceSecKm: number;
  avgHr: number;
  maxHr: number | null;
  elevGainM: number;
  avgCadence: number | null;
}

export interface ActivityDetail extends Activity {
  stravaId: string;
  summaryPolyline: string | null;
  laps: ActivityLap[];
}

// GET /activities/:id/streams — per-second stream used by the lap editor to
// resolve distance/time-based lap boundaries client-side
export interface ActivityStreamPoint {
  secondIndex: number;
  distanceTotalM: number;
  elevationM: number;
  heartRate: number;
  speedMs: number;
  cadence: number | null;
}

export interface ActivityStreamsResponse {
  points: ActivityStreamPoint[];
  source: 'stored' | 'strava';
}

export type LapSizeMode = 'distance' | 'time';

// PUT /activities/:id/laps request — boundaries are never sent, only
// type + size; the backend resolves positions via a sequential walk
export interface LapEditInput {
  lapType: LapType;
  sizeMode: LapSizeMode;
  sizeValue: number;
}

// flat, cross-activity lap for GET /activities/laps (Run > Analysis) — avgHr
// is 0 (never null) when no HR monitor was present for that lap
export interface ActivityLapPoint {
  activityId: string;
  activityStartDate: string;
  lapIndex: number;
  workoutType: string;
  distanceM: number;
  movingDurationSec: number;
  avgPaceSecKm: number;
  avgHr: number;
}

export interface ActivityLapsResponse {
  items: ActivityLapPoint[];
}

// per-activity (not per-lap) real HR zone time from Strava, requires a
// premium account — zoneIndex 1 = Z2 (0-based, native Strava zone order)
export interface ActivityHrZonePoint {
  activityId: string;
  activityStartDate: string;
  zoneIndex: number;
  min: number;
  max: number;
  timeSec: number;
}

export interface ActivityHrZonesResponse {
  items: ActivityHrZonePoint[];
}

export interface Gear {
  id: string;
  name: string;
  brandName: string | null;
  modelName: string | null;
  distance: number;
  computedDistanceM: number;
  runCount: number;
  firstUseDate: string | null;
  lastUseDate: string | null;
  primary: boolean;
  retired: boolean;
}

// GET /strava/sync/status — mirrors SyncProgress on the server
export interface SyncStatus {
  state: 'idle' | 'running' | 'done' | 'error';
  phase: 'listing' | 'processing' | 'rate_limited' | null;
  total: number | null;
  processed: number;
  synced: number;
  errors: number;
  etaSeconds: number | null;
  /** start date of the activity currently being processed */
  processingDate: string | null;
  startedAt: string | null;
  finishedAt: string | null;
  message: string | null;
  rateLimitResetAt: string | null;
}

// ---- Gym module ----

export interface ExerciseListItem {
  id: string;
  name: string;
  slug: string;
  force: string | null;
  level: string | null;
  mechanic: string | null;
  equipment: string | null;
  primaryMuscles: string[];
  secondaryMuscles: string[];
  source: string;
}

export interface ExerciseDetail extends ExerciseListItem {
  instructions: string[];
  imageUrls: string[];
}

export interface ExercisesResponse {
  items: ExerciseListItem[];
  total: number;
  page: number;
  limit: number;
}

export interface LastPerformanceSet {
  id: string;
  setNumber: number;
  weightKg: number | null;
  reps: number | null;
  rpe: number | null;
  setType: string;
}

export interface LastPerformance {
  workoutId: string;
  startedAt: string;
  sets: LastPerformanceSet[];
}

export interface ExercisePersonalRecord {
  weightKg: number;
  reps: number | null;
  workoutId: string;
  startedAt: string;
  templateName: string | null;
}

export interface WorkoutSet {
  id: string;
  setNumber: number;
  weightKg: number | null;
  reps: number | null;
  rpe: number | null;
  setType: string;
  completedAt: string;
}

// goal carried over from the originating template, matched by exerciseId —
// null for free workouts or exercises added ad hoc after starting from one
export interface ExerciseTarget {
  sets: number | null;
  repsMin: number | null;
  repsMax: number | null;
}

export interface WorkoutExercise {
  id: string;
  exerciseId: string;
  exerciseName: string;
  order: number;
  supersetGroupId: string | null;
  target: ExerciseTarget | null;
  sets: WorkoutSet[];
}

export interface WorkoutDetail {
  id: string;
  startedAt: string;
  finishedAt: string | null;
  notes: string | null;
  templateId: string | null;
  templateName: string | null;
  exercises: WorkoutExercise[];
}

// PATCH /workouts/:id/finish — server/src/workouts/workout-summary.ts
export interface WorkoutPersonalRecord {
  exerciseId: string;
  exerciseName: string;
  weightKg: number;
  reps: number | null;
  /** always present: a first-ever session for an exercise isn't a PR */
  previousWeightKg: number;
  previousReps: number | null;
}

export interface WorkoutFinishSummary {
  durationSec: number;
  volumeKg: number;
  setCount: number;
  exerciseCount: number;
  personalRecords: WorkoutPersonalRecord[];
}

export interface FinishedWorkout extends WorkoutDetail {
  summary: WorkoutFinishSummary;
}

export interface WorkoutHistoryItem {
  id: string;
  startedAt: string;
  finishedAt: string;
  durationSec: number;
  exerciseCount: number;
  volumeKg: number;
  templateId: string | null;
  templateName: string | null;
}

// POST/PATCH .../sets request body — all optional, a bodyweight set may
// carry reps only
export interface SetInput {
  weightKg?: number;
  reps?: number;
  rpe?: number;
  setType?: string;
}

// ---- Workout templates (routines) ----

export interface TemplateExerciseTargets {
  targetSets?: number;
  targetRepsMin?: number;
  targetRepsMax?: number;
}

export interface TemplateExerciseDetail extends TemplateExerciseTargets {
  id: string;
  exerciseId: string;
  exerciseName: string;
  primaryMuscles: string[];
  order: number;
  supersetGroupId: string | null;
}

export interface TemplateDetail {
  id: string;
  name: string;
  description: string | null;
  exercises: TemplateExerciseDetail[];
}

export interface TemplateSummary {
  id: string;
  name: string;
  description: string | null;
  exerciseCount: number;
  exercisePreview: string[];
  muscleGroups: string[];
  lastPerformedAt: string | null;
}

export interface PersonalBestRecord {
  name: string;
  /** 1–3, derived server-side from moving time (fastest first) */
  rank: number;
  movingTime: number;
  /** meters, as measured by Strava for the effort */
  distance: number;
  startDate: string;
  activityId: string;
  /** Strava's rank frozen at upload time — "was a PR back then" */
  prRank: number | null;
}

// ---- Diet module ----

/** all macro fields are always per-100g, regardless of source */
export interface FoodListItem {
  id: string;
  name: string;
  brand: string | null;
  source: 'TACO' | 'OFF' | 'CUSTOM';
  imageUrl: string | null;
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber: number | null;
  sodium: number | null;
  /** closed slug (see SERVING_UNITS in constants.ts), null for grams-only foods */
  servingLabel: string | null;
  /** grams in one serving — how "2 unidades" becomes 100g */
  servingGrams: number | null;
}

/** closed vocabulary of meal *names* — the day's actual slots are Meal rows */
export type MealType = 'BREAKFAST' | 'LUNCH' | 'SNACK' | 'DINNER' | 'SUPPER';

// One slot in the user's day, configured once and applying to every date.
// Two slots may share a type (two "Lanche"), so `id` — not `type` — is what
// a FoodLog points at.
export interface Meal {
  id: string;
  type: MealType;
  order: number;
  /** logs attached to this meal across every day — drives the delete confirmation */
  logCount: number;
}

export interface FoodLogItem {
  id: string;
  /** always grams, whatever unit was picked in the UI */
  quantity: number;
  /** display hint: render as N servings instead of raw grams */
  enteredAsServing: boolean;
  mealId: string;
  loggedAt: string;
  food: FoodListItem;
}

export interface DailySummary {
  totalKcal: number;
  totalProtein: number;
  totalCarbs: number;
  totalFat: number;
}

export interface DailyHistoryPoint extends DailySummary {
  date: string;
}

export interface NutritionGoal {
  dailyKcalGoal: number;
  dailyProteinGoal: number;
  dailyCarbsGoal: number;
  dailyFatGoal: number;
}

// GET/PATCH /users/me also carries the weekly targets the "Hoje" page
// measures Corrida and Treino against — same snapshot as NutritionGoal
export interface WeeklyGoals {
  weeklyRunKmGoal: number;
  weeklyWorkoutsGoal: number;
}

// ---- Saved meals (reusable food+quantity combos, no fixed Meal — see
// AddMealPage's "Refeições salvas" flow) ----

export interface SavedMealItemDetail {
  id: string;
  quantity: number;
  order: number;
  food: FoodListItem;
}

export interface SavedMealDetail {
  id: string;
  name: string;
  items: SavedMealItemDetail[];
}

export interface SavedMealSummary {
  id: string;
  name: string;
  itemCount: number;
  itemPreview: string[];
  totalKcal: number;
}

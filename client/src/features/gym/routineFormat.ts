import type { TemplateSummary } from '@/lib/types';

// shared between RoutineEditPage.tsx (builder card) and RoutineDetailPage.tsx
// (read-only exercise list) — a separate file (not a named export from a
// component file) because Vite's Fast Refresh requires component files to
// only export components
export function formatRepsRange(
  min: number | null | undefined,
  max: number | null | undefined,
): string {
  if (min == null && max == null) return '—';
  if (min != null && max != null && min !== max) return `${min}–${max}`;
  return String(min ?? max);
}

// per-exercise rest steps for the routine editor (15s, the server's minimum,
// up to 10min, its maximum — WorkoutTemplateExercise.restSeconds)
export const REST_STEP_SEC = 15;
export const REST_MIN_SEC = 15;
export const REST_MAX_SEC = 600;
// where "+" lands from "Padrão" (no per-exercise rest): the timer's default
export const REST_FIRST_SEC = 90;
export const REST_OPTIONS_SEC = [30, 45, 60, 75, 90, 120, 150, 180, 240, 300];

// 90 → "1:30", 45 → "0:45"
export function formatRestSeconds(sec: number): string {
  return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;
}

// "Treino A — Peito/Tríceps" → "Peito/Tríceps" — GymOverviewPage's routines
// section shows the descriptive part only, dropping the "Treino X — " label
// suggested by editor.namePlaceholder; names that don't follow that
// convention (most real routines, e.g. "Upper") pass through untouched
export function stripWorkoutPrefix(name: string): string {
  return name.replace(/^treino\s+\S+\s*[—-]\s*/i, '');
}

/**
 * the routine to suggest next: the one performed longest ago, so a split
 * (A → B → C) rotates on its own. Never-performed routines only come up
 * when nothing has been performed yet — otherwise an abandoned routine
 * would sit in the spotlight forever. Shared by GymOverviewPage ("Próximo
 * treino") and TodayPage (the pending Treino status)
 */
export function pickNextRoutine(templates: TemplateSummary[]): TemplateSummary | null {
  const performed = templates.filter((tpl) => tpl.lastPerformedAt != null);
  if (performed.length === 0) return templates[0] ?? null;
  return performed.reduce((oldest, tpl) =>
    tpl.lastPerformedAt! < oldest.lastPerformedAt! ? tpl : oldest,
  );
}

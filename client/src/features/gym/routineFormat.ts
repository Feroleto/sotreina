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

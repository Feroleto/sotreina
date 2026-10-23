import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import type { ExerciseDetail, WorkoutExercise, WorkoutSet } from '@/lib/types';
import { formatRepsRange } from './routineFormat';
import { formatWeight, weightLabel } from '@/lib/units';

function setVolume(set: WorkoutSet): number {
  return (set.weightKg ?? 0) * (set.reps ?? 0);
}

// highest-volume set — reused for both the "1RM est." stat card and the
// "Melhor série" line below, so there's a single definition of "best" set
// on this screen rather than two different rankings
function bestSet(sets: WorkoutSet[]): WorkoutSet | null {
  return sets.reduce<WorkoutSet | null>((best, s) => {
    if (!best || setVolume(s) > setVolume(best)) return s;
    return best;
  }, null);
}

// Epley formula — same estimate convention as most strength-training apps
function epley1RM(weightKg: number, reps: number): number {
  return weightKg * (1 + reps / 30);
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[12px] border border-border p-[11px_8px] text-center">
      <div className="text-[15px] font-semibold text-foreground">{value}</div>
      <div className="mt-0.5 text-[10.5px] text-muted-foreground">{label}</div>
    </div>
  );
}

interface ExerciseSessionDetailPageProps {
  exercise: WorkoutExercise;
  onBack: () => void;
}

// set-by-set detail of one exercise within a finished session, opened by
// tapping a row in WorkoutDetailPage.tsx. All the numbers here (sets,
// volume, 1RM estimate, best set) are derived straight from the real
// per-set weightKg/reps already returned by GET /workouts/:id — no
// simulated/derived data needed, unlike the design brief's fallback
// instruction, since the backend has always recorded sets individually.
// Only the muscle group chip needs its own fetch (GET /exercises/:id),
// same source RoutineExerciseDetailPage.tsx already uses.
//
// "Peso planejado" from the design reference is intentionally omitted:
// WorkoutTemplateExercise only stores targetSets/targetRepsMin/targetRepsMax
// (see CLAUDE.md's "Módulo Academia — fase 2") — a routine never carries a
// planned weight, so there's no real field to show there.
export default function ExerciseSessionDetailPage({
  exercise,
  onBack,
}: ExerciseSessionDetailPageProps) {
  const { t } = useTranslation('gym');
  const [detail, setDetail] = useState<ExerciseDetail | null>(null);

  useEffect(() => {
    let cancelled = false;
    apiFetch(`/exercises/${exercise.exerciseId}`)
      .then((res) => (res.ok ? (res.json() as Promise<ExerciseDetail>) : null))
      .then((data) => {
        if (!cancelled) setDetail(data);
      })
      .catch(() => {
        // best-effort enrichment — the chip just stays hidden without it
      });
    return () => {
      cancelled = true;
    };
  }, [exercise.exerciseId]);

  const muscle = detail?.primaryMuscles[0];
  const sets = exercise.sets;
  const totalVolume = sets.reduce((sum, s) => sum + setVolume(s), 0);
  const best = bestSet(sets);
  const estimated1RM =
    best && best.weightKg != null && best.reps != null
      ? round1(epley1RM(best.weightKg, best.reps))
      : null;

  return (
    <div className="flex min-h-screen flex-col">
      <div className="sticky top-0 z-10 flex items-center gap-3 border-b border-border bg-card px-5 py-4">
        <button
          type="button"
          onClick={onBack}
          aria-label={t('routines.back')}
          className="cursor-pointer text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" strokeWidth={1.8} />
        </button>
        <h1 className="flex-1 truncate text-[15px] font-semibold text-foreground">
          {exercise.exerciseName}
        </h1>
      </div>

      <div className="flex-1 overflow-y-auto px-5 pt-[18px] pb-[44px]">
        <h2 className="text-[20px] font-bold text-foreground">
          {exercise.exerciseName}
        </h2>
        {muscle && (
          <span className="mt-2 inline-block rounded-full bg-chip p-[4px_9px] text-[10.5px] font-semibold text-muted-foreground">
            {t(`muscles.${muscle}`, muscle)}
          </span>
        )}

        <div className="mt-4 grid grid-cols-3 gap-2">
          <StatCard
            label={t('history.exerciseSets.statSets')}
            value={String(sets.length)}
          />
          <StatCard
            label={t('history.exerciseSets.statVolume')}
            value={t('history.exerciseSets.kgValue', {
              unit: weightLabel(),
              weight: formatWeight(totalVolume),
            })}
          />
          <StatCard
            label={t('history.exerciseSets.stat1rm')}
            value={
              estimated1RM != null
                ? t('history.exerciseSets.kgValue', {
                    unit: weightLabel(),
                    weight: formatWeight(estimated1RM),
                  })
                : '—'
            }
          />
        </div>

        <div className="mt-5 flex items-center gap-1.5 text-[10px] font-medium tracking-[.04em] text-muted-foreground uppercase">
          <div className="w-[36px] flex-none">
            {t('history.exerciseSets.columnSet')}
          </div>
          <div className="min-w-0 flex-1">
            {t('history.exerciseSets.columnWeight')}
          </div>
          <div className="min-w-0 flex-1">
            {t('history.exerciseSets.columnReps')}
          </div>
          <div className="min-w-0 flex-1 text-right">
            {t('history.exerciseSets.columnVolume')}
          </div>
        </div>
        {sets.map((s) => (
          <div
            key={s.id}
            className="mt-2 flex items-center gap-1.5 text-[13px]"
          >
            <div className="w-[36px] flex-none font-medium text-foreground">
              {s.setNumber}
            </div>
            <div className="min-w-0 flex-1 text-foreground">
              {s.weightKg != null ? formatWeight(s.weightKg) : '—'}{' '}
              {weightLabel()}
            </div>
            <div className="min-w-0 flex-1 text-foreground">
              {s.reps ?? '—'}
            </div>
            <div className="min-w-0 flex-1 text-right text-muted-foreground">
              {t('history.exerciseSets.kgValue', {
                unit: weightLabel(),
                weight: formatWeight(setVolume(s)),
              })}
            </div>
          </div>
        ))}

        <div className="mt-5 border-b border-border pb-2 text-[11.5px] font-medium tracking-[.05em] text-muted-foreground uppercase">
          {t('history.exerciseSets.otherInfo')}
        </div>
        <div className="flex items-center justify-between border-b border-border py-[10px] text-[13px]">
          <span className="text-muted-foreground">
            {t('history.exerciseSets.bestSet')}
          </span>
          <span className="font-medium text-foreground">
            {best
              ? t('history.exerciseSets.bestSetValue', {
                  unit: weightLabel(),
                  n: best.setNumber,
                  weight:
                    best.weightKg != null ? formatWeight(best.weightKg) : '—',
                  reps: best.reps ?? '—',
                })
              : '—'}
          </span>
        </div>
        <div className="flex items-center justify-between border-b border-border py-[10px] text-[13px]">
          <span className="text-muted-foreground">
            {t('history.exerciseSets.plannedReps')}
          </span>
          <span className="font-medium text-foreground">
            {exercise.target
              ? `${formatRepsRange(exercise.target.repsMin, exercise.target.repsMax)} ${t('history.exerciseSets.repsUnit')}`
              : '—'}
          </span>
        </div>
      </div>
    </div>
  );
}

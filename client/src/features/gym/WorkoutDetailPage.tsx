import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, ChevronRight } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import { currentIntlLocale } from '@/lib/dateLocale';
import { formatDurationShort } from '@/lib/activityFormat';
import type {
  WorkoutDetail,
  WorkoutExercise,
  WorkoutHistoryItem,
  WorkoutSet,
} from '@/lib/types';
import ExerciseSessionDetailPage from './ExerciseSessionDetailPage';
import DrillStack from '@/components/DrillStack';
import { SkeletonRows } from '@/components/Skeleton';
import {
  formatVolume,
  formatWeight,
  volumeLabel,
  weightLabel,
} from '@/lib/units';

function formatDateLong(iso: string): string {
  const s = new Date(iso).toLocaleDateString(currentIntlLocale(), {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
  });
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// per-exercise summary shown in the read-only list — averaged across its
// sets since a session's sets don't always share one weight/reps value
// (unlike the routine editor's target, which is a single planned range)
function summarizeSets(sets: WorkoutSet[]): {
  weightKg: number | null;
  reps: number | null;
} {
  const weights = sets
    .map((s) => s.weightKg)
    .filter((w): w is number => w != null);
  const repsList = sets
    .map((s) => s.reps)
    .filter((r): r is number => r != null);
  const avg = (arr: number[]) => arr.reduce((a, b) => a + b, 0) / arr.length;
  return {
    weightKg: weights.length ? Math.round(avg(weights) * 10) / 10 : null,
    reps: repsList.length ? Math.round(avg(repsList)) : null,
  };
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[12px] border border-border p-[13px_15px]">
      <div className="text-[10.5px] font-semibold tracking-[.07em] text-muted-foreground uppercase">
        {label}
      </div>
      <div className="mt-1 text-[17px] font-bold text-foreground">{value}</div>
    </div>
  );
}

interface WorkoutDetailPageProps {
  item: WorkoutHistoryItem;
  onBack: () => void;
}

// read-only detail of a finished session, opened by tapping a row in the
// "Histórico" tab's week-grouped list (GymHistoryPage.tsx). `item` is the
// already-fetched WorkoutHistoryItem (duration/volume/exercise count come
// from there, same "don't refetch what's already loaded" pattern as
// RoutineDetailPage.tsx); only the per-exercise sets need their own fetch,
// via the same GET /workouts/:id used by the live session
export default function WorkoutDetailPage({
  item,
  onBack,
}: WorkoutDetailPageProps) {
  const { t } = useTranslation('gym');
  const [detail, setDetail] = useState<WorkoutDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [viewingExercise, setViewingExercise] =
    useState<WorkoutExercise | null>(null);

  useEffect(() => {
    let cancelled = false;
    apiFetch(`/workouts/${item.id}`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json() as Promise<WorkoutDetail>;
      })
      .then((data) => {
        if (!cancelled) setDetail(data);
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
  }, [item.id]);

  const totalSets =
    detail?.exercises.reduce((sum, ex) => sum + ex.sets.length, 0) ?? 0;

  return (
    <DrillStack
      depth={viewingExercise ? 1 : 0}
      viewKey={viewingExercise ? `exercise:${viewingExercise.id}` : 'workout'}
    >
      {viewingExercise ? (
        <ExerciseSessionDetailPage
          exercise={viewingExercise}
          onBack={() => setViewingExercise(null)}
        />
      ) : (
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
              {item.templateName ?? t('start.freeWorkout')}
            </h1>
          </div>

          <div className="flex-1 px-5 pt-[18px] pb-[44px]">
            <div className="text-[12.5px] text-muted-foreground">
              {formatDateLong(item.startedAt)}
            </div>

            <div className="mt-3 grid grid-cols-2 gap-2.5">
              <StatCard
                label={t('history.detail.statDuration')}
                value={formatDurationShort(item.durationSec)}
              />
              <StatCard
                label={t('history.detail.statVolume')}
                value={`${formatVolume(item.volumeKg)} ${volumeLabel()}`}
              />
              <StatCard
                label={t('history.detail.statExercises')}
                value={String(item.exerciseCount)}
              />
              <StatCard
                label={t('history.detail.statSets')}
                value={String(totalSets)}
              />
            </div>

            <div className="mt-5 border-b border-border pb-2 text-[11.5px] font-medium tracking-[.05em] text-muted-foreground uppercase">
              {t('history.detail.exercisesHeader')}
            </div>

            {loading && <SkeletonRows />}
            {error && <p className="mt-3 text-[12.5px] text-neg">{error}</p>}

            {!loading &&
              !error &&
              detail?.exercises.map((ex, idx) => {
                const { weightKg, reps } = summarizeSets(ex.sets);
                return (
                  <button
                    key={ex.id}
                    type="button"
                    onClick={() => setViewingExercise(ex)}
                    className="flex w-full cursor-pointer items-center gap-[12px] border-b border-border p-[13px_2px] text-left"
                  >
                    <div className="w-[22px] flex-none text-[12px] text-muted-foreground">
                      {idx + 1}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[14px] font-semibold text-foreground">
                        {ex.exerciseName}
                      </div>
                      <div className="mt-0.5 text-[11.5px] text-muted-foreground">
                        {t('history.detail.exerciseSummary', {
                          unit: weightLabel(),
                          sets: ex.sets.length,
                          weight:
                            weightKg != null ? formatWeight(weightKg) : '—',
                          reps: reps ?? '—',
                        })}
                      </div>
                    </div>
                    <ChevronRight
                      className="h-4 w-4 flex-none text-muted-foreground"
                      strokeWidth={1.8}
                    />
                  </button>
                );
              })}
          </div>
        </div>
      )}
    </DrillStack>
  );
}

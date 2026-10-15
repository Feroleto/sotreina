import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import type { ExerciseDetail, LastPerformance, TemplateExerciseDetail } from '@/lib/types';
import { formatRepsRange } from './routineFormat';

interface RoutineExerciseDetailPageProps {
  exercise: TemplateExerciseDetail;
  fallbackMuscle?: string;
  onBack: () => void;
}

// stacked full-screen detail for a single routine exercise, opened by
// tapping a row in RoutineDetailPage.tsx. Equipment/instructions come from
// the real exercise library (GET /exercises/:id) rather than mock data —
// the seed of 873 exercises already carries that data; "peso anterior" is
// the heaviest set from the real last-performance endpoint. Per-field
// fallbacks below only kick in when the library entry itself is missing
// that piece of data (e.g. no instructions authored), not as a stand-in
// for the fetch as a whole.
export default function RoutineExerciseDetailPage({
  exercise,
  fallbackMuscle,
  onBack,
}: RoutineExerciseDetailPageProps) {
  const { t } = useTranslation('gym');
  const [detail, setDetail] = useState<ExerciseDetail | null>(null);
  const [lastPerformance, setLastPerformance] = useState<LastPerformance | null>(null);
  const [imageFailed, setImageFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    apiFetch(`/exercises/${exercise.exerciseId}`)
      .then((res) => (res.ok ? (res.json() as Promise<ExerciseDetail>) : null))
      .then((data) => {
        if (!cancelled) setDetail(data);
      })
      .catch(() => {
        // best-effort enrichment — the read-only fallbacks below cover it
      });
    apiFetch(`/exercises/${exercise.exerciseId}/last-performance`)
      .then((res) => res.text())
      .then((text) => {
        if (!cancelled) setLastPerformance(text ? (JSON.parse(text) as LastPerformance) : null);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [exercise.exerciseId]);

  const muscle = detail?.primaryMuscles[0] ?? exercise.primaryMuscles[0] ?? fallbackMuscle;
  const equipmentLabel = detail?.equipment
    ? t(`equipment.${detail.equipment}`, detail.equipment)
    : t('exerciseDetail.equipmentFallback');
  const instructionsText =
    detail?.instructions.filter(Boolean).join(' ') || t('exerciseDetail.instrFallback');

  const prevWeight = lastPerformance?.sets.reduce<number | null>((max, s) => {
    if (s.weightKg == null) return max;
    return max == null ? s.weightKg : Math.max(max, s.weightKg);
  }, null);

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
        {detail?.imageUrls[0] && !imageFailed ? (
          <img
            src={detail.imageUrls[0]}
            alt={exercise.exerciseName}
            className="h-[200px] w-full rounded-[16px] bg-chip object-cover outline outline-1 -outline-offset-1 outline-black/10 dark:outline-white/10"
            onError={() => setImageFailed(true)}
          />
        ) : (
          <div className="h-[200px] w-full rounded-[16px] bg-chip" />
        )}

        <h2 className="mt-4 text-[20px] font-bold text-foreground">{exercise.exerciseName}</h2>

        <div className="mt-2 flex flex-wrap gap-[6px]">
          {muscle && (
            <span className="rounded-full bg-chip p-[4px_9px] text-[10.5px] font-semibold text-muted-foreground">
              {t(`muscles.${muscle}`, muscle)}
            </span>
          )}
          <span className="rounded-full bg-chip p-[4px_9px] text-[10.5px] font-semibold text-muted-foreground">
            {equipmentLabel}
          </span>
        </div>

        <div className="mt-4 grid grid-cols-3 gap-2">
          <StatCard
            label={t('exerciseDetail.setsLabel')}
            value={exercise.targetSets != null ? String(exercise.targetSets) : '—'}
          />
          <StatCard
            label={t('exerciseDetail.repsLabel')}
            value={formatRepsRange(exercise.targetRepsMin, exercise.targetRepsMax)}
          />
          <StatCard
            label={t('exerciseDetail.prevWeightLabel')}
            value={
              prevWeight != null
                ? t('exerciseDetail.prevWeightValue', { weight: prevWeight })
                : '—'
            }
          />
        </div>

        <div className="mt-5 border-b border-border pb-2 text-[11.5px] font-medium tracking-[.05em] text-muted-foreground uppercase">
          {t('exerciseDetail.howTo')}
        </div>
        <p className="mt-3 text-[13.5px] leading-[1.6] text-foreground">{instructionsText}</p>
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-[12px] border border-border p-[11px_8px] text-center">
      <div className="text-[15px] font-semibold text-foreground">{value}</div>
      <div className="mt-0.5 text-[10.5px] text-muted-foreground">{label}</div>
    </div>
  );
}

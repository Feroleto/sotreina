import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, ChevronRight, Pencil, Trash2 } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import type { TemplateDetail, TemplateExerciseDetail, TemplateSummary } from '@/lib/types';
import { formatLastPerformed } from './relativeTime';
import { formatRepsRange, formatRestSeconds } from './routineFormat';
import RoutineWorkoutToggleButton from './RoutineWorkoutToggleButton';
import RoutineExerciseDetailPage from './RoutineExerciseDetailPage';
import DrillStack from '@/components/DrillStack';
import { SkeletonRows } from '@/components/Skeleton';

interface RoutineDetailPageProps {
  template: TemplateSummary;
  onStart: () => void;
  onBack: () => void;
  onEdit: () => void;
  onDelete: () => void;
}

// read-only view of a routine's exercises, opened by tapping a card in
// RoutinesListPage.tsx — the only caller now that "Rotinas" and "Treino" were
// consolidated into a single tab (see GymWorkoutsPage.tsx). `template` is the
// already-fetched TemplateSummary (chips/exercise count/last-performed come
// from there, no need to refetch the list); only the per-exercise sets/reps
// detail needs its own fetch, since TemplateSummary doesn't carry that.
// Edit/delete in the app bar are a second entry point into the same actions
// the caller already has (onEdit/onDelete) — the routine stops existing
// after a delete, so the caller is expected to navigate away (e.g. clear its
// "viewing" state) as part of onDelete, not just remove it from a list in
// place. onStart navigates into the real execution screen
// (WorkoutSession.tsx, hosted by GymWorkoutsPage.tsx) — this screen
// itself never shows an "in progress"/"finalizar" state, since starting
// always leaves it
export default function RoutineDetailPage({
  template,
  onStart,
  onBack,
  onEdit,
  onDelete,
}: RoutineDetailPageProps) {
  const { t } = useTranslation('gym');
  const [detail, setDetail] = useState<TemplateDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [viewingExercise, setViewingExercise] = useState<TemplateExerciseDetail | null>(null);

  useEffect(() => {
    let cancelled = false;
    apiFetch(`/workout-templates/${template.id}`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json() as Promise<TemplateDetail>;
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
  }, [template.id]);

  return (
    <DrillStack depth={viewingExercise ? 1 : 0} viewKey={viewingExercise ? `exercise:${viewingExercise.id}` : 'routine'}>
      {viewingExercise ? (
        <RoutineExerciseDetailPage
          exercise={viewingExercise}
          fallbackMuscle={template.muscleGroups[0]}
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
              {template.name}
            </h1>
            <div className="flex flex-none items-center gap-1.5">
              <button
                type="button"
                onClick={onEdit}
                aria-label={t('editor.editTitle')}
                className="flex h-[30px] w-[30px] cursor-pointer items-center justify-center rounded-[8px] bg-chip text-muted-foreground hover:text-foreground"
              >
                <Pencil className="h-3.5 w-3.5" strokeWidth={1.8} />
              </button>
              <button
                type="button"
                onClick={() => setConfirmingDelete(true)}
                aria-label={t('routines.delete')}
                className="flex h-[30px] w-[30px] cursor-pointer items-center justify-center rounded-[8px] bg-chip text-muted-foreground hover:text-neg"
              >
                <Trash2 className="h-3.5 w-3.5" strokeWidth={1.8} />
              </button>
            </div>
          </div>

          {confirmingDelete && (
            <div className="flex items-center justify-between gap-3 border-b border-border bg-chip px-5 py-3">
              <span className="text-[13px] text-foreground">{t('routines.deleteConfirm')}</span>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setConfirmingDelete(false)}
                  className="cursor-pointer rounded-[8px] px-2.5 py-1 text-[12.5px] font-medium text-muted-foreground hover:text-foreground"
                >
                  {t('routines.cancel')}
                </button>
                <button
                  type="button"
                  onClick={onDelete}
                  className="cursor-pointer rounded-[8px] bg-neg px-2.5 py-1 text-[12.5px] font-medium text-white"
                >
                  {t('routines.delete')}
                </button>
              </div>
            </div>
          )}

          <div className="flex-1 px-5 pt-[18px] pb-[44px]">
            {template.muscleGroups.length > 0 && (
              <div className="flex flex-wrap gap-[6px]">
                {template.muscleGroups.map((mg) => (
                  <span
                    key={mg}
                    className="rounded-full bg-chip p-[4px_9px] text-[10.5px] font-semibold text-muted-foreground"
                  >
                    {t(`muscles.${mg}`, mg)}
                  </span>
                ))}
              </div>
            )}

            <div className="mt-2 text-[12.5px] text-muted-foreground">
              {t('routines.exerciseCount', { count: template.exerciseCount })} ·{' '}
              {template.lastPerformedAt
                ? t('routines.lastPerformed', {
                    when: formatLastPerformed(t, template.lastPerformedAt),
                  })
                : t('routines.neverPerformed')}
            </div>

            <div className="mt-5 border-b border-border pb-2 text-[11.5px] font-medium tracking-[.05em] text-muted-foreground uppercase">
              {t('editor.exercisesHeader')}
            </div>

            {loading && <SkeletonRows />}
            {error && <p className="mt-3 text-[12.5px] text-neg">{error}</p>}

            {!loading &&
              !error &&
              detail?.exercises.map((ex, idx) => (
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
                      {t('editor.mobileSpec', {
                        sets: ex.targetSets ?? '—',
                        reps: formatRepsRange(ex.targetRepsMin, ex.targetRepsMax),
                      })}
                      {ex.restSeconds != null &&
                        ` · ${t('editor.restSuffix', { rest: formatRestSeconds(ex.restSeconds) })}`}
                    </div>
                  </div>
                  <ChevronRight
                    className="h-4 w-4 flex-none text-muted-foreground"
                    strokeWidth={1.8}
                  />
                </button>
              ))}

            <RoutineWorkoutToggleButton onClick={onStart} />
          </div>
        </div>
      )}
    </DrillStack>
  );
}

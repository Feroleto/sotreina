import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { useActiveWorkout } from './useActiveWorkout';
import RoutinesListPage from './RoutinesListPage';
import RoutineEditPage from './RoutineEditPage';
import WorkoutSession from './WorkoutSession';
import WorkoutSummaryPage from './WorkoutSummaryPage';

type View = 'list' | 'edit';

interface GymWorkoutsPageProps {
  // owned by App.tsx (not this page) so the active session survives
  // navigating away from Academia — see ActiveWorkoutBar
  activeWorkout: ReturnType<typeof useActiveWorkout>;
  onOpenDrawer: () => void;
}

// "Rotinas" nav tab — the routines browser (RoutinesListPage), with routine
// create/edit as an in-page sub-flow, plus starting/resuming a real workout.
// useActiveWorkout is the single source of truth for the active session —
// "Iniciar treino" (from the list card or the routine detail) calls its real
// `start(templateId)`, which is idempotent (resumes an already-open workout,
// ignoring templateId, so a refresh mid-workout never spawns a second one)
export default function GymWorkoutsPage({
  activeWorkout,
  onOpenDrawer,
}: GymWorkoutsPageProps) {
  const { t } = useTranslation('gym');
  const {
    workout,
    loading,
    error,
    busy,
    start,
    addExercise,
    removeExercise,
    reorderExercise,
    commitReorderExercises,
    addSet,
    updateSet,
    deleteSet,
    checkTemplateDrift,
    finish,
    discard,
    lastFinished,
    dismissSummary,
  } = activeWorkout;
  const [view, setView] = useState<View>('list');
  const [editingTemplateId, setEditingTemplateId] = useState<string | null>(null);

  if (loading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center text-[13px] text-muted-foreground">
        {t('loading')}
      </div>
    );
  }

  // just finished: the summary takes over until dismissed (an open workout
  // can't coexist — finishing is what produced lastFinished)
  if (lastFinished && !workout) {
    return <WorkoutSummaryPage workout={lastFinished} onDone={dismissSummary} />;
  }

  if (workout) {
    return (
      <WorkoutSession
        workout={workout}
        error={error}
        busy={busy}
        onAddExercise={addExercise}
        onRemoveExercise={removeExercise}
        onReorderExercise={reorderExercise}
        onCommitReorderExercises={commitReorderExercises}
        onAddSet={addSet}
        onUpdateSet={updateSet}
        onDeleteSet={deleteSet}
        onCheckTemplateDrift={checkTemplateDrift}
        onFinish={finish}
        onDiscard={discard}
        onOpenDrawer={onOpenDrawer}
      />
    );
  }

  if (view === 'edit') {
    return (
      <RoutineEditPage
        templateId={editingTemplateId}
        onDone={() => setView('list')}
        onCancel={() => setView('list')}
      />
    );
  }

  return (
    <RoutinesListPage
      onCreateNew={() => {
        setEditingTemplateId(null);
        setView('edit');
      }}
      onEdit={(id) => {
        setEditingTemplateId(id);
        setView('edit');
      }}
      onStartWorkout={(id) => start(id)}
    />
  );
}

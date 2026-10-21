import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { useActiveWorkout } from './useActiveWorkout';
import RoutinesListPage from './RoutinesListPage';
import RoutineEditPage from './RoutineEditPage';
import WorkoutSession from './WorkoutSession';
import WorkoutSummaryPage from './WorkoutSummaryPage';
import { useHideMobileChrome } from '@/features/nav/chromeVisibility';

type View = 'list' | 'edit';

/** what the Treino overview asked this page to open when navigating here */
export type RoutinesIntent = { kind: 'open'; templateId: string } | { kind: 'new' };

interface GymWorkoutsPageProps {
  // owned by App.tsx (not this page) so the active session survives
  // navigating away from Academia — see ActiveWorkoutBar
  activeWorkout: ReturnType<typeof useActiveWorkout>;
  /** leave the live session for another page (ActiveWorkoutBar brings it back) */
  onMinimizeWorkout: () => void;
  /** read once, on mount — the page is keyed per navigation, so a stale
      intent can't replay on a later visit */
  intent: RoutinesIntent | null;
}

// "Rotinas" nav tab — the routines browser (RoutinesListPage), with routine
// create/edit as an in-page sub-flow, plus starting/resuming a real workout.
// useActiveWorkout is the single source of truth for the active session —
// "Iniciar treino" (from the list card or the routine detail) calls its real
// `start(templateId)`, which is idempotent (resumes an already-open workout,
// ignoring templateId, so a refresh mid-workout never spawns a second one)
export default function GymWorkoutsPage({
  activeWorkout,
  onMinimizeWorkout,
  intent,
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
  const [view, setView] = useState<View>(() => (intent?.kind === 'new' ? 'edit' : 'list'));
  const [editingTemplateId, setEditingTemplateId] = useState<string | null>(null);
  // live session, its summary and the routine editor are full-screen flows
  // with their own fixed bottom bar — the mobile tab bar would cover it
  useHideMobileChrome(!loading && (!!workout || !!lastFinished || view === 'edit'));

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
        onMinimize={onMinimizeWorkout}
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
      initialTemplateId={intent?.kind === 'open' ? intent.templateId : null}
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

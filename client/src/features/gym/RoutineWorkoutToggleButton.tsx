import { useTranslation } from 'react-i18next';
import { Play } from 'lucide-react';

interface RoutineWorkoutToggleButtonProps {
  onClick: () => void;
}

// shared between RoutinesListPage.tsx (card) and RoutineDetailPage.tsx —
// extracted so both places stay pixel-identical instead of two copies
// drifting apart. Always "Iniciar treino": starting now navigates straight
// into the real execution screen (WorkoutSession.tsx), so there's no
// "Finalizar treino" state to represent here anymore (finishing happens from
// within that screen, not by toggling this button back)
export default function RoutineWorkoutToggleButton({ onClick }: RoutineWorkoutToggleButtonProps) {
  const { t } = useTranslation('gym');
  return (
    <button
      type="button"
      onClick={onClick}
      className="press mt-3 flex w-full cursor-pointer items-center justify-center gap-2 rounded-[10px] bg-acc p-[12px] text-[14px] font-semibold text-acc-fg"
    >
      <Play className="h-4 w-4" strokeWidth={1.8} />
      {t('routines.startWorkout')}
    </button>
  );
}

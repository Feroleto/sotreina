import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ChevronRight, Dumbbell } from 'lucide-react';
import type { WorkoutDetail } from '@/lib/types';
import { DEFAULT_SET_COUNT } from './WorkoutExerciseCard';

interface ActiveWorkoutBarProps {
  workout: WorkoutDetail;
  /** mobile tab bar is showing — sit above the pill instead of the screen edge */
  aboveTabBar: boolean;
  onOpen: () => void;
}

function formatElapsed(totalSec: number): string {
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

// Persistent "mini player" for the active workout — rendered by App.tsx
// (mobile-only) on every page except gym/workouts itself, where
// WorkoutSession already fills the screen. Tapping it jumps straight back
// into the session, no confirmation; leaving it (the session's minimize
// button, or any tab) never touches the running workout underneath.
export default function ActiveWorkoutBar({
  workout,
  aboveTabBar,
  onOpen,
}: ActiveWorkoutBarProps) {
  const { t } = useTranslation('gym');
  const [elapsedSec, setElapsedSec] = useState(0);

  useEffect(() => {
    const startedAtMs = new Date(workout.startedAt).getTime();
    const tick = () =>
      setElapsedSec(Math.floor((Date.now() - startedAtMs) / 1000));
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [workout.startedAt]);

  // mirrors WorkoutExerciseCard's own "no target → 3 rows" fallback, so the
  // total shown here matches what the user sees once they open the session
  const totalSets = workout.exercises.reduce(
    (sum, we) => sum + (we.target?.sets ?? DEFAULT_SET_COUNT),
    0,
  );
  const completedSets = workout.exercises.reduce(
    (sum, we) => sum + we.sets.length,
    0,
  );

  return (
    <button
      type="button"
      onClick={onOpen}
      aria-label={t('activeBar.resume')}
      className={`fixed inset-x-3.5 ${
        aboveTabBar
          ? 'bottom-[calc(max(20px,env(safe-area-inset-bottom)+8px)+68px)]'
          : 'bottom-[calc(18px+env(safe-area-inset-bottom))]'
      } z-40 flex cursor-pointer items-center gap-3 rounded-2xl bg-acc px-4 py-3 text-left text-acc-fg shadow-[0_12px_28px_rgba(8,12,20,.28)] md:hidden`}
    >
      <span className="flex h-10 w-10 flex-none items-center justify-center rounded-full bg-black/10">
        <Dumbbell className="h-[18px] w-[18px]" strokeWidth={1.8} />
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-[14px] font-semibold">
          {workout.templateName ?? t('session.title')}
        </span>
        <span className="block truncate text-[11.5px] text-acc-fg/70">
          {t('activeBar.setsProgress', {
            done: completedSets,
            total: totalSets,
          })}
        </span>
      </span>
      <span className="flex-none text-[13px] font-semibold tabular-nums">
        {formatElapsed(elapsedSec)}
      </span>
      <ChevronRight className="h-4 w-4 flex-none" strokeWidth={1.8} />
    </button>
  );
}

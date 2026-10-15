import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, Check, Plus, Search } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import type { ExerciseListItem, ExercisesResponse } from '@/lib/types';

const SEARCH_DEBOUNCE_MS = 250;
const FETCH_LIMIT = 50;

type MuscleFilterId = 'all' | 'chest' | 'back' | 'legs' | 'shoulders' | 'arms' | 'core';

// coarse UI groups → real MuscleGroup enum values (backend OR-filters via
// primaryMuscles hasSome) — several of these map to more than one enum value,
// which is why this can't just reuse the single-value ?muscle= param
const MUSCLE_GROUPS: Record<Exclude<MuscleFilterId, 'all'>, string[]> = {
  chest: ['CHEST'],
  back: ['BACK', 'LATS', 'TRAPS', 'LOWER_BACK'],
  legs: ['QUADRICEPS', 'HAMSTRINGS', 'GLUTES', 'CALVES', 'ADDUCTORS', 'ABDUCTORS'],
  shoulders: ['SHOULDERS'],
  arms: ['BICEPS', 'TRICEPS', 'FOREARMS'],
  core: ['ABDOMINALS'],
};

const FILTER_CHIPS: MuscleFilterId[] = [
  'all',
  'chest',
  'back',
  'legs',
  'shoulders',
  'arms',
  'core',
];

interface RoutineExercisePickerProps {
  /** exerciseIds already in the routine, for the +/✓ badge state */
  selectedExerciseIds: Set<string>;
  /** running total across the whole routine, shown in the "{n} selecionados" line */
  totalSelectedCount: number;
  // toggling commits immediately (add or remove) — same "commit as you go"
  // model as the rest of the routine editor, not a batch applied on close
  onToggle: (exercise: ExerciseListItem) => void;
  onClose: () => void;
}

// mobile-only, full-screen exercise search — used by the routine builder
// (RoutineEditPage.tsx) and the mobile "add exercise" flow of the workout
// session (WorkoutSession.tsx, which keeps the plain ExercisePicker.tsx on
// desktop). Toggling an exercise already in the workout is a no-op there
// (no "remove exercise from workout" endpoint exists yet), unlike the
// routine editor where it removes it — the interaction model here is
// otherwise the same: multi-select with a running counter instead of
// pick-one-and-close
export default function RoutineExercisePicker({
  selectedExerciseIds,
  totalSelectedCount,
  onToggle,
  onClose,
}: RoutineExercisePickerProps) {
  const { t } = useTranslation('gym');
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<MuscleFilterId>('all');
  const [items, setItems] = useState<ExerciseListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    const handle = setTimeout(() => {
      const params = new URLSearchParams({ limit: String(FETCH_LIMIT) });
      if (search.trim()) params.set('search', search.trim());
      if (filter !== 'all') params.set('muscles', MUSCLE_GROUPS[filter].join(','));
      apiFetch(`/exercises?${params.toString()}`)
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.json() as Promise<ExercisesResponse>;
        })
        .then((data) => {
          if (!cancelled) setItems(data.items);
        })
        .catch(() => {
          if (!cancelled) setItems([]);
        })
        .finally(() => {
          if (!cancelled) setLoading(false);
        });
    }, SEARCH_DEBOUNCE_MS);
    return () => {
      cancelled = true;
      clearTimeout(handle);
    };
  }, [search, filter]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-page-bg md:hidden">
      <div className="flex items-center gap-3 border-b border-border bg-card px-[18px] pt-[calc(12px+env(safe-area-inset-top))] pb-3">
        <button
          type="button"
          onClick={onClose}
          aria-label={t('routines.back')}
          className="cursor-pointer text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" strokeWidth={1.8} />
        </button>
        <h1 className="flex-1 text-[16px] font-semibold text-foreground">
          {t('editor.addExercise')}
        </h1>
        <button
          type="button"
          onClick={onClose}
          className="cursor-pointer text-[13.5px] font-semibold text-acc-tx"
        >
          {t('editor.done')}
        </button>
      </div>

      <div className="px-[18px] pt-[14px] pb-[10px]">
        <div className="flex items-center gap-2 rounded-[10px] bg-chip px-3 py-[10px]">
          <Search className="h-4 w-4 flex-none text-muted-foreground" strokeWidth={1.8} />
          <input
            ref={inputRef}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t('picker.searchPlaceholder')}
            className="h-5 flex-1 bg-transparent text-[16px] text-foreground outline-none placeholder:text-muted-foreground"
          />
        </div>

        <div className="no-scrollbar -mx-[18px] mt-3 flex gap-[8px] overflow-x-auto px-[18px]">
          {FILTER_CHIPS.map((id) => (
            <button
              key={id}
              type="button"
              onClick={() => setFilter(id)}
              className={
                filter === id
                  ? 'flex-none cursor-pointer rounded-full bg-acc-bg px-3 py-[6px] text-[12.5px] font-semibold text-acc-tx'
                  : 'flex-none cursor-pointer rounded-full bg-chip px-3 py-[6px] text-[12.5px] font-medium text-muted-foreground'
              }
            >
              {t(`editor.muscleFilter.${id}`)}
            </button>
          ))}
        </div>

        <div className="mt-3 text-[11.5px] text-muted-foreground">
          {t('editor.selectedCount', { count: totalSelectedCount })}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto overscroll-contain px-[18px] pb-[calc(18px+env(safe-area-inset-bottom))]">
        {loading && (
          <p className="py-8 text-center text-[13px] text-muted-foreground">
            {t('picker.loading')}
          </p>
        )}
        {!loading && items.length === 0 && (
          <p className="py-8 text-center text-[13px] text-muted-foreground">{t('picker.empty')}</p>
        )}
        {!loading &&
          items.map((ex) => {
            const selected = selectedExerciseIds.has(ex.id);
            return (
              <button
                key={ex.id}
                type="button"
                onClick={() => onToggle(ex)}
                className="flex w-full cursor-pointer items-center gap-[12px] border-b border-border p-[12px_2px] text-left"
              >
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-semibold text-foreground">
                    {ex.name}
                  </div>
                  {ex.primaryMuscles[0] && (
                    <div className="mt-0.5 truncate text-[11.5px] text-muted-foreground">
                      {t(`muscles.${ex.primaryMuscles[0]}`, ex.primaryMuscles[0])}
                    </div>
                  )}
                </div>
                <span
                  className={
                    selected
                      ? 'flex h-[26px] w-[26px] flex-none items-center justify-center rounded-full bg-acc'
                      : 'flex h-[26px] w-[26px] flex-none items-center justify-center rounded-full bg-chip'
                  }
                >
                  {selected ? (
                    <Check className="h-3.5 w-3.5 text-white" strokeWidth={2.2} />
                  ) : (
                    <Plus className="h-3.5 w-3.5 text-muted-foreground" strokeWidth={2.2} />
                  )}
                </span>
              </button>
            );
          })}
      </div>
    </div>
  );
}

import { useState } from 'react';
import type { CSSProperties } from 'react';
import { useTranslation } from 'react-i18next';
import { Check, ChevronDown, ChevronUp, Pencil, Plus, Settings, Trash2 } from 'lucide-react';
import type { Meal, MealType } from '@/lib/types';
import { currentIntlLocale } from '@/lib/dateLocale';
import { useFoodLogs, localDateString } from './useFoodLogs';
import { useNutritionGoal } from './useNutritionGoal';
import { useMeals } from './useMeals';
import { MACRO_COLORS, capitalize } from './constants';
import NutritionRing from './components/NutritionRing';
import MacroBar from './components/MacroBar';
import MealTypePicker from './components/MealTypePicker';
import AddMealPage from './AddMealPage';
import GoalPage from './GoalPage';
import DrillStack from '@/components/DrillStack';
import { useEntrance } from '@/lib/useEntrance';
import { LoadingSwap, Skeleton } from '@/components/Skeleton';

type View = { name: 'overview' } | { name: 'addMeal'; meal: Meal } | { name: 'goal' };

// the picker doubles as "add a meal" and "rename this one"
type Picker = { mode: 'add' } | { mode: 'rename'; meal: Meal };

function formatDayHeader(date: string): string {
  const d = new Date(`${date}T00:00:00`);
  const text = d.toLocaleDateString(currentIntlLocale(), {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  });
  return capitalize(text);
}

// mirrors the loaded layout: ring + macro bars card, then the meals card
function OverviewSkeleton() {
  return (
    <>
      <div className="mt-5 flex flex-col items-center rounded-[16px] border border-border bg-card p-[22px]">
        <Skeleton className="h-[176px] w-[176px] rounded-full" />
        <Skeleton className="mt-4 h-[13px] w-[120px]" />
        <div className="mt-5 flex w-full flex-col gap-4">
          {[0, 1, 2].map((i) => (
            <div key={i}>
              <Skeleton className="h-[11px] w-[30%]" />
              <Skeleton className="mt-1.5 h-[7px] rounded-full" />
            </div>
          ))}
        </div>
      </div>
      <Skeleton className="mt-6 mb-2 ml-1 h-[14px] w-[130px]" />
      <div className="rounded-[14px] border border-border bg-card">
        {[0, 1, 2, 3, 4].map((i) => (
          <div
            key={i}
            className={`flex items-center gap-3 px-4 py-[14px] ${i > 0 ? 'border-t border-border' : ''}`}
          >
            <div className="flex-1">
              <Skeleton className="h-[13px] w-[35%]" />
              <Skeleton className="mt-1.5 h-[10px] w-[25%]" />
            </div>
            <Skeleton className="h-8 w-8 flex-none rounded-full" />
          </div>
        ))}
      </div>
    </>
  );
}

export default function DietOverviewPage() {
  const { t } = useTranslation('diet');
  const [view, setView] = useState<View>({ name: 'overview' });
  const [refreshKey, setRefreshKey] = useState(0);
  const date = localDateString();
  const { logs, summary, loading } = useFoodLogs(date, refreshKey);
  const { goal, save: saveGoal } = useNutritionGoal();
  const { meals, loading: mealsLoading, reload: reloadMeals, add, rename, reorder, remove } =
    useMeals();
  const [editing, setEditing] = useState(false);
  const [picker, setPicker] = useState<Picker | null>(null);
  const [confirmingDeleteId, setConfirmingDeleteId] = useState<string | null>(null);

  const totalKcal = summary?.totalKcal ?? 0;
  const kcalGoal = goal?.dailyKcalGoal ?? 2000;
  const remaining = Math.round(kcalGoal - totalKcal);
  // same "over" rule as NutritionRing (value > max) — not remaining < 0,
  // whose rounding would disagree with the ring right at the goal
  const overGoal = totalKcal > kcalGoal;

  // the server derives `order` from array position, so moving one meal means
  // sending the whole reordered list, not a delta
  const move = (index: number, delta: number) => {
    const next = [...meals];
    const [moved] = next.splice(index, 1);
    next.splice(index + delta, 0, moved);
    void reorder(next.map((m) => m.id));
  };

  // first load only — refreshes after a save keep the current numbers on
  // screen instead of flashing the skeleton again
  const firstLoad = (loading && summary == null) || (mealsLoading && meals.length === 0);
  // ring/macro fills sweep in and the meal rows rise, once per session
  const { attach: enterRef, state: enterState } = useEntrance('diet/overview', { ready: !firstLoad });

  const kcalOf = (mealId: string) =>
    Math.round(
      logs
        .filter((l) => l.mealId === mealId)
        .reduce((sum, l) => sum + (l.food.kcal * l.quantity) / 100, 0),
    );

  const detail =
    view.name === 'addMeal' ? (
        <AddMealPage
          meal={view.meal}
          existingLogs={logs.filter((l) => l.mealId === view.meal.id)}
          onBack={() => setView({ name: 'overview' })}
          onSaved={() => {
            setRefreshKey((k) => k + 1);
            // logCount is computed server-side at fetch time, so the delete
            // confirmation would under-report without this
            void reloadMeals();
            setView({ name: 'overview' });
          }}
        />
    ) : view.name === 'goal' && goal ? (
        <GoalPage
          goal={goal}
          onBack={() => setView({ name: 'overview' })}
          onSave={async (next) => {
            await saveGoal(next);
            setView({ name: 'overview' });
          }}
        />
    ) : null;

  return (
    <DrillStack
      depth={detail ? 1 : 0}
      viewKey={view.name === 'addMeal' ? `addMeal:${view.meal.id}` : detail ? view.name : 'overview'}
    >
      {detail ?? (
        <div ref={enterRef} data-enter={enterState} className="px-5 pt-[76px] pb-8">
          <div className="flex items-start justify-between">
            <div>
              <h1 className="text-[25px] font-bold tracking-[-.02em] text-foreground">
                {t('overview.title')}
              </h1>
              <p className="mt-0.5 text-[12.5px] text-muted-foreground">{formatDayHeader(date)}</p>
            </div>
            <button
              type="button"
              onClick={() => setView({ name: 'goal' })}
              aria-label={t('overview.editGoal')}
              className="flex h-9 w-9 flex-none cursor-pointer items-center justify-center rounded-[10px] text-muted-foreground hover:bg-chip hover:text-foreground"
            >
              <Settings className="h-[18px] w-[18px]" strokeWidth={1.8} />
            </button>
          </div>

          <LoadingSwap loading={firstLoad} skeleton={<OverviewSkeleton />}>
            <div className="mt-5 flex flex-col items-center rounded-[16px] border border-border bg-card p-[22px]">
              <NutritionRing value={totalKcal} max={kcalGoal}>
                <span className="text-[30px] font-bold tabular-nums tracking-[-.02em] text-foreground">
                  {Math.round(totalKcal)}
                </span>
                <span className="mt-0.5 text-[11.5px] text-muted-foreground">
                  {t('overview.ofGoal', { kcal: kcalGoal })}
                </span>
              </NutritionRing>
              <p
                className={`mt-3 text-[13px] font-semibold ${overGoal ? 'text-neg' : 'text-acc'}`}
              >
                {overGoal
                  ? t('overview.overGoal', { kcal: Math.ceil(totalKcal - kcalGoal) })
                  : t('overview.remaining', { kcal: remaining })}
              </p>

              <div className="mt-5 flex w-full flex-col gap-3">
                <MacroBar
                  label={t('macro.protein')}
                  value={summary?.totalProtein ?? 0}
                  max={goal?.dailyProteinGoal ?? 150}
                  color={MACRO_COLORS.protein}
                />
                <MacroBar
                  label={t('macro.carbs')}
                  value={summary?.totalCarbs ?? 0}
                  max={goal?.dailyCarbsGoal ?? 250}
                  color={MACRO_COLORS.carbs}
                />
                <MacroBar
                  label={t('macro.fat')}
                  value={summary?.totalFat ?? 0}
                  max={goal?.dailyFatGoal ?? 65}
                  color={MACRO_COLORS.fat}
                />
              </div>
            </div>

            <div className="mt-6">
              <div className="mb-2 flex items-center justify-between px-1">
                <span className="text-[14px] font-semibold text-foreground">
                  {t('overview.mealsTitle')}
                </span>
                <button
                  type="button"
                  onClick={() => {
                    setEditing((v) => !v);
                    setConfirmingDeleteId(null);
                  }}
                  aria-label={editing ? t('meals.done') : t('meals.editMeals')}
                  className="flex h-9 w-9 flex-none cursor-pointer items-center justify-center rounded-[10px] text-muted-foreground hover:bg-chip hover:text-foreground"
                >
                  {editing ? (
                    <Check className="h-[18px] w-[18px] text-acc" strokeWidth={2} />
                  ) : (
                    <Pencil className="h-[16px] w-[16px]" strokeWidth={1.8} />
                  )}
                </button>
              </div>

              <div className="rounded-[14px] border border-border bg-card">
                {meals.map((meal, i) => {
                  const count = logs.filter((l) => l.mealId === meal.id).length;
                  const kcal = kcalOf(meal.id);
                  const divider = i > 0 ? 'border-t border-border' : '';

                  if (!editing) {
                    return (
                      <button
                        key={meal.id}
                        type="button"
                        onClick={() => setView({ name: 'addMeal', meal })}
                        className={`enter-rise flex w-full cursor-pointer items-center gap-3 px-4 py-3 text-left hover:bg-chip ${divider}`}
                        style={{ '--i': i } as CSSProperties}
                      >
                        <div className="min-w-0 flex-1">
                          <div className="text-[14px] font-semibold text-foreground">
                            {t(`meal.${meal.type}`)}
                          </div>
                          <div className="text-[11.5px] text-muted-foreground">
                            {t('overview.items', { count })} · {kcal} {t('addMeal.kcal')}
                          </div>
                        </div>
                        <span className="text-[13px] font-semibold tabular-nums text-foreground">
                          {kcal}
                        </span>
                        <span
                          aria-hidden
                          className="flex h-[26px] w-[26px] flex-none items-center justify-center rounded-full bg-chip text-acc"
                        >
                          <Plus className="h-3.5 w-3.5" strokeWidth={2.2} />
                        </span>
                      </button>
                    );
                  }

                  return (
                    <div key={meal.id} className={`px-4 py-3 ${divider}`}>
                      <div className="flex items-center gap-1">
                        <div className="min-w-0 flex-1">
                          <div className="text-[14px] font-semibold text-foreground">
                            {t(`meal.${meal.type}`)}
                          </div>
                          <div className="text-[11.5px] text-muted-foreground">
                            {t('overview.items', { count })}
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={() => move(i, -1)}
                          disabled={i === 0}
                          aria-label={t('meals.moveUp')}
                          className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-[8px] text-muted-foreground hover:bg-chip hover:text-foreground disabled:cursor-default disabled:opacity-30 disabled:hover:bg-transparent"
                        >
                          <ChevronUp className="h-4 w-4" strokeWidth={1.8} />
                        </button>
                        <button
                          type="button"
                          onClick={() => move(i, 1)}
                          disabled={i === meals.length - 1}
                          aria-label={t('meals.moveDown')}
                          className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-[8px] text-muted-foreground hover:bg-chip hover:text-foreground disabled:cursor-default disabled:opacity-30 disabled:hover:bg-transparent"
                        >
                          <ChevronDown className="h-4 w-4" strokeWidth={1.8} />
                        </button>
                        <button
                          type="button"
                          onClick={() => setPicker({ mode: 'rename', meal })}
                          aria-label={t('meals.renameTitle')}
                          className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-[8px] text-muted-foreground hover:bg-chip hover:text-foreground"
                        >
                          <Pencil className="h-3.5 w-3.5" strokeWidth={1.8} />
                        </button>
                        <button
                          type="button"
                          onClick={() => setConfirmingDeleteId(meal.id)}
                          disabled={meals.length === 1}
                          title={meals.length === 1 ? t('meals.lastMealHint') : undefined}
                          aria-label={t('meals.remove')}
                          className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-[8px] text-muted-foreground hover:bg-chip hover:text-foreground disabled:cursor-default disabled:opacity-30 disabled:hover:bg-transparent"
                        >
                          <Trash2 className="h-3.5 w-3.5" strokeWidth={1.8} />
                        </button>
                      </div>

                      {confirmingDeleteId === meal.id && (
                        <div className="mt-3 flex flex-wrap items-center justify-between gap-2 rounded-[9px] bg-chip px-3 py-2">
                          <span className="text-[12px] text-foreground">
                            {meal.logCount > 0
                              ? t('meals.deleteConfirm', { count: meal.logCount })
                              : t('meals.deleteConfirmEmpty')}
                          </span>
                          <div className="flex flex-none items-center gap-2">
                            <button
                              type="button"
                              onClick={() => setConfirmingDeleteId(null)}
                              className="cursor-pointer rounded-[7px] px-2 py-1 text-[12px] font-medium text-muted-foreground hover:text-foreground"
                            >
                              {t('savedMeals.cancel')}
                            </button>
                            <button
                              type="button"
                              onClick={() => {
                                setConfirmingDeleteId(null);
                                void remove(meal.id).then(() => setRefreshKey((k) => k + 1));
                              }}
                              className="cursor-pointer rounded-[7px] bg-neg/10 px-2 py-1 text-[12px] font-semibold text-neg hover:bg-neg/20"
                            >
                              {t('meals.remove')}
                            </button>
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })}

                {!mealsLoading && meals.length === 0 && (
                  <p className="px-4 py-6 text-center text-[13px] text-muted-foreground">
                    {t('meals.empty')}
                  </p>
                )}
              </div>

              {editing && (
                <button
                  type="button"
                  onClick={() => setPicker({ mode: 'add' })}
                  className="mt-3 flex w-full cursor-pointer items-center justify-center gap-1.5 rounded-[11px] border border-dashed border-border py-3 text-[13.5px] font-medium text-acc hover:bg-chip"
                >
                  <Plus className="h-4 w-4" strokeWidth={2} />
                  {t('meals.add')}
                </button>
              )}
            </div>
          </LoadingSwap>

          {picker && (
            <MealTypePicker
              title={picker.mode === 'add' ? t('meals.addTitle') : t('meals.renameTitle')}
              initialType={picker.mode === 'rename' ? picker.meal.type : undefined}
              confirmLabel={picker.mode === 'add' ? t('meals.add') : t('meals.save')}
              onCancel={() => setPicker(null)}
              onConfirm={(type: MealType) => {
                const p = picker;
                setPicker(null);
                void (p.mode === 'add' ? add(type) : rename(p.meal.id, type));
              }}
            />
          )}

          {!loading && (
            <p className="mt-8 px-1 text-center text-[10.5px] leading-[1.5] text-muted-foreground">
              {t('attribution')}
            </p>
          )}
        </div>
      )}
    </DrillStack>
  );
}

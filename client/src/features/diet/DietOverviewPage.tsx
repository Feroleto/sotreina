import { useState } from 'react';
import type { CSSProperties } from 'react';
import { useTranslation } from 'react-i18next';
import { Check, ChevronDown, ChevronUp, Pencil, Plus, Settings, Trash2 } from 'lucide-react';
import type { Meal, MealType } from '@/lib/types';
import { currentIntlLocale } from '@/lib/dateLocale';
import { useFoodLogs, localDateString } from './useFoodLogs';
import { useNutritionGoal } from './useNutritionGoal';
import { useMeals } from './useMeals';
import { capitalize } from './constants';
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

// mirrors the loaded layout: kcal hero, macro strip, meal rows
function OverviewSkeleton() {
  return (
    <>
      <Skeleton className="mt-[22px] h-[64px] w-[55%]" />
      <Skeleton className="mt-3 h-[12px] w-[60%]" />
      <Skeleton className="mt-[7px] h-[3px]" />
      <div className="mt-[22px] grid grid-cols-3 border-y border-border">
        {[0, 1, 2].map((i) => (
          <div key={i} className={i ? 'border-l border-border py-3.5 pl-3' : 'py-3.5 pr-3'}>
            <Skeleton className="h-[11px] w-[55%]" />
            <Skeleton className="mt-2 h-[20px] w-[70%]" />
            <Skeleton className="mt-2 h-[3px]" />
          </div>
        ))}
      </div>
      <Skeleton className="mt-6 mb-2 h-[14px] w-[110px]" />
      {[0, 1, 2, 3, 4].map((i) => (
        <div key={i} className="flex items-center gap-3 border-b border-border py-[13px]">
          <div className="flex-1">
            <Skeleton className="h-[13px] w-[35%]" />
            <Skeleton className="mt-1.5 h-[10px] w-[20%]" />
          </div>
          <Skeleton className="h-[30px] w-[30px] flex-none rounded-full" />
        </div>
      ))}
    </>
  );
}

// one column of the macro strip — Redesign 18c: macros share the accent,
// told apart by opacity (protein 1 → carbs .7 → fat .45), not by hue
function MacroStat({
  label,
  value,
  goal,
  opacity,
  position,
}: {
  label: string;
  value: number;
  goal: number;
  opacity: number;
  position: 'first' | 'middle' | 'last';
}) {
  const pct = goal > 0 ? Math.min(100, (value / goal) * 100) : 0;
  return (
    <div
      className={
        position === 'first'
          ? 'py-3.5 pr-3'
          : `border-l border-border py-3.5 ${position === 'middle' ? 'px-3' : 'pl-3'}`
      }
    >
      <div className="text-[12px] text-muted-foreground">{label}</div>
      <div className="mt-1 font-mono text-[20px] font-medium text-foreground">
        {Math.round(value)}
        <span className="text-[12px] text-muted-foreground"> / {Math.round(goal)}g</span>
      </div>
      <div className="mt-2 h-[3px] rounded-[2px] bg-border">
        <div
          className="macro-fill h-full bg-acc"
          style={{ clipPath: `inset(0 ${100 - pct}% 0 0 round 2px)`, opacity }}
        />
      </div>
    </div>
  );
}

export default function DietOverviewPage() {
  const { t } = useTranslation('diet');
  const [view, setView] = useState<View>({ name: 'overview' });
  const [refreshKey, setRefreshKey] = useState(0);
  const date = localDateString();
  const { logs, summary, loading } = useFoodLogs(date, refreshKey);
  const { goal, save: saveGoal } = useNutritionGoal();
  const {
    meals,
    loading: mealsLoading,
    reload: reloadMeals,
    add,
    rename,
    reorder,
    remove,
  } = useMeals();
  const [editing, setEditing] = useState(false);
  const [picker, setPicker] = useState<Picker | null>(null);
  const [confirmingDeleteId, setConfirmingDeleteId] = useState<string | null>(null);

  const totalKcal = summary?.totalKcal ?? 0;
  const kcalGoal = goal?.dailyKcalGoal ?? 2000;
  const remaining = Math.round(kcalGoal - totalKcal);
  // strict value > goal, same rule as DietHistoryPage's bars — not
  // remaining < 0, whose rounding would disagree right at the goal
  const overGoal = totalKcal > kcalGoal;
  const kcalPct = kcalGoal > 0 ? Math.round((totalKcal / kcalGoal) * 100) : 0;
  const nf = new Intl.NumberFormat(currentIntlLocale());

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
  // progress fills sweep in and the meal rows rise, once per session
  const { attach: enterRef, state: enterState } = useEntrance('diet/overview', {
    ready: !firstLoad,
  });

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
      viewKey={
        view.name === 'addMeal' ? `addMeal:${view.meal.id}` : detail ? view.name : 'overview'
      }
    >
      {detail ?? (
        <div
          ref={enterRef}
          data-enter={enterState}
          className="px-[22px] pt-3 pb-8 tabular-nums md:max-w-[640px] md:p-[30px_34px_34px]"
        >
          {/* on mobile the "Dieta" title lives in the header (MobileChrome) */}
          <h1 className="hidden text-[19px] font-semibold tracking-[-.01em] text-foreground md:block">
            {t('overview.title')}
          </h1>
          <div className="flex items-center justify-between gap-3">
            <p className="text-[13px] text-muted-foreground md:mt-[2px]">{formatDayHeader(date)}</p>
            <button
              type="button"
              onClick={() => setView({ name: 'goal' })}
              aria-label={t('overview.editGoal')}
              className="-mr-2.5 flex h-11 w-11 flex-none cursor-pointer items-center justify-center rounded-[10px] text-muted-foreground hover:bg-chip hover:text-foreground"
            >
              <Settings className="h-[18px] w-[18px]" strokeWidth={1.8} />
            </button>
          </div>

          <LoadingSwap loading={firstLoad} skeleton={<OverviewSkeleton />}>
            <div className="mt-3 flex items-baseline gap-2">
              <span className="font-mono text-[64px] leading-none font-medium tracking-[-.05em] text-foreground">
                {nf.format(Math.round(totalKcal))}
              </span>
              <span className="text-[17px] text-muted-foreground">{t('addMeal.kcal')}</span>
            </div>
            <div className="mt-3 flex justify-between gap-3 text-[12.5px] text-muted-foreground">
              <span className={overGoal ? 'text-neg' : undefined}>
                {t('overview.goalLine', { kcal: nf.format(kcalGoal) })} ·{' '}
                {overGoal
                  ? t('overview.overGoal', {
                      kcal: nf.format(Math.ceil(totalKcal - kcalGoal)),
                    })
                  : t('overview.remaining', { kcal: nf.format(remaining) })}
              </span>
              <span className="font-medium text-foreground">{kcalPct}%</span>
            </div>
            <div className="mt-[7px] h-[3px] rounded-[2px] bg-border">
              <div
                className={`macro-fill h-full ${overGoal ? 'bg-neg' : 'bg-acc'}`}
                style={{
                  clipPath: `inset(0 ${100 - Math.min(100, kcalPct)}% 0 0 round 2px)`,
                }}
              />
            </div>

            <div className="mt-[22px] grid grid-cols-3 border-y border-border">
              <MacroStat
                position="first"
                label={t('macro.protein')}
                value={summary?.totalProtein ?? 0}
                goal={goal?.dailyProteinGoal ?? 150}
                opacity={1}
              />
              <MacroStat
                position="middle"
                label={t('macro.carbs')}
                value={summary?.totalCarbs ?? 0}
                goal={goal?.dailyCarbsGoal ?? 250}
                opacity={0.7}
              />
              <MacroStat
                position="last"
                label={t('macro.fat')}
                value={summary?.totalFat ?? 0}
                goal={goal?.dailyFatGoal ?? 65}
                opacity={0.45}
              />
            </div>

            <div className="mt-6">
              <div className="flex items-center justify-between">
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
                  className="-mr-2.5 flex h-11 w-11 flex-none cursor-pointer items-center justify-center rounded-[10px] text-muted-foreground hover:bg-chip hover:text-foreground"
                >
                  {editing ? (
                    <Check className="h-[18px] w-[18px] text-acc-tx" strokeWidth={2} />
                  ) : (
                    <Pencil className="h-[16px] w-[16px]" strokeWidth={1.8} />
                  )}
                </button>
              </div>

              <div>
                {meals.map((meal, i) => {
                  const count = logs.filter((l) => l.mealId === meal.id).length;
                  const kcal = kcalOf(meal.id);
                  const divider = 'border-b border-border';

                  if (!editing) {
                    return (
                      <button
                        key={meal.id}
                        type="button"
                        onClick={() => setView({ name: 'addMeal', meal })}
                        className={`enter-rise flex w-full cursor-pointer items-center gap-3 py-[13px] text-left ${divider}`}
                        style={{ '--i': i } as CSSProperties}
                      >
                        <div className="min-w-0 flex-1">
                          <div className="text-[14.5px] font-medium text-foreground">
                            {t(`meal.${meal.type}`)}
                          </div>
                          <div className="mt-0.5 text-[12px] text-muted-foreground">
                            {count > 0 ? t('overview.items', { count }) : t('overview.noItems')}
                          </div>
                        </div>
                        <span
                          className={`font-mono text-[14.5px] font-medium ${
                            count > 0 ? 'text-foreground' : 'text-muted-foreground'
                          }`}
                        >
                          {count > 0 ? nf.format(kcal) : '—'}
                        </span>
                        <span
                          aria-hidden
                          className="flex h-[30px] w-[30px] flex-none items-center justify-center rounded-full bg-chip text-acc-tx"
                        >
                          <Plus className="h-3 w-3" strokeWidth={2.2} />
                        </span>
                      </button>
                    );
                  }

                  return (
                    <div key={meal.id} className={`py-2.5 ${divider}`}>
                      <div className="flex items-center gap-1">
                        <div className="min-w-0 flex-1">
                          <div className="text-[14.5px] font-medium text-foreground">
                            {t(`meal.${meal.type}`)}
                          </div>
                          <div className="mt-0.5 text-[12px] text-muted-foreground">
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
                              ? t('meals.deleteConfirm', {
                                  count: meal.logCount,
                                })
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
                  <p className="border-b border-border py-6 text-center text-[13px] text-muted-foreground">
                    {t('meals.empty')}
                  </p>
                )}
              </div>

              {editing && (
                <button
                  type="button"
                  onClick={() => setPicker({ mode: 'add' })}
                  className="mt-3 flex w-full cursor-pointer items-center justify-center gap-1.5 rounded-[11px] border border-dashed border-border py-3 text-[13.5px] font-medium text-acc-tx hover:bg-chip"
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

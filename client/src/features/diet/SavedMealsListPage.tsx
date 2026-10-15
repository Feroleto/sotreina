import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ChevronLeft, Pencil, Plus, Trash2 } from 'lucide-react';
import type { SavedMealSummary } from '@/lib/types';
import { useSavedMeals } from './useSavedMeals';

interface SavedMealsListPageProps {
  onBack: () => void;
  onUse: (meal: SavedMealSummary) => void;
  onEdit: (mealId: string) => void;
  onCreateNew: () => void;
  applying: boolean;
}

export default function SavedMealsListPage({
  onBack,
  onUse,
  onEdit,
  onCreateNew,
  applying,
}: SavedMealsListPageProps) {
  const { t } = useTranslation('diet');
  const { meals, loading, remove } = useSavedMeals();
  const [confirmingDeleteId, setConfirmingDeleteId] = useState<string | null>(null);

  return (
    <div className="px-5 pt-[18px] pb-[44px]">
      <div className="mb-4 flex items-center gap-3">
        <button
          type="button"
          onClick={onBack}
          aria-label={t('addMeal.back')}
          className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-[9px] text-muted-foreground hover:bg-chip hover:text-foreground"
        >
          <ChevronLeft className="h-4.5 w-4.5" strokeWidth={1.8} />
        </button>
        <h1 className="min-w-0 flex-1 truncate text-[18px] font-semibold text-foreground">
          {t('savedMeals.listTitle')}
        </h1>
      </div>

      {loading && <p className="text-[13px] text-muted-foreground">{t('addMeal.loading')}</p>}

      {!loading && meals.length === 0 && (
        <p className="py-6 text-center text-[13px] text-muted-foreground">
          {t('savedMeals.empty')}
        </p>
      )}

      <div className="flex flex-col gap-2">
        {meals.map((meal) => (
          <div key={meal.id} className="rounded-[12px] border border-border bg-card p-3.5">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0 flex-1">
                <div className="truncate text-[14px] font-semibold text-foreground">
                  {meal.name}
                </div>
                <div className="truncate text-[11.5px] text-muted-foreground">
                  {meal.itemCount > 0
                    ? meal.itemPreview.join(', ')
                    : t('savedMeals.noItems')}
                </div>
                <div className="mt-0.5 text-[11.5px] text-muted-foreground">
                  {Math.round(meal.totalKcal)} {t('addMeal.kcal')}
                </div>
              </div>
              <div className="flex flex-none items-center gap-1">
                <button
                  type="button"
                  onClick={() => onEdit(meal.id)}
                  aria-label={t('savedMeals.edit')}
                  className="flex h-8 w-8 cursor-pointer items-center justify-center rounded-[8px] text-muted-foreground hover:bg-chip hover:text-foreground"
                >
                  <Pencil className="h-3.5 w-3.5" strokeWidth={1.8} />
                </button>
                <button
                  type="button"
                  onClick={() => setConfirmingDeleteId(meal.id)}
                  aria-label={t('savedMeals.delete')}
                  className="flex h-8 w-8 cursor-pointer items-center justify-center rounded-[8px] text-muted-foreground hover:bg-chip hover:text-foreground"
                >
                  <Trash2 className="h-3.5 w-3.5" strokeWidth={1.8} />
                </button>
              </div>
            </div>

            {confirmingDeleteId === meal.id ? (
              <div className="mt-3 flex items-center justify-between gap-3 rounded-[9px] bg-chip px-3 py-2">
                <span className="text-[12px] text-foreground">{t('savedMeals.deleteConfirm')}</span>
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
                      void remove(meal.id);
                    }}
                    className="cursor-pointer rounded-[7px] bg-neg/10 px-2 py-1 text-[12px] font-semibold text-neg hover:bg-neg/20"
                  >
                    {t('savedMeals.delete')}
                  </button>
                </div>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => onUse(meal)}
                disabled={applying || meal.itemCount === 0}
                className="press mt-3 w-full cursor-pointer rounded-[9px] bg-acc py-2 text-[13px] font-semibold text-white disabled:cursor-default disabled:opacity-50"
              >
                {t('savedMeals.use')}
              </button>
            )}
          </div>
        ))}
      </div>

      <button
        type="button"
        onClick={onCreateNew}
        className="mt-4 flex w-full cursor-pointer items-center justify-center gap-1.5 rounded-[11px] border border-dashed border-border py-3 text-[13.5px] font-medium text-acc hover:bg-chip"
      >
        <Plus className="h-4 w-4" strokeWidth={2} />
        {t('savedMeals.createNew')}
      </button>
    </div>
  );
}

import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ChevronLeft, Plus, Search, X } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import type { FoodListItem } from '@/lib/types';
import { currentIntlLocale } from '@/lib/dateLocale';
import { useSavedMealEditor, type WorkingMealItem } from './useSavedMealEditor';
import QuantitySheet from './components/QuantitySheet';
import { defaultPortion, formatQuantity, kcalForQuantity } from './quantityFormat';

const SEARCH_DEBOUNCE_MS = 250;

interface SavedMealEditPageProps {
  mealId: string | null;
  initialItems: WorkingMealItem[];
  onBack: () => void;
  onSaved: () => void;
}

export default function SavedMealEditPage({
  mealId,
  initialItems,
  onBack,
  onSaved,
}: SavedMealEditPageProps) {
  const { t } = useTranslation('diet');
  const locale = currentIntlLocale();
  const editor = useSavedMealEditor(mealId, initialItems);
  const [search, setSearch] = useState('');
  const [results, setResults] = useState<FoodListItem[]>([]);
  const [searching, setSearching] = useState(false);
  const [confirmingBack, setConfirmingBack] = useState(false);
  // key of the item whose quantity is being edited — the sheet is input-only
  // here, since SavedMealItem stores grams with no unit column
  const [editingKey, setEditingKey] = useState<string | null>(null);
  const editingItem = editor.items.find((i) => i.key === editingKey) ?? null;

  useEffect(() => {
    if (!search.trim()) {
      setResults([]);
      setSearching(false);
      return;
    }
    let cancelled = false;
    setSearching(true);
    const handle = setTimeout(() => {
      apiFetch(`/foods/search?q=${encodeURIComponent(search.trim())}`)
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.json() as Promise<FoodListItem[]>;
        })
        .then((data) => {
          if (!cancelled) setResults(data);
        })
        .catch(() => {
          if (!cancelled) setResults([]);
        })
        .finally(() => {
          if (!cancelled) setSearching(false);
        });
    }, SEARCH_DEBOUNCE_MS);
    return () => {
      cancelled = true;
      clearTimeout(handle);
    };
  }, [search]);

  const handleBack = () => {
    if (editor.isDirty && !confirmingBack) {
      setConfirmingBack(true);
      return;
    }
    onBack();
  };

  const handleSave = async () => {
    const saved = await editor.save();
    if (saved) onSaved();
  };

  const totalKcal = editor.items.reduce((sum, i) => sum + kcalForQuantity(i.food, i.quantity), 0);

  if (editor.loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-[13px] text-muted-foreground">{t('addMeal.loading')}</p>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col">
      <div className="flex items-center gap-3 border-b border-border px-5 py-3.5">
        <button
          type="button"
          onClick={handleBack}
          aria-label={t('addMeal.back')}
          className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-[9px] text-muted-foreground hover:bg-chip hover:text-foreground"
        >
          <ChevronLeft className="h-4.5 w-4.5" strokeWidth={1.8} />
        </button>
        <div className="min-w-0 flex-1 truncate text-[15px] font-semibold text-foreground">
          {editor.isEdit ? t('savedMeals.editTitle') : t('savedMeals.newTitle')}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-5 pt-4 pb-[88px]">
        {confirmingBack && (
          <div className="mb-4 flex items-center justify-between gap-3 rounded-[10px] border border-border bg-chip px-3.5 py-2.5">
            <span className="text-[12.5px] text-foreground">{t('savedMeals.discardConfirm')}</span>
            <div className="flex flex-none items-center gap-2">
              <button
                type="button"
                onClick={() => setConfirmingBack(false)}
                className="cursor-pointer rounded-[8px] px-2.5 py-1 text-[12px] font-medium text-muted-foreground hover:text-foreground"
              >
                {t('savedMeals.cancel')}
              </button>
              <button
                type="button"
                onClick={onBack}
                className="cursor-pointer rounded-[8px] bg-neg/10 px-2.5 py-1 text-[12px] font-semibold text-neg hover:bg-neg/20"
              >
                {t('savedMeals.discard')}
              </button>
            </div>
          </div>
        )}

        <label className="flex flex-col gap-1">
          <span className="text-[12.5px] font-medium text-muted-foreground">
            {t('savedMeals.nameLabel')}
          </span>
          <input
            autoFocus={!editor.isEdit}
            value={editor.name}
            onChange={(e) => editor.setName(e.target.value)}
            placeholder={t('savedMeals.namePlaceholder')}
            className="w-full rounded-[11px] border border-border bg-transparent px-3.5 py-[11px] text-[16px] text-foreground outline-none placeholder:text-muted-foreground focus:border-acc md:text-[14px]"
          />
        </label>

        <div className="mt-5">
          <div className="mb-1.5 px-1 text-[11.5px] font-semibold tracking-[.05em] text-muted-foreground uppercase">
            {t('savedMeals.itemsTitle')}
          </div>
          {editor.items.length === 0 ? (
            <p className="px-1 py-4 text-[13px] text-muted-foreground">
              {t('savedMeals.noItems')}
            </p>
          ) : (
            <div className="flex flex-col gap-1">
              {editor.items.map((item) => (
                <div
                  key={item.key}
                  className="flex min-h-[52px] items-center gap-2 rounded-[10px] px-3 py-2 hover:bg-chip"
                >
                  <button
                    type="button"
                    onClick={() => setEditingKey(item.key)}
                    aria-label={t('savedMeals.quantityLabel')}
                    className="min-w-0 flex-1 cursor-pointer text-left"
                  >
                    <div className="truncate text-[14px] font-medium text-foreground">
                      {item.food.name}
                    </div>
                    <div className="text-[11.5px] text-muted-foreground">
                      {formatQuantity(item.food, item.quantity, false, t, locale)} ·{' '}
                      {Math.round(kcalForQuantity(item.food, item.quantity))} {t('addMeal.kcal')}
                    </div>
                  </button>
                  <button
                    type="button"
                    onClick={() => editor.removeFood(item.key)}
                    aria-label={t('addMeal.remove')}
                    className="flex h-7 w-7 flex-none cursor-pointer items-center justify-center rounded-[7px] text-muted-foreground hover:bg-grid-ax hover:text-foreground"
                  >
                    <X className="h-3.5 w-3.5" strokeWidth={1.8} />
                  </button>
                </div>
              ))}
              <div className="px-3 pt-1 text-[12px] font-medium text-muted-foreground">
                {Math.round(totalKcal)} {t('addMeal.kcal')}
              </div>
            </div>
          )}
        </div>

        <div className="mt-5">
          <div className="flex items-center gap-2 rounded-[10px] border border-border bg-chip px-3">
            <Search className="h-4 w-4 flex-none text-muted-foreground" strokeWidth={1.8} />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={t('addMeal.searchPlaceholder')}
              className="h-10 flex-1 bg-transparent text-[16px] text-foreground outline-none placeholder:text-muted-foreground md:text-[15px]"
            />
          </div>

          {searching && (
            <p className="py-6 text-center text-[13px] text-muted-foreground">
              {t('addMeal.loading')}
            </p>
          )}
          {!searching && search.trim() && results.length === 0 && (
            <p className="py-6 text-center text-[13px] text-muted-foreground">
              {t('addMeal.noResults', { query: search.trim() })}
            </p>
          )}
          {!searching &&
            results.map((food) => (
              <div
                key={food.id}
                className="flex min-h-[56px] items-center gap-2 rounded-[10px] px-3 py-2 hover:bg-chip"
              >
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-medium text-foreground">
                    {food.name}
                  </div>
                  <div className="text-[11.5px] text-muted-foreground">
                    {(() => {
                      const preview = defaultPortion(food);
                      return `${formatQuantity(food, preview.quantity, preview.enteredAsServing, t, locale)} · ${Math.round(
                        kcalForQuantity(food, preview.quantity),
                      )} ${t('addMeal.kcal')}`;
                    })()}
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => {
                    editor.addFood(food);
                    setSearch('');
                  }}
                  aria-label={food.name}
                  className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-full bg-chip text-acc hover:bg-grid-ax"
                >
                  <Plus className="h-4 w-4" strokeWidth={2.2} />
                </button>
              </div>
            ))}
        </div>

        {editor.error && <p className="mt-3 text-[12px] text-neg">{editor.error}</p>}
      </div>

      <div className="fixed inset-x-0 bottom-0 z-10 flex items-center justify-end border-t border-border bg-card px-5 py-3.5 pb-[calc(14px+env(safe-area-inset-bottom))] md:static md:border-0 md:bg-transparent">
        <button
          type="button"
          onClick={() => void handleSave()}
          disabled={editor.saving || !editor.name.trim()}
          className="press cursor-pointer rounded-[11px] bg-acc px-5 py-2.5 text-[14px] font-semibold text-acc-fg disabled:cursor-default disabled:opacity-70"
        >
          {editor.saving ? t('savedMeals.saving') : t('savedMeals.save')}
        </button>
      </div>

      {editingItem && (
        <QuantitySheet
          food={editingItem.food}
          initialQuantity={editingItem.quantity}
          initialAsServing={false}
          confirmLabel={t('quantity.update')}
          onCancel={() => setEditingKey(null)}
          onConfirm={({ quantity }) => {
            editor.updateQuantity(editingItem.key, quantity);
            setEditingKey(null);
          }}
        />
      )}
    </div>
  );
}

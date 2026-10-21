import { lazy, Suspense, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Search, ScanBarcode, ChevronLeft, X, Check, Plus, BookmarkPlus } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import { currentIntlLocale } from '@/lib/dateLocale';
import type { FoodListItem, FoodLogItem, Meal, SavedMealSummary } from '@/lib/types';
import AddManualFoodPage from './AddManualFoodPage';
import SavedMealsListPage from './SavedMealsListPage';
import SavedMealEditPage from './SavedMealEditPage';
import QuantitySheet from './components/QuantitySheet';
import { defaultPortion, formatQuantity, kcalForQuantity, type Portion } from './quantityFormat';
import type { WorkingMealItem } from './useSavedMealEditor';

// html5-qrcode's decoder is a heavy dependency (~100kB gzipped) — split out
// so it only downloads when the user actually taps "escanear"
const BarcodeScannerPage = lazy(() => import('./BarcodeScannerPage'));

const SEARCH_DEBOUNCE_MS = 250;

interface AddMealPageProps {
  /** the day's slot being filled — id, not name, since names can repeat */
  meal: Meal;
  existingLogs: FoodLogItem[];
  onBack: () => void;
  onSaved: () => void;
}

type View = 'search' | 'scanner' | 'manual' | 'savedMeals' | 'editSavedMeal';

/** a food staged for saving — quantity lives per item, not globally */
interface CartItem extends Portion {
  /** stable React key: the same food can be added twice via scan/manual */
  key: string;
  food: FoodListItem;
}

// what the quantity sheet is currently editing: a brand new addition, an item
// already in the cart, or a FoodLog that was saved on an earlier visit
type SheetTarget =
  | { kind: 'new'; food: FoodListItem }
  | { kind: 'cart'; item: CartItem }
  | { kind: 'existing'; log: FoodLogItem };

function todayShort(): string {
  return new Date().toLocaleDateString(currentIntlLocale(), {
    day: 'numeric',
    month: 'long',
  });
}

let cartKeySeq = 0;
function nextCartKey(): string {
  cartKeySeq += 1;
  return `cart-${cartKeySeq}`;
}

export default function AddMealPage({ meal, existingLogs, onBack, onSaved }: AddMealPageProps) {
  const { t } = useTranslation('diet');
  const locale = currentIntlLocale();
  const [view, setView] = useState<View>('search');
  const [search, setSearch] = useState('');
  const [results, setResults] = useState<FoodListItem[]>([]);
  const [searching, setSearching] = useState(false);
  const [cart, setCart] = useState<CartItem[]>([]);
  const [existing, setExisting] = useState(existingLogs);
  const [sheet, setSheet] = useState<SheetTarget | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // set only when reached via a barcode scan that found no match — links the
  // manually-cadastrado food to that code
  const [pendingExternalId, setPendingExternalId] = useState<string | undefined>();
  // null = creating a new saved meal; a string = editing that one
  const [editingSavedMealId, setEditingSavedMealId] = useState<string | null>(null);
  // seeds a new saved meal's items from the current cart, via "Salvar como
  // refeição salva" — ignored when editingSavedMealId is set
  const [editorInitialItems, setEditorInitialItems] = useState<WorkingMealItem[]>([]);
  const [applyingSavedMeal, setApplyingSavedMeal] = useState(false);

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

  const removeExisting = (id: string) => {
    setExisting((e) => e.filter((l) => l.id !== id));
    void apiFetch(`/food-logs/${id}`, { method: 'DELETE' });
  };

  const removeCartItem = (key: string) => {
    setCart((c) => c.filter((i) => i.key !== key));
  };

  // untoggling from the search result row: drops every staged entry of that
  // food, since the row only knows the food, not which cart entries it spawned
  const removeFoodFromCart = (foodId: string) => {
    setCart((c) => c.filter((i) => i.food.id !== foodId));
  };

  // every path into the cart goes through the sheet, so a quantity is always
  // chosen deliberately — search, barcode scan and manual entry alike
  const confirmSheet = (portion: Portion) => {
    if (!sheet) return;
    if (sheet.kind === 'new') {
      const food = sheet.food;
      setCart((c) => [...c, { key: nextCartKey(), food, ...portion }]);
    } else if (sheet.kind === 'cart') {
      const key = sheet.item.key;
      setCart((c) => c.map((i) => (i.key === key ? { ...i, ...portion } : i)));
    } else {
      void updateExisting(sheet.log, portion);
    }
    setSheet(null);
  };

  const updateExisting = async (log: FoodLogItem, portion: Portion) => {
    // optimistic: the row already shows the new amount while the PATCH flies
    setExisting((e) => e.map((l) => (l.id === log.id ? { ...l, ...portion } : l)));
    setError(null);
    try {
      const res = await apiFetch(`/food-logs/${log.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(portion),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
    } catch {
      setExisting((e) => e.map((l) => (l.id === log.id ? log : l)));
      setError(t('addMeal.error'));
    }
  };

  const handleSave = async () => {
    if (cart.length === 0) {
      onSaved();
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const loggedAt = new Date().toISOString();
      for (const item of cart) {
        const res = await apiFetch('/food-logs', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            foodId: item.food.id,
            quantity: item.quantity,
            enteredAsServing: item.enteredAsServing,
            mealId: meal.id,
            loggedAt,
          }),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
      }
      onSaved();
    } catch {
      setError(t('addMeal.error'));
    } finally {
      setSaving(false);
    }
  };

  // single call — mirrors starting a workout from a routine template — that
  // creates a FoodLog per saved-meal item server-side (SavedMealsService.applyToLog)
  // instead of looping N sequential POSTs like handleSave's ad-hoc cart does
  const applySavedMeal = async (meal: SavedMealSummary) => {
    setApplyingSavedMeal(true);
    setError(null);
    try {
      const res = await apiFetch(`/saved-meals/${meal.id}/apply`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mealId: meal.id, loggedAt: new Date().toISOString() }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      onSaved();
    } catch {
      setError(t('addMeal.error'));
    } finally {
      setApplyingSavedMeal(false);
    }
  };

  if (view === 'savedMeals') {
    return (
      <SavedMealsListPage
        onBack={() => setView('search')}
        applying={applyingSavedMeal}
        onUse={(meal) => void applySavedMeal(meal)}
        onEdit={(mealId) => {
          setEditingSavedMealId(mealId);
          setView('editSavedMeal');
        }}
        onCreateNew={() => {
          setEditingSavedMealId(null);
          setEditorInitialItems([]);
          setView('editSavedMeal');
        }}
      />
    );
  }

  if (view === 'editSavedMeal') {
    return (
      <SavedMealEditPage
        mealId={editingSavedMealId}
        initialItems={editorInitialItems}
        onBack={() => setView('savedMeals')}
        onSaved={() => setView('savedMeals')}
      />
    );
  }

  if (view === 'manual') {
    return (
      <AddManualFoodPage
        initialExternalId={pendingExternalId}
        onBack={() => {
          setPendingExternalId(undefined);
          setView('search');
        }}
        onCreated={(food) => {
          setPendingExternalId(undefined);
          setSheet({ kind: 'new', food });
          setView('search');
        }}
      />
    );
  }

  if (view === 'scanner') {
    return (
      <Suspense fallback={null}>
        <BarcodeScannerPage
          onBack={() => setView('search')}
          onFound={(food) => {
            setSheet({ kind: 'new', food });
            setView('search');
          }}
          onNotFound={(barcode) => {
            setPendingExternalId(barcode);
            setView('manual');
          }}
        />
      </Suspense>
    );
  }

  const totalItems = existing.length + cart.length;
  const totalKcal =
    existing.reduce((sum, l) => sum + kcalForQuantity(l.food, l.quantity), 0) +
    cart.reduce((sum, i) => sum + kcalForQuantity(i.food, i.quantity), 0);

  const sheetInitial: Portion | null =
    sheet === null
      ? null
      : sheet.kind === 'new'
        ? defaultPortion(sheet.food)
        : sheet.kind === 'cart'
          ? { quantity: sheet.item.quantity, enteredAsServing: sheet.item.enteredAsServing }
          : { quantity: sheet.log.quantity, enteredAsServing: sheet.log.enteredAsServing };

  return (
    <div className="flex min-h-screen flex-col">
      <div className="flex items-center gap-3 border-b border-border px-5 py-3.5">
        <button
          type="button"
          onClick={onBack}
          aria-label={t('addMeal.back')}
          className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-[9px] text-muted-foreground hover:bg-chip hover:text-foreground"
        >
          <ChevronLeft className="h-4.5 w-4.5" strokeWidth={1.8} />
        </button>
        <div className="min-w-0 flex-1">
          <div className="truncate text-[15px] font-semibold text-foreground">
            {t(`meal.${meal.type}`)}
          </div>
          <div className="text-[11.5px] text-muted-foreground">{todayShort()}</div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-5 pt-4 pb-[88px]">
        <div className="flex items-center gap-2">
          <div className="flex flex-1 items-center gap-2 rounded-[10px] border border-border bg-chip px-3">
            <Search className="h-4 w-4 flex-none text-muted-foreground" strokeWidth={1.8} />
            <input
              autoFocus
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={t('addMeal.searchPlaceholder')}
              className="h-10 flex-1 bg-transparent text-[16px] text-foreground outline-none placeholder:text-muted-foreground md:text-[15px]"
            />
          </div>
          <button
            type="button"
            onClick={() => setView('scanner')}
            aria-label={t('addMeal.scanBarcode')}
            className="flex h-[42px] w-[42px] flex-none cursor-pointer items-center justify-center rounded-[10px] border border-border bg-chip text-muted-foreground hover:bg-grid-ax hover:text-foreground"
          >
            <ScanBarcode className="h-[18px] w-[18px]" strokeWidth={1.8} />
          </button>
          <button
            type="button"
            onClick={() => setView('savedMeals')}
            aria-label={t('savedMeals.listTitle')}
            className="flex h-[42px] w-[42px] flex-none cursor-pointer items-center justify-center rounded-[10px] border border-border bg-chip text-muted-foreground hover:bg-grid-ax hover:text-foreground"
          >
            <BookmarkPlus className="h-[18px] w-[18px]" strokeWidth={1.8} />
          </button>
        </div>

        {totalItems > 0 && (
          <div className="mt-5">
            <div className="mb-1.5 px-1 text-[11.5px] font-semibold tracking-[.05em] text-muted-foreground uppercase">
              {t('addMeal.inThisMeal')}
            </div>
            <div className="flex flex-col gap-1">
              {existing.map((log) => (
                <div
                  key={log.id}
                  className="flex min-h-[52px] items-center gap-2 rounded-[10px] px-3 py-2 hover:bg-chip"
                >
                  <button
                    type="button"
                    onClick={() => setSheet({ kind: 'existing', log })}
                    className="min-w-0 flex-1 cursor-pointer text-left"
                  >
                    <div className="truncate text-[14px] font-medium text-foreground">
                      {log.food.name}
                    </div>
                    <div className="text-[11.5px] text-muted-foreground">
                      {formatQuantity(log.food, log.quantity, log.enteredAsServing, t, locale)} ·{' '}
                      {Math.round(kcalForQuantity(log.food, log.quantity))} {t('addMeal.kcal')}
                    </div>
                  </button>
                  <button
                    type="button"
                    onClick={() => removeExisting(log.id)}
                    aria-label={t('addMeal.remove')}
                    className="flex h-7 w-7 flex-none cursor-pointer items-center justify-center rounded-[7px] text-muted-foreground hover:bg-grid-ax hover:text-foreground"
                  >
                    <X className="h-3.5 w-3.5" strokeWidth={1.8} />
                  </button>
                </div>
              ))}
              {cart.map((item) => (
                <div
                  key={item.key}
                  className="flex min-h-[52px] items-center gap-2 rounded-[10px] px-3 py-2 hover:bg-chip"
                >
                  <button
                    type="button"
                    onClick={() => setSheet({ kind: 'cart', item })}
                    className="min-w-0 flex-1 cursor-pointer text-left"
                  >
                    <div className="truncate text-[14px] font-medium text-foreground">
                      {item.food.name}
                    </div>
                    <div className="text-[11.5px] text-muted-foreground">
                      {formatQuantity(item.food, item.quantity, item.enteredAsServing, t, locale)} ·{' '}
                      {Math.round(kcalForQuantity(item.food, item.quantity))} {t('addMeal.kcal')}
                    </div>
                  </button>
                  <button
                    type="button"
                    onClick={() => removeCartItem(item.key)}
                    aria-label={t('addMeal.remove')}
                    className="flex h-7 w-7 flex-none cursor-pointer items-center justify-center rounded-[7px] text-muted-foreground hover:bg-grid-ax hover:text-foreground"
                  >
                    <X className="h-3.5 w-3.5" strokeWidth={1.8} />
                  </button>
                </div>
              ))}
            </div>
            {cart.length > 0 && (
              <button
                type="button"
                onClick={() => {
                  setEditorInitialItems(
                    cart.map((item) => ({
                      key: item.key,
                      foodId: item.food.id,
                      quantity: item.quantity,
                      food: item.food,
                    })),
                  );
                  setEditingSavedMealId(null);
                  setView('editSavedMeal');
                }}
                className="mt-2 cursor-pointer text-[12.5px] font-medium text-acc hover:underline"
              >
                {t('savedMeals.saveCurrentAsMeal')}
              </button>
            )}
          </div>
        )}

        <div className="mt-5">
          {search.trim() && (
            <div className="mb-1.5 px-1 text-[11.5px] font-semibold tracking-[.05em] text-muted-foreground uppercase">
              {t('addMeal.searchResults')}
            </div>
          )}
          {searching && (
            <p className="py-8 text-center text-[13px] text-muted-foreground">
              {t('addMeal.loading')}
            </p>
          )}
          {!searching && search.trim() && results.length === 0 && (
            <div className="flex flex-col items-center gap-3 py-8">
              <p className="text-[13px] text-muted-foreground">
                {t('addMeal.noResults', { query: search.trim() })}
              </p>
            </div>
          )}
          {!searching &&
            results.map((food) => {
              const inCart = cart.some((i) => i.food.id === food.id);
              // the subtitle previews the portion the sheet will open on
              const preview = defaultPortion(food);
              return (
                <div
                  key={food.id}
                  className="flex min-h-[56px] items-center gap-2 rounded-[10px] px-3 py-2 hover:bg-chip"
                >
                  <button
                    type="button"
                    onClick={() => setSheet({ kind: 'new', food })}
                    className="min-w-0 flex-1 cursor-pointer text-left"
                  >
                    <div className="truncate text-[14px] font-medium text-foreground">
                      {food.name}
                    </div>
                    <div className="text-[11.5px] text-muted-foreground">
                      {formatQuantity(food, preview.quantity, preview.enteredAsServing, t, locale)} ·{' '}
                      {Math.round(kcalForQuantity(food, preview.quantity))} {t('addMeal.kcal')}
                    </div>
                  </button>
                  <button
                    type="button"
                    // already staged: one tap clears it, same as before the
                    // sheet existed. Otherwise it's the shortcut into the sheet.
                    onClick={() =>
                      inCart ? removeFoodFromCart(food.id) : setSheet({ kind: 'new', food })
                    }
                    aria-label={food.name}
                    className={`flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-full ${
                      inCart ? 'bg-acc-bg text-acc-tx' : 'bg-chip text-acc hover:bg-grid-ax'
                    }`}
                  >
                    {inCart ? (
                      <Check className="h-4 w-4" strokeWidth={2.2} />
                    ) : (
                      <Plus className="h-4 w-4" strokeWidth={2.2} />
                    )}
                  </button>
                </div>
              );
            })}
        </div>

        <button
          type="button"
          onClick={() => setView('manual')}
          className="mt-4 cursor-pointer text-[12.5px] font-medium text-acc hover:underline"
        >
          {t('addMeal.manualLink')}
        </button>

        {error && <p className="mt-3 text-[12px] text-neg">{error}</p>}
      </div>

      <div className="fixed inset-x-0 bottom-0 z-10 flex items-center justify-between border-t border-border bg-card px-5 py-3.5 pb-[calc(14px+env(safe-area-inset-bottom))] md:static md:border-0 md:bg-transparent">
        <span className="text-[12.5px] text-muted-foreground">
          {t('addMeal.itemsCount', { count: totalItems })} · {Math.round(totalKcal)}{' '}
          {t('addMeal.kcal')}
        </span>
        <button
          type="button"
          onClick={() => void handleSave()}
          disabled={saving}
          className="press cursor-pointer rounded-[11px] bg-acc px-5 py-2.5 text-[14px] font-semibold text-acc-fg disabled:cursor-default disabled:opacity-70"
        >
          {saving ? t('addMeal.saving') : t('addMeal.save')}
        </button>
      </div>

      {sheet && sheetInitial && (
        <QuantitySheet
          food={sheet.kind === 'new' ? sheet.food : sheet.kind === 'cart' ? sheet.item.food : sheet.log.food}
          initialQuantity={sheetInitial.quantity}
          initialAsServing={sheetInitial.enteredAsServing}
          confirmLabel={sheet.kind === 'new' ? t('quantity.add') : t('quantity.update')}
          onCancel={() => setSheet(null)}
          onConfirm={confirmSheet}
        />
      )}
    </div>
  );
}

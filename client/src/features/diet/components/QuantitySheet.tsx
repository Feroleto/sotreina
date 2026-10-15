import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Minus, Plus } from 'lucide-react';
import type { FoodListItem } from '@/lib/types';
import { currentIntlLocale } from '@/lib/dateLocale';
import {
  formatNumber,
  gramsFromServings,
  hasServing,
  kcalForQuantity,
  roundTo,
  servingsFromGrams,
  unitLabel,
  type Portion,
} from '../quantityFormat';

interface QuantitySheetProps {
  food: FoodListItem;
  /** grams — the portion the row currently holds */
  initialQuantity: number;
  initialAsServing: boolean;
  /** "Adicionar" for a new entry, "Atualizar" when editing an existing one */
  confirmLabel: string;
  onCancel: () => void;
  onConfirm: (portion: Portion) => void;
}

type Mode = 'serving' | 'grams';

const SERVING_PRESETS = [0.5, 1, 2, 3];
const GRAM_PRESETS = [30, 50, 100, 150, 200];
const SERVING_STEP = 0.5;
const GRAM_STEP = 10;
const MAX_GRAMS = 5000;

// the field holds a string, not a number, so a half-typed value ("1." or an
// empty box while retyping) doesn't get clobbered mid-edit
function toInputValue(value: number): string {
  return String(roundTo(value, 2));
}

export default function QuantitySheet({
  food,
  initialQuantity,
  initialAsServing,
  confirmLabel,
  onCancel,
  onConfirm,
}: QuantitySheetProps) {
  const { t } = useTranslation('diet');
  const locale = currentIntlLocale();
  const servingGrams = food.servingGrams ?? 0;
  const servingAvailable = hasServing(food);

  const [mode, setMode] = useState<Mode>(
    initialAsServing && servingAvailable ? 'serving' : 'grams',
  );
  const [raw, setRaw] = useState(() =>
    toInputValue(
      initialAsServing && servingAvailable
        ? servingsFromGrams(initialQuantity, servingGrams)
        : initialQuantity,
    ),
  );

  // Escape closes, matching the overlay behaviour of the lap editor
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onCancel();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onCancel]);

  const value = Number(raw.replace(',', '.'));
  const valid = Number.isFinite(value) && value > 0;
  const grams = useMemo(() => {
    if (!valid) return 0;
    const g = mode === 'serving' ? gramsFromServings(value, servingGrams) : roundTo(value, 1);
    return Math.min(g, MAX_GRAMS);
  }, [valid, value, mode, servingGrams]);

  const step = mode === 'serving' ? SERVING_STEP : GRAM_STEP;
  const nudge = (delta: number) => {
    const next = roundTo(Math.max(step, (valid ? value : 0) + delta), 2);
    setRaw(toInputValue(next));
  };

  const switchMode = (next: Mode) => {
    if (next === mode) return;
    // carry the current weight across instead of resetting — switching to
    // grams on "2 unidades" should land on 100g, not on an empty field
    setRaw(
      toInputValue(next === 'serving' ? servingsFromGrams(grams, servingGrams) : grams),
    );
    setMode(next);
  };

  const factor = grams / 100;
  const unitName = food.servingLabel ? unitLabel(food.servingLabel, valid ? value : 1, t) : '';

  return (
    <>
      <div
        className="fixed inset-0 z-40 bg-[rgba(8,12,20,.45)]"
        onClick={onCancel}
        aria-hidden
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={t('quantity.title')}
        className="fixed inset-x-0 bottom-0 z-50 rounded-t-[20px] border border-border bg-card p-5 pb-[calc(20px+env(safe-area-inset-bottom))] md:inset-x-auto md:bottom-auto md:top-1/2 md:left-1/2 md:w-[380px] md:-translate-x-1/2 md:-translate-y-1/2 md:rounded-[16px]"
      >
        <div className="text-[15px] font-semibold text-foreground">{food.name}</div>
        {food.brand && (
          <div className="mt-0.5 truncate text-[11.5px] text-muted-foreground">{food.brand}</div>
        )}

        {servingAvailable && (
          <div className="mt-4 flex gap-2">
            <button
              type="button"
              onClick={() => switchMode('serving')}
              className={`flex-1 cursor-pointer rounded-[10px] border px-3 py-2 text-[13px] font-medium ${
                mode === 'serving'
                  ? 'border-acc bg-acc-bg text-acc-tx'
                  : 'border-border bg-chip text-muted-foreground hover:text-foreground'
              }`}
            >
              {formatNumber(1, locale)}{' '}
              {food.servingLabel ? unitLabel(food.servingLabel, 1, t) : ''}
            </button>
            <button
              type="button"
              onClick={() => switchMode('grams')}
              className={`flex-1 cursor-pointer rounded-[10px] border px-3 py-2 text-[13px] font-medium ${
                mode === 'grams'
                  ? 'border-acc bg-acc-bg text-acc-tx'
                  : 'border-border bg-chip text-muted-foreground hover:text-foreground'
              }`}
            >
              {t('quantity.grams')}
            </button>
          </div>
        )}

        <div className="mt-4 flex items-center justify-center gap-4">
          <button
            type="button"
            onClick={() => nudge(-step)}
            aria-label={t('quantity.decrease')}
            className="flex h-9 w-9 flex-none cursor-pointer items-center justify-center rounded-full bg-chip text-foreground hover:bg-grid-ax"
          >
            <Minus className="h-4 w-4" strokeWidth={2} />
          </button>
          <div className="flex items-baseline gap-2">
            <input
              type="text"
              inputMode="decimal"
              value={raw}
              onChange={(e) => setRaw(e.target.value)}
              aria-label={t('quantity.title')}
              // 16px on mobile — anything smaller makes iOS Safari zoom on focus
              className="h-11 w-[96px] rounded-[10px] border border-border bg-transparent px-3 text-center text-[18px] font-semibold tabular-nums text-foreground outline-none focus:border-acc"
            />
            <span className="text-[13px] text-muted-foreground">
              {mode === 'serving' ? unitName : t('quantity.gramsShort')}
            </span>
          </div>
          <button
            type="button"
            onClick={() => nudge(step)}
            aria-label={t('quantity.increase')}
            className="flex h-9 w-9 flex-none cursor-pointer items-center justify-center rounded-full bg-chip text-foreground hover:bg-grid-ax"
          >
            <Plus className="h-4 w-4" strokeWidth={2} />
          </button>
        </div>

        {mode === 'serving' && (
          <p className="mt-2 text-center text-[12px] text-muted-foreground tabular-nums">
            {t('quantity.equals', { grams: formatNumber(grams, locale) })}
          </p>
        )}

        <div className="mt-4 flex flex-wrap justify-center gap-2">
          {(mode === 'serving' ? SERVING_PRESETS : GRAM_PRESETS).map((preset) => (
            <button
              key={preset}
              type="button"
              onClick={() => setRaw(toInputValue(preset))}
              className="cursor-pointer rounded-full bg-chip px-3 py-1.5 text-[12.5px] font-medium text-muted-foreground tabular-nums hover:bg-grid-ax hover:text-foreground"
            >
              {formatNumber(preset, locale)}
              {mode === 'grams' ? ` ${t('quantity.gramsShort')}` : ''}
            </button>
          ))}
        </div>

        <div className="mt-4 rounded-[10px] bg-chip px-3 py-2.5 text-center text-[12.5px] text-muted-foreground tabular-nums">
          <span className="font-semibold text-foreground">
            {Math.round(kcalForQuantity(food, grams))}
          </span>{' '}
          {t('addMeal.kcal')} · P {Math.round(food.protein * factor)}g · C{' '}
          {Math.round(food.carbs * factor)}g · G {Math.round(food.fat * factor)}g
        </div>

        <div className="mt-4 flex gap-2">
          <button
            type="button"
            onClick={onCancel}
            className="flex-1 cursor-pointer rounded-[11px] border border-border px-4 py-2.5 text-[14px] font-medium text-muted-foreground hover:text-foreground"
          >
            {t('quantity.cancel')}
          </button>
          <button
            type="button"
            disabled={!valid || grams <= 0}
            onClick={() => onConfirm({ quantity: grams, enteredAsServing: mode === 'serving' })}
            className="press flex-1 cursor-pointer rounded-[11px] bg-acc px-4 py-2.5 text-[14px] font-semibold text-white disabled:cursor-default disabled:opacity-70"
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </>
  );
}

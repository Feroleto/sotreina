import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { apiFetch } from '@/lib/api';
import type { FoodListItem } from '@/lib/types';
import { SERVING_UNITS, type ServingUnit } from './constants';
import { unitLabel } from './quantityFormat';

interface AddManualFoodPageProps {
  onBack: () => void;
  onCreated: (food: FoodListItem) => void;
  /** pre-filled when reached from a barcode scan that found no match — links
   * the custom entry to that code so future scans resolve locally */
  initialExternalId?: string;
}

interface FieldProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: 'text' | 'number';
  placeholder?: string;
  required?: boolean;
}

function Field({ label, value, onChange, type = 'text', placeholder, required }: FieldProps) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[12.5px] font-medium text-muted-foreground">{label}</span>
      <input
        type={type}
        inputMode={type === 'number' ? 'decimal' : undefined}
        min={type === 'number' ? 0 : undefined}
        step={type === 'number' ? 'any' : undefined}
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        required={required}
        className="w-full rounded-[11px] border border-border bg-transparent px-3.5 py-[11px] text-[16px] text-foreground outline-none placeholder:text-muted-foreground focus:border-acc md:text-[14px]"
      />
    </label>
  );
}

// leading number in the free-text "Porção" field (e.g. "150 g" → 150) —
// falls back to 100 when unparseable
function parsePortionGrams(portion: string): number {
  const match = portion.match(/(\d+(\.\d+)?)/);
  const grams = match ? Number(match[1]) : NaN;
  return Number.isFinite(grams) && grams > 0 ? grams : 100;
}

export default function AddManualFoodPage({
  onBack,
  onCreated,
  initialExternalId,
}: AddManualFoodPageProps) {
  const { t } = useTranslation('diet');
  const [name, setName] = useState('');
  const [portion, setPortion] = useState('');
  // '' = grams-only food; otherwise the portion above also becomes a household
  // measure, so the food can later be logged as "2 unidades"
  const [unit, setUnit] = useState<ServingUnit | ''>('');
  const [kcal, setKcal] = useState('');
  const [protein, setProtein] = useState('');
  const [carbs, setCarbs] = useState('');
  const [fat, setFat] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      // Food/POST /foods/custom are always per-100g — this form collects
      // absolute values for the stated portion, so normalize before saving
      const grams = parsePortionGrams(portion);
      const factor = 100 / grams;
      const res = await apiFetch('/foods/custom', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: name.trim(),
          kcal: Number(kcal) * factor,
          protein: Number(protein) * factor,
          carbs: Number(carbs) * factor,
          fat: Number(fat) * factor,
          externalId: initialExternalId,
          // the typed portion used to be discarded after normalizing to
          // per-100g — kept now as the food's household measure
          ...(unit ? { servingLabel: unit, servingGrams: grams } : {}),
        }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const food = (await res.json()) as FoodListItem;
      onCreated(food);
    } catch {
      setError(t('manual.error'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="px-5 pt-[18px] pb-[44px]">
      <h1 className="mb-4 text-[18px] font-semibold text-foreground">{t('manual.title')}</h1>

      <form onSubmit={(e) => void submit(e)} className="flex flex-col gap-3">
        <Field label={t('manual.name')} value={name} onChange={setName} required />
        <Field
          label={t('manual.portion')}
          value={portion}
          onChange={setPortion}
          placeholder={t('manual.portionPlaceholder')}
          required
        />

        <label className="flex flex-col gap-1">
          <span className="text-[12.5px] font-medium text-muted-foreground">
            {t('manual.unitLabel')}
          </span>
          <select
            value={unit}
            onChange={(e) => setUnit(e.target.value as ServingUnit | '')}
            className="w-full rounded-[11px] border border-border bg-transparent px-3.5 py-[11px] text-[16px] text-foreground outline-none focus:border-acc md:text-[14px]"
          >
            <option value="">{t('manual.unitNone')}</option>
            {SERVING_UNITS.map((slug) => (
              <option key={slug} value={slug}>
                {unitLabel(slug, 1, t)}
              </option>
            ))}
          </select>
          <span className="text-[11.5px] text-muted-foreground">{t('manual.unitHelp')}</span>
        </label>

        <Field label={t('manual.kcal')} value={kcal} onChange={setKcal} type="number" required />
        <div className="grid grid-cols-3 gap-3">
          <Field
            label={t('manual.protein')}
            value={protein}
            onChange={setProtein}
            type="number"
            required
          />
          <Field label={t('manual.carbs')} value={carbs} onChange={setCarbs} type="number" required />
          <Field label={t('manual.fat')} value={fat} onChange={setFat} type="number" required />
        </div>

        {error && <p className="text-[12px] text-neg">{error}</p>}

        <button
          type="submit"
          disabled={submitting}
          className="press mt-1 cursor-pointer rounded-[11px] bg-acc px-4 py-3 text-[14px] font-semibold text-acc-fg disabled:cursor-default disabled:opacity-70"
        >
          {submitting ? t('manual.saving') : t('manual.save')}
        </button>

        <button
          type="button"
          onClick={onBack}
          className="cursor-pointer text-center text-[12.5px] font-medium text-muted-foreground hover:text-foreground"
        >
          {t('manual.back')}
        </button>
      </form>
    </div>
  );
}

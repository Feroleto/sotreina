import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ChevronLeft, Minus, Plus } from 'lucide-react';
import type { NutritionGoal } from '@/lib/types';

interface GoalPageProps {
  goal: NutritionGoal;
  onBack: () => void;
  onSave: (next: NutritionGoal) => Promise<void>;
}

const KCAL_STEP = 50;
const KCAL_MIN = 800;
const KCAL_MAX = 6000;
const MACRO_STEP = 5;
const MACRO_MIN = 0;
const MACRO_MAX = 500;
const MATCH_TOLERANCE_PCT = 3;

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function KcalStepper({ value, onChange }: { value: number; onChange: (v: number) => void }) {
  return (
    <div className="flex items-center justify-center gap-5">
      <button
        type="button"
        onClick={() => onChange(clamp(value - KCAL_STEP, KCAL_MIN, KCAL_MAX))}
        className="flex h-9 w-9 cursor-pointer items-center justify-center rounded-full bg-chip text-foreground hover:bg-grid-ax"
      >
        <Minus className="h-4 w-4" strokeWidth={2} />
      </button>
      <div className="flex items-baseline gap-1.5 tabular-nums">
        <span className="text-[22px] font-bold text-foreground">{value}</span>
        <span className="text-[13px] text-muted-foreground">kcal</span>
      </div>
      <button
        type="button"
        onClick={() => onChange(clamp(value + KCAL_STEP, KCAL_MIN, KCAL_MAX))}
        className="flex h-9 w-9 cursor-pointer items-center justify-center rounded-full bg-chip text-foreground hover:bg-grid-ax"
      >
        <Plus className="h-4 w-4" strokeWidth={2} />
      </button>
    </div>
  );
}

function MacroRow({
  label,
  value,
  kcalGoal,
  kcalPerGram,
  onChange,
}: {
  label: string;
  value: number;
  kcalGoal: number;
  kcalPerGram: number;
  onChange: (v: number) => void;
}) {
  const { t } = useTranslation('diet');
  const pct = kcalGoal > 0 ? Math.round(((value * kcalPerGram) / kcalGoal) * 100) : 0;
  return (
    <div className="flex items-center justify-between py-2.5">
      <div>
        <div className="text-[13px] font-medium text-foreground">{label}</div>
        <div className="text-[11px] text-muted-foreground">{t('goal.pctOfCalories', { pct })}</div>
      </div>
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => onChange(clamp(value - MACRO_STEP, MACRO_MIN, MACRO_MAX))}
          className="flex h-7 w-7 cursor-pointer items-center justify-center rounded-full bg-chip text-foreground hover:bg-grid-ax"
        >
          <Minus className="h-3.5 w-3.5" strokeWidth={2} />
        </button>
        <span className="w-[44px] text-center text-[14px] font-semibold tabular-nums text-foreground">
          {value}g
        </span>
        <button
          type="button"
          onClick={() => onChange(clamp(value + MACRO_STEP, MACRO_MIN, MACRO_MAX))}
          className="flex h-7 w-7 cursor-pointer items-center justify-center rounded-full bg-chip text-foreground hover:bg-grid-ax"
        >
          <Plus className="h-3.5 w-3.5" strokeWidth={2} />
        </button>
      </div>
    </div>
  );
}

export default function GoalPage({ goal, onBack, onSave }: GoalPageProps) {
  const { t } = useTranslation('diet');
  const [kcalGoal, setKcalGoal] = useState(goal.dailyKcalGoal);
  const [protein, setProtein] = useState(goal.dailyProteinGoal);
  const [carbs, setCarbs] = useState(goal.dailyCarbsGoal);
  const [fat, setFat] = useState(goal.dailyFatGoal);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const calculatedKcal = Math.round(protein * 4 + carbs * 4 + fat * 9);
  const diffPct = kcalGoal > 0 ? Math.round((Math.abs(calculatedKcal - kcalGoal) / kcalGoal) * 100) : 0;
  const matches = diffPct <= MATCH_TOLERANCE_PCT;
  const isAbove = calculatedKcal > kcalGoal;

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    try {
      await onSave({
        dailyKcalGoal: kcalGoal,
        dailyProteinGoal: protein,
        dailyCarbsGoal: carbs,
        dailyFatGoal: fat,
      });
    } catch {
      setError(t('goal.error'));
      setSaving(false);
    }
  };

  return (
    <div className="px-5 pt-[18px] pb-8">
      <div className="mb-5 flex items-center gap-3">
        <button
          type="button"
          onClick={onBack}
          aria-label={t('addMeal.back')}
          className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-[9px] text-muted-foreground hover:bg-chip hover:text-foreground"
        >
          <ChevronLeft className="h-4.5 w-4.5" strokeWidth={1.8} />
        </button>
        <h1 className="text-[15px] font-semibold text-foreground">{t('goal.title')}</h1>
      </div>

      <div className="rounded-[16px] border border-border bg-card p-5">
        <div className="mb-2 text-center text-[12.5px] font-medium text-muted-foreground">
          {t('goal.calories')}
        </div>
        <KcalStepper value={kcalGoal} onChange={setKcalGoal} />
      </div>

      <div className="mt-4 divide-y divide-border rounded-[16px] border border-border bg-card px-5">
        <MacroRow
          label={t('macro.protein')}
          value={protein}
          kcalGoal={kcalGoal}
          kcalPerGram={4}
          onChange={setProtein}
        />
        <MacroRow
          label={t('macro.carbs')}
          value={carbs}
          kcalGoal={kcalGoal}
          kcalPerGram={4}
          onChange={setCarbs}
        />
        <MacroRow
          label={t('macro.fat')}
          value={fat}
          kcalGoal={kcalGoal}
          kcalPerGram={9}
          onChange={setFat}
        />
      </div>

      <div className="mt-4 flex items-center justify-between rounded-[10px] bg-chip px-4 py-3">
        <span className="text-[12px] text-muted-foreground">
          {t('goal.calculated', { kcal: calculatedKcal })}
        </span>
        <span
          className="text-[12px] font-medium"
          style={{ color: matches ? 'var(--pos)' : 'var(--neg)' }}
        >
          {matches
            ? t('goal.matches')
            : t(isAbove ? 'goal.aboveTarget' : 'goal.belowTarget', { pct: diffPct })}
        </span>
      </div>

      {error && <p className="mt-3 text-[12px] text-neg">{error}</p>}

      <button
        type="button"
        onClick={() => void handleSave()}
        disabled={saving}
        className="press mt-5 w-full cursor-pointer rounded-[11px] bg-acc px-4 py-3 text-[14px] font-semibold text-white disabled:cursor-default disabled:opacity-70"
      >
        {saving ? t('goal.saving') : t('goal.save')}
      </button>
    </div>
  );
}

import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { MealType } from '@/lib/types';
import { MEAL_TYPES } from '../constants';

interface MealTypePickerProps {
  title: string;
  /** preselected name when renaming; undefined when adding a new meal */
  initialType?: MealType;
  confirmLabel: string;
  onCancel: () => void;
  onConfirm: (type: MealType) => void;
}

// Same chrome as QuantitySheet: bottom sheet on mobile, centered modal from md
// up. Serves both "add a meal" and "rename this meal" — the only difference is
// whether a name starts selected.
export default function MealTypePicker({
  title,
  initialType,
  confirmLabel,
  onCancel,
  onConfirm,
}: MealTypePickerProps) {
  const { t } = useTranslation('diet');
  const [selected, setSelected] = useState<MealType>(initialType ?? MEAL_TYPES[0]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onCancel();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onCancel]);

  return (
    <>
      <div className="fixed inset-0 z-40 bg-[rgba(8,12,20,.45)]" onClick={onCancel} aria-hidden />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="fixed inset-x-0 bottom-0 z-50 rounded-t-[20px] border border-border bg-card p-5 pb-[calc(20px+env(safe-area-inset-bottom))] md:inset-x-auto md:bottom-auto md:top-1/2 md:left-1/2 md:w-[380px] md:-translate-x-1/2 md:-translate-y-1/2 md:rounded-[16px]"
      >
        <div className="text-[15px] font-semibold text-foreground">{title}</div>

        <div className="mt-4 flex flex-col gap-2">
          {MEAL_TYPES.map((type) => (
            <button
              key={type}
              type="button"
              aria-pressed={selected === type}
              onClick={() => setSelected(type)}
              className={`cursor-pointer rounded-[10px] border px-3 py-2.5 text-left text-[14px] font-medium ${
                selected === type
                  ? 'border-acc bg-acc-bg text-acc-tx'
                  : 'border-border bg-chip text-muted-foreground hover:text-foreground'
              }`}
            >
              {t(`meal.${type}`)}
            </button>
          ))}
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
            onClick={() => onConfirm(selected)}
            className="press flex-1 cursor-pointer rounded-[11px] bg-acc px-4 py-2.5 text-[14px] font-semibold text-acc-fg"
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </>
  );
}

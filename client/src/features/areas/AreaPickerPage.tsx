import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Check } from 'lucide-react';
import { LogoMark } from '@/components/Logo';
import { cn } from '@/lib/utils';
import type { Area } from '@/lib/types';
import { AREAS } from './areas';

interface AreaPickerPageProps {
  /** saves the selection; a rejection keeps the user here with an error */
  onConfirm: (areas: Area[]) => Promise<void>;
}

/**
 * "O que você quer acompanhar?" — Redesign 21a. Shown once, right after an
 * account is created (enabledAreas still empty), before the app shell. The
 * same selection is edited later from Perfil's toggles
 */
export default function AreaPickerPage({ onConfirm }: AreaPickerPageProps) {
  const { t } = useTranslation(['onboarding', 'nav']);
  const [selected, setSelected] = useState<Area[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(false);

  const toggle = (id: Area) =>
    setSelected((cur) =>
      cur.includes(id) ? cur.filter((a) => a !== id) : [...cur, id],
    );

  const confirm = async () => {
    if (selected.length === 0 || saving) return;
    setSaving(true);
    setError(false);
    try {
      // canonical order, same as the server stores it
      await onConfirm(
        AREAS.map((a) => a.id).filter((id) => selected.includes(id)),
      );
    } catch {
      setError(true);
      setSaving(false);
    }
  };

  const count = selected.length;

  return (
    <div className="flex min-h-[100dvh] flex-col bg-page-bg pt-[env(safe-area-inset-top)] text-foreground">
      <div className="mx-auto flex w-full max-w-[480px] flex-1 flex-col px-[22px] pt-5 md:pt-16">
        <LogoMark className="size-[34px] text-foreground" />
        <h1 className="mt-7 text-[28px] leading-[1.15] font-semibold tracking-[-.02em] text-pretty">
          {t('areas.title')}
        </h1>
        <p className="mt-2.5 text-[14px] leading-[1.5] text-pretty text-muted-foreground">
          {t('areas.subtitle')}
        </p>

        <div
          className="mt-7 border-t border-border"
          role="group"
          aria-label={t('areas.title')}
        >
          {AREAS.map((area) => {
            const on = selected.includes(area.id);
            return (
              <button
                key={area.id}
                type="button"
                role="checkbox"
                aria-checked={on}
                onClick={() => toggle(area.id)}
                className="flex w-full cursor-pointer items-center gap-3.5 border-b border-border py-[18px] text-left"
              >
                <span className="flex h-[42px] w-[42px] flex-none items-center justify-center rounded-full bg-chip text-foreground">
                  <svg
                    width="20"
                    height="20"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.8}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                  >
                    <path d={area.icon} />
                  </svg>
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-[15.5px] font-medium">
                    {t(`nav:${area.labelKey}`)}
                  </span>
                  <span className="mt-[3px] block text-[12.5px] leading-[1.4] text-muted-foreground">
                    {t(area.descKey)}
                  </span>
                </span>
                {on ? (
                  <span className="flex h-6 w-6 flex-none items-center justify-center rounded-full bg-acc text-acc-fg">
                    <Check
                      className="h-3 w-3"
                      strokeWidth={3}
                      aria-hidden="true"
                    />
                  </span>
                ) : (
                  <span className="block h-6 w-6 flex-none rounded-full border-[1.5px] border-muted-foreground" />
                )}
              </button>
            );
          })}
        </div>

        <div className="mt-auto flex flex-col items-center gap-3.5 pt-8 pb-[max(34px,calc(env(safe-area-inset-bottom)+16px))]">
          <p
            aria-live="polite"
            className={cn(
              'text-[12.5px]',
              error ? 'text-neg' : 'text-muted-foreground',
            )}
          >
            {error
              ? t('areas.error')
              : count === 0
                ? t('areas.countNone')
                : t('areas.count', { count })}
          </p>
          <button
            type="button"
            onClick={() => void confirm()}
            disabled={count === 0 || saving}
            className={cn(
              'h-[54px] w-full cursor-pointer rounded-full text-[15.5px] font-semibold disabled:cursor-default',
              count > 0
                ? 'press bg-acc text-acc-fg disabled:opacity-70'
                : 'bg-chip text-muted-foreground',
            )}
          >
            {t('areas.continue')}
          </button>
        </div>
      </div>
    </div>
  );
}

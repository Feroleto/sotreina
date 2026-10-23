import { useTranslation } from 'react-i18next';
import { formatDistance } from '@/lib/activityFormat';
import { distanceLabel } from '@/lib/units';

interface RangeChipProps {
  label: string;
  count: number;
  km: number;
  days: number;
  onClear: () => void;
}

export default function RangeChip({
  label,
  count,
  km,
  days,
  onClear,
}: RangeChipProps) {
  const { t } = useTranslation('dashboard');
  return (
    <div className="mb-[26px] flex">
      <div
        className="flex items-center gap-2.5 rounded-full px-3.5 py-[7px]"
        style={{
          background: 'color-mix(in oklab, var(--acc) 10%, transparent)',
        }}
      >
        <span
          className="text-[12.5px] font-semibold"
          style={{ color: 'var(--acc-tx)' }}
        >
          {label}
        </span>
        <span className="text-xs text-muted-foreground">
          {t('rangeChip.runsCount', { count })} · {formatDistance(km)}{' '}
          {distanceLabel()} · {t('rangeChip.daysCount', { count: days })}
        </span>
        <button
          onClick={onClear}
          aria-label={t('rangeChip.clearAriaLabel')}
          className="cursor-pointer text-[14px] leading-none text-muted-foreground hover:text-foreground"
        >
          ×
        </button>
      </div>
    </div>
  );
}

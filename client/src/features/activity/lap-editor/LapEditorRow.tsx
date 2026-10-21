import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { GripVertical } from 'lucide-react';
import { formatMinSec } from '@/lib/activityFormat';
import type { ActivityStreamPoint, LapSizeMode, LapType } from '@/lib/types';
import type { ResolvedLap } from './lapBoundaryMath';
import { EDITABLE_LAP_TYPES, LAP_TYPE_I18N } from './constants';
import SizeModeToggle from './SizeModeToggle';

interface LapEditorRowProps {
  resolved: ResolvedLap;
  points: ActivityStreamPoint[];
  index: number;
  isEditing: boolean;
  isDragging: boolean;
  onStartEdit: () => void;
  onCommit: (patch: {
    lapType: LapType;
    sizeMode: LapSizeMode;
    sizeValue: number;
  }) => void;
  onCancelEdit: () => void;
  onDelete: () => void;
  onDragStart: (e: React.PointerEvent) => void;
}

export default function LapEditorRow({
  resolved,
  points,
  index,
  isEditing,
  isDragging,
  onStartEdit,
  onCommit,
  onCancelEdit,
  onDelete,
  onDragStart,
}: LapEditorRowProps) {
  const { t } = useTranslation('activity');
  const [lapType, setLapType] = useState<LapType>(resolved.lapType);
  const [sizeMode, setSizeMode] = useState<LapSizeMode>(resolved.sizeMode);
  const [sizeValue, setSizeValue] = useState(String(resolved.sizeValue));

  const durationSec =
    points.length > 0
      ? points[resolved.endIdx].secondIndex - points[resolved.startIdx].secondIndex
      : 0;

  function startEdit() {
    setLapType(resolved.lapType);
    setSizeMode(resolved.sizeMode);
    setSizeValue(String(resolved.sizeValue));
    onStartEdit();
  }

  function commit() {
    const value = Number(sizeValue);
    if (!Number.isFinite(value) || value <= 0) return;
    onCommit({ lapType, sizeMode, sizeValue: value });
  }

  if (isEditing) {
    return (
      <div
        data-lap-key={resolved.key}
        className="flex flex-wrap items-center gap-2 rounded-[10px] border border-border bg-chip px-2.5 py-2.5"
      >
        <select
          value={lapType}
          onChange={(e) => setLapType(e.target.value as LapType)}
          className="cursor-pointer rounded-md border border-border bg-card px-2 py-1 text-[16px] text-foreground md:text-[13px]"
        >
          {EDITABLE_LAP_TYPES.map((type) => (
            <option key={type} value={type}>
              {t(LAP_TYPE_I18N[type])}
            </option>
          ))}
        </select>
        <SizeModeToggle value={sizeMode} onChange={setSizeMode} />
        <input
          type="number"
          min={1}
          value={sizeValue}
          onChange={(e) => setSizeValue(e.target.value)}
          className="w-20 rounded-md border border-border bg-card px-2 py-1 text-[16px] text-foreground md:text-[13px]"
        />
        <span className="text-[12px] text-muted-foreground">
          {sizeMode === 'distance' ? 'm' : 's'}
        </span>
        <div className="ml-auto flex items-center gap-1.5">
          <button
            type="button"
            onClick={onCancelEdit}
            className="cursor-pointer rounded-[8px] px-2.5 py-1 text-[12px] font-medium text-muted-foreground hover:text-foreground"
          >
            {t('laps.cancelEdit')}
          </button>
          <button
            type="button"
            onClick={commit}
            className="press cursor-pointer rounded-[8px] bg-acc px-2.5 py-1 text-[12px] font-medium text-acc-fg"
          >
            {t('laps.confirm')}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div
      data-lap-key={resolved.key}
      className={`flex items-center gap-1.5 border-b border-border px-0.5 py-2.5 md:gap-[13px] ${
        isDragging ? 'opacity-40' : ''
      }`}
    >
      <div className="w-[22px] text-[12.5px] text-muted-foreground">{index}</div>
      <button
        type="button"
        onClick={startEdit}
        className="w-[84px] cursor-pointer truncate text-left text-[13.5px] font-medium text-foreground hover:underline md:w-[110px]"
      >
        {t(LAP_TYPE_I18N[resolved.lapType])}
      </button>
      <div className="hidden flex-1 md:block" />
      <div className="w-[58px] text-right text-[13px] text-muted-foreground md:w-[66px]">
        {(resolved.distanceM / 1000).toFixed(2)} km
      </div>
      <div className="w-11 text-right text-[13px] text-muted-foreground md:w-14">
        {formatMinSec(durationSec)}
      </div>
      <div className="w-14 text-right text-[13.5px] font-semibold text-muted-foreground md:w-16">
        —
      </div>
      <div className="hidden w-11 text-right text-[13px] text-muted-foreground md:block">
        —
      </div>
      <div className="w-11 text-right text-[13px] text-muted-foreground">—</div>
      <div className="hidden w-11 text-right text-[13px] text-muted-foreground md:block">
        —
      </div>
      {/* fixed width, matching the header's trailing spacer exactly (see
          LapEditorPanel.tsx) — otherwise these two buttons (absent from the
          header) make the flex-1 spacer above shrink more in the row than
          in the header, pushing DIST/TIME/PACE/etc left of their labels */}
      <div className="ml-1 flex w-16 flex-none items-center justify-end gap-1">
        <button
          type="button"
          onPointerDown={onDragStart}
          aria-label={t('laps.reorder')}
          className="cursor-grab touch-none rounded-[7px] p-1.5 text-muted-foreground hover:bg-chip active:cursor-grabbing"
        >
          <GripVertical size={15} />
        </button>
        <button
          type="button"
          onClick={onDelete}
          aria-label={t('laps.deleteLap')}
          className="cursor-pointer rounded-[7px] p-1.5 text-[18px] leading-none text-neg hover:bg-chip"
        >
          ×
        </button>
      </div>
    </div>
  );
}

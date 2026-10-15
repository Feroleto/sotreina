import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { LapSizeMode, LapType } from '@/lib/types';
import { EDITABLE_LAP_TYPES, LAP_TYPE_I18N } from './constants';
import SizeModeToggle from './SizeModeToggle';

interface SizeInput {
  sizeMode: LapSizeMode;
  sizeValue: number;
}

interface LapEditorToolbarProps {
  onAddLap: (lap: { lapType: LapType; sizeMode: LapSizeMode; sizeValue: number }) => void;
  onAddReps: (count: number, workout: SizeInput, rest: SizeInput) => void;
}

type OpenForm = 'lap' | 'reps' | null;

// Fixed pair of buttons at the top of the panel (in place of the old
// per-row "+" dividers) — new laps/repeats are always appended at the end
// of the working list, simpler than picking an arbitrary insert position.
export default function LapEditorToolbar({
  onAddLap,
  onAddReps,
}: LapEditorToolbarProps) {
  const { t } = useTranslation('activity');
  const [openForm, setOpenForm] = useState<OpenForm>(null);

  const [lapType, setLapType] = useState<LapType>('RUN');
  const [sizeMode, setSizeMode] = useState<LapSizeMode>('distance');
  const [sizeValue, setSizeValue] = useState('400');

  const [repsCount, setRepsCount] = useState('4');
  const [workoutSizeMode, setWorkoutSizeMode] = useState<LapSizeMode>('distance');
  const [workoutSizeValue, setWorkoutSizeValue] = useState('400');
  const [restSizeMode, setRestSizeMode] = useState<LapSizeMode>('time');
  const [restSizeValue, setRestSizeValue] = useState('90');

  function toggle(form: OpenForm) {
    setOpenForm((current) => (current === form ? null : form));
  }

  function submitLap() {
    const value = Number(sizeValue);
    if (!Number.isFinite(value) || value <= 0) return;
    onAddLap({ lapType, sizeMode, sizeValue: value });
    setOpenForm(null);
  }

  function submitReps() {
    const count = Number(repsCount);
    const workoutValue = Number(workoutSizeValue);
    const restValue = Number(restSizeValue);
    if (!Number.isInteger(count) || count <= 0) return;
    if (!Number.isFinite(workoutValue) || workoutValue <= 0) return;
    if (!Number.isFinite(restValue) || restValue <= 0) return;

    onAddReps(
      count,
      { sizeMode: workoutSizeMode, sizeValue: workoutValue },
      { sizeMode: restSizeMode, sizeValue: restValue },
    );
    setOpenForm(null);
  }

  return (
    <div className="mb-3">
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={() => toggle('lap')}
          className={`cursor-pointer rounded-[8px] px-3 py-1.5 text-[12.5px] font-medium ${
            openForm === 'lap'
              ? 'bg-acc text-white'
              : 'bg-chip text-foreground hover:bg-grid-ax'
          }`}
        >
          + {t('laps.addLap')}
        </button>
        <button
          type="button"
          onClick={() => toggle('reps')}
          className={`cursor-pointer rounded-[8px] px-3 py-1.5 text-[12.5px] font-medium ${
            openForm === 'reps'
              ? 'bg-acc text-white'
              : 'bg-chip text-foreground hover:bg-grid-ax'
          }`}
        >
          + {t('laps.addReps')}
        </button>
      </div>

      {openForm === 'lap' && (
        <div className="mt-2 flex flex-wrap items-center gap-2 rounded-[10px] border border-border bg-chip p-3">
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
          <button
            type="button"
            onClick={submitLap}
            className="press ml-auto cursor-pointer rounded-[8px] bg-acc px-3 py-1 text-[12px] font-medium text-white"
          >
            {t('laps.confirm')}
          </button>
        </div>
      )}

      {openForm === 'reps' && (
        <div className="mt-2 flex flex-col gap-2 rounded-[10px] border border-border bg-chip p-3">
          <div className="flex items-center gap-2">
            <label className="w-24 text-[12px] text-muted-foreground">
              {t('laps.repsCount')}
            </label>
            <input
              type="number"
              min={1}
              value={repsCount}
              onChange={(e) => setRepsCount(e.target.value)}
              className="w-16 rounded-md border border-border bg-card px-2 py-1 text-[16px] text-foreground md:text-[13px]"
            />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="w-24 text-[12px] text-muted-foreground">
              {t('laps.workoutSize')}
            </span>
            <SizeModeToggle value={workoutSizeMode} onChange={setWorkoutSizeMode} />
            <input
              type="number"
              min={1}
              value={workoutSizeValue}
              onChange={(e) => setWorkoutSizeValue(e.target.value)}
              className="w-20 rounded-md border border-border bg-card px-2 py-1 text-[16px] text-foreground md:text-[13px]"
            />
            <span className="text-[12px] text-muted-foreground">
              {workoutSizeMode === 'distance' ? 'm' : 's'}
            </span>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="w-24 text-[12px] text-muted-foreground">
              {t('laps.restSize')}
            </span>
            <SizeModeToggle value={restSizeMode} onChange={setRestSizeMode} />
            <input
              type="number"
              min={1}
              value={restSizeValue}
              onChange={(e) => setRestSizeValue(e.target.value)}
              className="w-20 rounded-md border border-border bg-card px-2 py-1 text-[16px] text-foreground md:text-[13px]"
            />
            <span className="text-[12px] text-muted-foreground">
              {restSizeMode === 'distance' ? 'm' : 's'}
            </span>
          </div>
          <div className="flex justify-end">
            <button
              type="button"
              onClick={submitReps}
              className="press cursor-pointer rounded-[8px] bg-acc px-3 py-1 text-[12px] font-medium text-white"
            >
              {t('laps.confirm')}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

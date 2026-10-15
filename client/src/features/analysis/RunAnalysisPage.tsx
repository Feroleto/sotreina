import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useActivityLaps } from './useActivityLaps';
import { useHrZones } from './useHrZones';
import { useMaxHr } from './useMaxHr';
import { useTrainingMetrics } from './useTrainingMetrics';
import { useDecoupling } from './useDecoupling';
import WeeklyVolumeChart from './WeeklyVolumeChart';
import PaceVsVolumeChart from './PaceVsVolumeChart';
import Z2StackedChart from './Z2StackedChart';
import PaceZoneHistogram from './PaceZoneHistogram';
import TrainingLoadChart from './TrainingLoadChart';
import AcwrChart from './AcwrChart';
import EfficiencyFactorChart from './EfficiencyFactorChart';
import MonotonyStrainChart from './MonotonyStrainChart';
import DecouplingTrendChart from './DecouplingTrendChart';
import { DelayedSkeleton, Skeleton } from '@/components/Skeleton';

function SectionLabel({
  children,
  first = false,
}: {
  children: string;
  first?: boolean;
}) {
  return (
    <div
      className={`text-[11px] font-semibold tracking-[.08em] text-muted-foreground uppercase md:col-span-2 ${
        first ? '' : 'mt-6'
      }`}
    >
      {children}
    </div>
  );
}

function MaxHrControl({
  maxHr,
  onSave,
}: {
  maxHr: number | null;
  onSave: (value: number) => Promise<void>;
}) {
  const { t } = useTranslation('analysis');
  const [value, setValue] = useState(maxHr != null ? String(maxHr) : '');
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    setValue(maxHr != null ? String(maxHr) : '');
  }, [maxHr]);

  async function handleSave() {
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < 100 || parsed > 230) {
      setErr(t('maxHr.invalid'));
      return;
    }
    setSaving(true);
    setErr(null);
    try {
      await onSave(parsed);
    } catch {
      setErr(t('maxHr.saveFailed'));
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="mt-2 flex flex-wrap items-center gap-2 text-[12.5px] text-muted-foreground">
      <label htmlFor="max-hr-input">{t('maxHr.label')}</label>
      <input
        id="max-hr-input"
        type="number"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder={t('maxHr.placeholder')}
        className="w-20 rounded-md border border-border bg-transparent px-2 py-1 text-[16px] text-foreground md:text-[12.5px]"
      />
      <span>{t('maxHr.bpm')}</span>
      <button
        onClick={handleSave}
        disabled={saving}
        className="rounded-md border border-border px-2 py-1 text-foreground hover:bg-chip"
      >
        {saving ? t('maxHr.saving') : t('maxHr.save')}
      </button>
      {err ? (
        <span className="text-neg">{err}</span>
      ) : maxHr == null ? (
        <span>{t('maxHr.helper')}</span>
      ) : null}
    </div>
  );
}

export default function RunAnalysisPage() {
  const { t } = useTranslation('analysis');
  const { laps, loading, error } = useActivityLaps();
  const { zones: hrZones } = useHrZones();
  const { maxHr, save: saveMaxHr } = useMaxHr();
  const hasMaxHr = maxHr != null;
  const weeks = useTrainingMetrics(laps, maxHr, hrZones);
  const decoupling = useDecoupling(laps);
  // the trailing partial week is a mid-week artifact (every metric plunges
  // until Sunday) — every chart reads completed weeks only, same convention
  // the app already uses elsewhere for weekly training metrics
  const completed = useMemo(
    () => (weeks.at(-1)?.isPartial ? weeks.slice(0, -1) : weeks),
    [weeks],
  );

  if (error) {
    return (
      <p className="p-10 text-center text-[13.5px] text-neg">
        {t('common:error', { message: error })}
      </p>
    );
  }

  return (
    <div className="px-5 pt-[18px] pb-[44px] tabular-nums md:p-[30px_34px_34px]">
      {/* on mobile the section title lives in the app bar (MobileChrome) */}
      <h1 className="hidden text-[19px] font-semibold tracking-[-.01em] text-foreground md:block">
        {t('page.title')}
      </h1>
      <p className="mt-[2px] text-[12.5px] text-muted-foreground">
        {t('page.subtitle')}
      </p>
      <MaxHrControl maxHr={maxHr} onSave={saveMaxHr} />

      {loading ? (
        <DelayedSkeleton>
          <div className="mt-6 grid grid-cols-1 gap-4 md:grid-cols-2">
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-[300px] rounded-[var(--rad)]" />
            ))}
          </div>
        </DelayedSkeleton>
      ) : (
        <div className="content-fade-in mt-6 grid grid-cols-1 gap-4 md:grid-cols-2">
          <SectionLabel first>{t('sections.volume')}</SectionLabel>
          <WeeklyVolumeChart weeks={completed} />
          <PaceVsVolumeChart weeks={completed} />

          <SectionLabel>{t('sections.intensityZones')}</SectionLabel>
          <Z2StackedChart weeks={completed} hasMaxHr={hasMaxHr} />
          <PaceZoneHistogram laps={laps} weeks={completed} />

          <SectionLabel>{t('sections.trainingLoad')}</SectionLabel>
          <TrainingLoadChart weeks={completed} />
          <AcwrChart weeks={completed} />
          <EfficiencyFactorChart weeks={completed} hasMaxHr={hasMaxHr} />
          <DecouplingTrendChart points={decoupling} />

          <MonotonyStrainChart weeks={completed} />
        </div>
      )}
    </div>
  );
}

import { currentIntlLocale } from '@/lib/dateLocale';
import type { ActivityLap } from '@/lib/types';
import {
  distanceLabel,
  kmToDisplay,
  paceToDisplay,
  type DistanceUnit,
} from '@/lib/units';

// dot/badge colors per workout type (tokens from index.css); labelKey points
// into the 'common' i18n namespace, translate at render time
export const WORKOUT_META: Record<
  string,
  { labelKey: string; dot: string; badgeBg: string; badgeColor: string }
> = {
  EASY_OR_LONG: {
    labelKey: 'workout.easyLong',
    dot: 'var(--dot-easy)',
    badgeBg: 'var(--neutral-bg)',
    badgeColor: 'var(--neutral)',
  },
  INTERVAL: {
    labelKey: 'workout.interval',
    dot: 'var(--acc)',
    badgeBg: 'var(--acc-bg)',
    badgeColor: 'var(--acc-tx)',
  },
  HILL_REPEATS: {
    labelKey: 'workout.hillRepeats',
    dot: 'var(--pos)',
    badgeBg: 'var(--pos-bg)',
    badgeColor: 'var(--pos)',
  },
};

// values are activity.json keys, translated at render time
const LAP_TYPE_BASE: Record<string, string> = {
  WARMUP: 'lapType.warmup',
  COOLDOWN: 'lapType.cooldown',
  WORKOUT: 'lapType.workout',
  REST: 'lapType.rest',
  RUN: 'lapType.run',
  STEADY: 'lapType.steady',
  ACTIVITY: 'lapType.activity',
};

const KM_LAP_TOLERANCE_M = 100;

// last lap may be a partial km (splits_metric remainder, or a native
// "cooldown" lap) — excluded from the check
function isKmAligned(steadyLaps: ActivityLap[]): boolean {
  if (steadyLaps.length === 0) return true;
  return steadyLaps
    .slice(0, -1)
    .every((lap) => Math.abs(lap.distanceM - 1000) <= KM_LAP_TOLERANCE_M);
}

// "Run 1", "Rec 1", "Km 3" — numbered per type; single-occurrence types
// (Warmup, Cooldown) keep the bare label. STEADY laps that aren't actually
// ~1km each (e.g. a progressive-pace run lapped manually on the watch)
// fall back to the generic lapType.run label instead of a misleading "Km N"
export function lapLabels(
  laps: ActivityLap[],
  t: (key: string) => string,
): string[] {
  const steadyIsKm = isKmAligned(laps.filter((l) => l.lapType === 'STEADY'));

  const perType: Record<string, number> = {};
  for (const lap of laps) {
    perType[lap.lapType] = (perType[lap.lapType] ?? 0) + 1;
  }
  const counters: Record<string, number> = {};
  return laps.map((lap) => {
    const key =
      lap.lapType === 'STEADY' && !steadyIsKm
        ? LAP_TYPE_BASE.RUN
        : LAP_TYPE_BASE[lap.lapType];
    const base = key ? t(key) : lap.lapType;
    counters[lap.lapType] = (counters[lap.lapType] ?? 0) + 1;
    return perType[lap.lapType] > 1 ? `${base} ${counters[lap.lapType]}` : base;
  });
}

// km in → the user's distance unit out ("12.4"), no suffix — pair with
// distanceLabel() from lib/units
export function formatDistance(km: number, unit?: DistanceUnit): string {
  return kmToDisplay(km, unit).toFixed(1);
}

// "5:12" — pace in the user's distance unit, no suffix
export function formatPaceValue(
  secPerKm: number | null,
  unit?: DistanceUnit,
): string {
  if (!secPerKm || !isFinite(secPerKm)) return '—';
  const secPerUnit = paceToDisplay(secPerKm, unit);
  let min = Math.floor(secPerUnit / 60);
  let sec = Math.round(secPerUnit % 60);
  if (sec === 60) {
    min++;
    sec = 0;
  }
  return `${min}:${sec.toString().padStart(2, '0')}`;
}

// "5:12 /km" | "8:23 /mi"
export function formatPace(
  secPerKm: number | null,
  unit?: DistanceUnit,
): string {
  const value = formatPaceValue(secPerKm, unit);
  return value === '—' ? value : `${value} /${distanceLabel(unit)}`;
}

// "29h 16m" | "42min" — rail totals
export function formatDuration(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.round((sec % 3600) / 60);
  return h > 0 ? `${h}h ${m.toString().padStart(2, '0')}m` : `${m}min`;
}

// "1h11" | "58min" — activity rows
export function formatDurationShort(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.round((sec % 3600) / 60);
  return h > 0 ? `${h}h${m.toString().padStart(2, '0')}` : `${m}min`;
}

// "4:32" — lap durations
export function formatMinSec(sec: number): string {
  let m = Math.floor(sec / 60);
  let s = Math.round(sec % 60);
  if (s === 60) {
    m++;
    s = 0;
  }
  return `${m}:${s.toString().padStart(2, '0')}`;
}

// "21:46" | "1:51:45" — best-effort times, hours shown only when ≥ 1h
export function formatHms(sec: number): string {
  const h = Math.floor(sec / 3600);
  if (h === 0) return formatMinSec(sec);
  const m = Math.floor((sec % 3600) / 60);
  const s = Math.round(sec % 60);
  return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

// "DD/MM"
export function formatDayMonth(d: Date): string {
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`;
}

// removing dot from toLocaleDateString
export function formatMonthShort(d: Date): string {
  return d
    .toLocaleDateString(currentIntlLocale(), { month: 'short' })
    .replace('.', '');
}

// January 2026
export function formatMonthLong(d: Date): string {
  const s = d.toLocaleDateString(currentIntlLocale(), {
    month: 'long',
    year: 'numeric',
  });
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export function formatNumber(n: number): string {
  return n.toLocaleString(currentIntlLocale());
}

// "Jul 2025"
export function formatMonthShortYear(d: Date): string {
  return `${formatMonthShort(d)} ${d.getFullYear()}`;
}

// "Jul 5"
export function formatMonthDay(d: Date): string {
  return `${formatMonthShort(d)} ${d.getDate()}`;
}

// "Jul 5, 2025"
export function formatMonthDayYear(d: Date): string {
  return `${formatMonthDay(d)}, ${d.getFullYear()}`;
}

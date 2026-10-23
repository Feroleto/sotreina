// Display/entry units (User.distanceUnit / User.weightUnit). The API and the
// database always speak km and kg — conversion happens only here, at the
// edges: when a number is shown and when one typed by the user is sent.
//
// The current preference is module state set by AuthProvider on every
// render (same idiom as currentIntlLocale() in dateLocale.ts), so formatters
// deep in the tree don't need the user threaded through. Every helper takes
// the unit as an optional last argument: callers that must stay metric
// (Analysis pace zones, the lap editor) pass 'KM' explicitly.

export type DistanceUnit = 'KM' | 'MI';
export type WeightUnit = 'KG' | 'LB';

export interface UnitPrefs {
  distanceUnit: DistanceUnit;
  weightUnit: WeightUnit;
}

export const DEFAULT_UNITS: UnitPrefs = {
  distanceUnit: 'KM',
  weightUnit: 'KG',
};

// exact by definition (international yard and pound, 1959)
export const KM_PER_MI = 1.609344;
export const KG_PER_LB = 0.45359237;

let current: UnitPrefs = DEFAULT_UNITS;

export function setUnitPrefs(
  prefs: Partial<UnitPrefs> | null | undefined,
): void {
  current = {
    distanceUnit: prefs?.distanceUnit ?? DEFAULT_UNITS.distanceUnit,
    weightUnit: prefs?.weightUnit ?? DEFAULT_UNITS.weightUnit,
  };
}

export function currentUnits(): UnitPrefs {
  return current;
}

// ---- distance ----

export function kmToDisplay(
  km: number,
  unit: DistanceUnit = current.distanceUnit,
): number {
  return unit === 'MI' ? km / KM_PER_MI : km;
}

export function displayToKm(
  value: number,
  unit: DistanceUnit = current.distanceUnit,
): number {
  return unit === 'MI' ? value * KM_PER_MI : value;
}

/** "km" | "mi" — the same in pt and en */
export function distanceLabel(
  unit: DistanceUnit = current.distanceUnit,
): string {
  return unit === 'MI' ? 'mi' : 'km';
}

// weekly distance goals are whole km in the DB (User.weeklyRunKmGoal) and
// whole units on screen. Any whole mile survives the trip: the km rounding
// error (≤ 0.5 km) is under half a mile, so it rounds back to the same mile
export function goalToDisplay(
  km: number,
  unit: DistanceUnit = current.distanceUnit,
): number {
  return Math.round(kmToDisplay(km, unit));
}

export function goalFromDisplay(
  value: number,
  unit: DistanceUnit = current.distanceUnit,
): number {
  return Math.round(displayToKm(value, unit));
}

/** seconds per km → seconds per display unit (pace grows with the unit) */
export function paceToDisplay(
  secPerKm: number,
  unit: DistanceUnit = current.distanceUnit,
): number {
  return unit === 'MI' ? secPerKm * KM_PER_MI : secPerKm;
}

// ---- weight ----

// weightKg is Decimal(6,2) in the schema: anything finer is lost on save
function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export function kgToDisplay(
  kg: number,
  unit: WeightUnit = current.weightUnit,
): number {
  // lb shown to 0.1: 45 lb is stored as 20.41 kg, which reads back as
  // 44.996 lb — one decimal is what makes the round trip land on 45 again
  return unit === 'LB' ? Math.round((kg / KG_PER_LB) * 10) / 10 : round2(kg);
}

export function displayToKg(
  value: number,
  unit: WeightUnit = current.weightUnit,
): number {
  return round2(unit === 'LB' ? value * KG_PER_LB : value);
}

/** "kg" | "lb" */
export function weightLabel(unit: WeightUnit = current.weightUnit): string {
  return unit === 'LB' ? 'lb' : 'kg';
}

/** "45" | "22.5" — a stored weight in the display unit, no unit suffix */
export function formatWeight(
  kg: number,
  unit: WeightUnit = current.weightUnit,
): string {
  return String(kgToDisplay(kg, unit));
}

/**
 * training volume (Σ weight × reps) in thousands of the display unit, one
 * decimal: "12.3" — read together with volumeLabel() ("t" | "k lb")
 */
export function formatVolume(
  kg: number,
  unit: WeightUnit = current.weightUnit,
): string {
  const value = unit === 'LB' ? kg / KG_PER_LB : kg;
  return (value / 1000).toFixed(1);
}

export function volumeLabel(unit: WeightUnit = current.weightUnit): string {
  return unit === 'LB' ? 'k lb' : 't';
}

import { isoWeekday, daysInRange } from './plan-dates';

// What the Plano da semana says for each day: the Padrão version in force on
// that day, overridden per area by that date's Ajuste. Pure, so the same rule
// serves GET /plan/days and the checks behind every mutation

export type PlanArea = 'RUN' | 'GYM';
export type PlanEntryState = 'PLANNED' | 'SKIPPED';

export const PLAN_AREAS: readonly PlanArea[] = ['RUN', 'GYM'];

export interface PatternSlotInput {
  weekday: number;
  area: PlanArea;
  templateId: string | null;
  templateName: string | null;
}

export interface VersionInput {
  effectiveFrom: string;
  slots: PatternSlotInput[];
}

export interface AdjustmentInput {
  date: string;
  area: PlanArea;
  state: PlanEntryState;
  templateId: string | null;
  templateName: string | null;
  movedFromDate: string | null;
  movedToDate: string | null;
}

export interface PlanEntry {
  area: PlanArea;
  state: PlanEntryState;
  source: 'PATTERN' | 'ADJUSTMENT';
  templateId: string | null;
  templateName: string | null;
  movedFrom: string | null;
  movedTo: string | null;
}

export interface PlanDay {
  date: string;
  /** the Padrão in force on this day has at least one slot */
  active: boolean;
  entries: PlanEntry[];
}

/** the version in force on `date`: the latest one starting on or before it */
export function versionOn(
  versions: VersionInput[],
  date: string,
): VersionInput | null {
  let found: VersionInput | null = null;
  for (const v of versions) {
    if (
      v.effectiveFrom <= date &&
      (!found || v.effectiveFrom > found.effectiveFrom)
    )
      found = v;
  }
  return found;
}

export function isActiveOn(versions: VersionInput[], date: string): boolean {
  return (versionOn(versions, date)?.slots.length ?? 0) > 0;
}

/** what the Padrão alone plans for `area` on `date`, ignoring Ajustes */
export function patternEntry(
  versions: VersionInput[],
  date: string,
  area: PlanArea,
): { templateId: string | null; templateName: string | null } | null {
  const weekday = isoWeekday(date);
  const slot = versionOn(versions, date)?.slots.find(
    (s) => s.weekday === weekday && s.area === area,
  );
  return slot
    ? { templateId: slot.templateId, templateName: slot.templateName }
    : null;
}

export function resolveDays(input: {
  versions: VersionInput[];
  adjustments: AdjustmentInput[];
  from: string;
  to: string;
}): PlanDay[] {
  const adjustmentByKey = new Map(
    input.adjustments.map((a) => [`${a.date}|${a.area}`, a]),
  );
  return daysInRange(input.from, input.to).map((date) => {
    if (!isActiveOn(input.versions, date))
      return { date, active: false, entries: [] };
    const entries: PlanEntry[] = [];
    for (const area of PLAN_AREAS) {
      const pattern = patternEntry(input.versions, date, area);
      const adjustment = adjustmentByKey.get(`${date}|${area}`);
      if (adjustment) {
        // a Folga of something the current Padrão no longer plans has
        // nothing left to skip — unless it's the emptied half of a move
        if (
          adjustment.state === 'SKIPPED' &&
          !pattern &&
          !adjustment.movedToDate
        )
          continue;
        entries.push({
          area,
          state: adjustment.state,
          source: 'ADJUSTMENT',
          templateId: adjustment.templateId,
          templateName: adjustment.templateName,
          movedFrom: adjustment.movedFromDate,
          movedTo: adjustment.movedToDate,
        });
      } else if (pattern) {
        entries.push({
          area,
          state: 'PLANNED',
          source: 'PATTERN',
          templateId: pattern.templateId,
          templateName: pattern.templateName,
          movedFrom: null,
          movedTo: null,
        });
      }
    }
    return { date, active: true, entries };
  });
}

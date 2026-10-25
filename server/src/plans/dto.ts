import { BadRequestException } from '@nestjs/common';
import { PLAN_AREAS, type PlanArea } from './plan-resolver';
import type { DayChange } from './plan-rules';
import { addDays } from '../common/timezone';

// Manual validation, no class-validator — same convention as meals/dto.ts

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** GET /plan/days covers at most this many days (two months: room for a monthly adherence view later) */
export const MAX_DAYS_RANGE = 62;

export interface PatternSlot {
  weekday: number;
  area: PlanArea;
  templateId: string | null;
}

export interface SavePatternInput {
  slots: PatternSlot[];
}

export type DayChangeInput = Partial<Record<PlanArea, DayChange>>;

export interface MoveInput {
  area: PlanArea;
  from: string;
  to: string;
}

function asObject(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw new BadRequestException('Request body must be an object');
  }
  return body as Record<string, unknown>;
}

export function parseDate(value: unknown, field: string): string {
  // the round trip rejects impossible days like 2026-02-30
  if (
    typeof value !== 'string' ||
    !DATE_RE.test(value) ||
    addDays(value, 0) !== value
  ) {
    throw new BadRequestException(`${field} must be a date (YYYY-MM-DD)`);
  }
  return value;
}

function parseArea(value: unknown, field: string): PlanArea {
  if (typeof value !== 'string' || !PLAN_AREAS.includes(value as PlanArea)) {
    throw new BadRequestException(
      `${field} must be one of: ${PLAN_AREAS.join(', ')}`,
    );
  }
  return value as PlanArea;
}

function parseTemplateId(value: unknown, field: string): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new BadRequestException(
      `${field} must be a non-empty string or null`,
    );
  }
  return value.trim();
}

export function parseSavePatternInput(body: unknown): SavePatternInput {
  const { slots } = asObject(body);
  if (!Array.isArray(slots))
    throw new BadRequestException('slots must be an array');

  const seen = new Set<string>();
  const parsed = slots.map((raw, idx) => {
    const slot = asObject(raw);
    const { weekday } = slot;
    if (
      typeof weekday !== 'number' ||
      !Number.isInteger(weekday) ||
      weekday < 1 ||
      weekday > 7
    ) {
      throw new BadRequestException(
        `slots[${idx}].weekday must be an integer from 1 (Monday) to 7 (Sunday)`,
      );
    }
    const area = parseArea(slot.area, `slots[${idx}].area`);
    const templateId = parseTemplateId(
      slot.templateId,
      `slots[${idx}].templateId`,
    );
    if (area === 'RUN' && templateId !== null) {
      throw new BadRequestException(
        `slots[${idx}].templateId is only valid for GYM`,
      );
    }
    const key = `${weekday}|${area}`;
    if (seen.has(key))
      throw new BadRequestException(
        `slots has ${area} twice on weekday ${weekday}`,
      );
    seen.add(key);
    return { weekday, area, templateId };
  });
  return { slots: parsed };
}

export function parseDaysQuery(
  from: unknown,
  to: unknown,
): { from: string; to: string } {
  const start = parseDate(from, 'from');
  const end = parseDate(to, 'to');
  if (start > end) throw new BadRequestException('from must not be after to');
  if (addDays(start, MAX_DAYS_RANGE - 1) < end) {
    throw new BadRequestException(
      `the range must not exceed ${MAX_DAYS_RANGE} days`,
    );
  }
  return { from: start, to: end };
}

// `entries` maps each area to a change: an absent key leaves that area alone,
// `null` undoes its Ajuste (back to the Padrão)
export function parseDayChangeInput(body: unknown): DayChangeInput {
  const { entries } = asObject(body);
  const map = asObject(entries);
  const result: DayChangeInput = {};
  for (const [key, raw] of Object.entries(map)) {
    const area = parseArea(key, 'entries key');
    if (raw === null) {
      result[area] = null;
      continue;
    }
    const entry = asObject(raw);
    if (entry.state !== 'PLANNED' && entry.state !== 'SKIPPED') {
      throw new BadRequestException(
        `entries.${area}.state must be PLANNED or SKIPPED`,
      );
    }
    const templateId = parseTemplateId(
      entry.templateId,
      `entries.${area}.templateId`,
    );
    if (entry.state === 'SKIPPED' && templateId !== null) {
      throw new BadRequestException(
        `entries.${area}.templateId is only valid when PLANNED`,
      );
    }
    result[area] = { state: entry.state, templateId };
  }
  if (Object.keys(result).length === 0)
    throw new BadRequestException('entries must not be empty');
  return result;
}

export function parseMoveInput(body: unknown): MoveInput {
  const obj = asObject(body);
  return {
    area: parseArea(obj.area, 'area'),
    from: parseDate(obj.from, 'from'),
    to: parseDate(obj.to, 'to'),
  };
}

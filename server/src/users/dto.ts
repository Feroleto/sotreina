import { BadRequestException } from '@nestjs/common';
import type { Area, DistanceUnit, WeightUnit } from '@prisma/client';

// Manual validation, no class-validator — same convention as auth/dto.ts

const AREAS: readonly Area[] = ['RUN', 'GYM', 'DIET'];
const DISTANCE_UNITS: readonly DistanceUnit[] = ['KM', 'MI'];
const WEIGHT_UNITS: readonly WeightUnit[] = ['KG', 'LB'];

/**
 * enabledAreas must keep at least one area: the empty list is what marks a
 * user who hasn't chosen yet (the client shows the area picker for it), so
 * accepting [] here would send the user back through onboarding
 */
export function parseEnabledAreas(value: unknown): Area[] | undefined {
  if (value === undefined) return undefined;
  if (
    !Array.isArray(value) ||
    value.length === 0 ||
    !value.every((v) => typeof v === 'string' && (AREAS as readonly string[]).includes(v))
  ) {
    throw new BadRequestException(
      `enabledAreas must be a non-empty array of ${AREAS.join(', ')}`,
    );
  }
  // stored in canonical order, deduplicated — order carries no meaning
  return AREAS.filter((a) => value.includes(a));
}

function parseEnum<T extends string>(
  field: string,
  allowed: readonly T[],
  value: unknown,
): T | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || !(allowed as readonly string[]).includes(value)) {
    throw new BadRequestException(`${field} must be one of ${allowed.join(', ')}`);
  }
  return value as T;
}

export function parseDistanceUnit(value: unknown): DistanceUnit | undefined {
  return parseEnum('distanceUnit', DISTANCE_UNITS, value);
}

export function parseWeightUnit(value: unknown): WeightUnit | undefined {
  return parseEnum('weightUnit', WEIGHT_UNITS, value);
}

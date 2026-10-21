import { BadRequestException } from '@nestjs/common';
import type { Area } from '@prisma/client';

// Manual validation, no class-validator — same convention as auth/dto.ts

const AREAS: readonly Area[] = ['RUN', 'GYM', 'DIET'];

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

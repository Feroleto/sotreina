import { BadRequestException } from '@nestjs/common';
import { SetType } from '@prisma/client';

// Manual validation, no class-validator (not used anywhere in this project) —
// same convention as UsersController.update / lap-editor/dto.ts

const MAX_LIMIT = 100;
const MAX_PAGE = 1_000_000;
const DEFAULT_PAGE = 1;
const DEFAULT_LIMIT = 20;

export function parseWorkoutsPagination(
  page?: string,
  limit?: string,
): { page: number; limit: number } {
  return {
    page: parseIntParam('page', page, 1, MAX_PAGE) ?? DEFAULT_PAGE,
    limit: parseIntParam('limit', limit, 1, MAX_LIMIT) ?? DEFAULT_LIMIT,
  };
}

function parseIntParam(
  name: string,
  value: string | undefined,
  min: number,
  max: number,
): number | undefined {
  if (value === undefined) return undefined;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new BadRequestException(
      `Invalid ${name}. Expected an integer between ${min} and ${max}.`,
    );
  }
  return parsed;
}

export interface StartWorkoutInput {
  templateId?: string;
}

// body is optional entirely (free workout) — only validated when present
export function parseStartWorkoutInput(body: unknown): StartWorkoutInput {
  if (body === undefined || body === null) return {};
  if (typeof body !== 'object') {
    throw new BadRequestException('Request body must be an object');
  }
  const { templateId } = body as Record<string, unknown>;
  if (templateId === undefined || templateId === null) return {};
  if (typeof templateId !== 'string' || templateId.trim().length === 0) {
    throw new BadRequestException('templateId must be a non-empty string');
  }
  return { templateId };
}

export interface AddExerciseInput {
  exerciseId: string;
}

export function parseAddExerciseInput(body: unknown): AddExerciseInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { exerciseId } = body as Record<string, unknown>;
  if (typeof exerciseId !== 'string' || exerciseId.trim().length === 0) {
    throw new BadRequestException('exerciseId is required');
  }
  return { exerciseId };
}

export interface FinishWorkoutInput {
  syncTemplate?: boolean;
}

// body is optional entirely — omitting it (or syncTemplate) finishes without
// touching the originating template, the common case (free workouts, or the
// user declining the "update the routine too?" prompt)
export function parseFinishWorkoutInput(body: unknown): FinishWorkoutInput {
  if (body === undefined || body === null) return {};
  if (typeof body !== 'object') {
    throw new BadRequestException('Request body must be an object');
  }
  const { syncTemplate } = body as Record<string, unknown>;
  if (syncTemplate === undefined || syncTemplate === null) return {};
  if (typeof syncTemplate !== 'boolean') {
    throw new BadRequestException('syncTemplate must be a boolean');
  }
  return { syncTemplate };
}

export interface ReorderExerciseInput {
  order: number;
}

// order is the only field here — unlike workout-templates' equivalent
// (which folds order in alongside targetSets/targetRepsMin/Max), a
// WorkoutExercise carries no targets of its own (those live on the
// originating WorkoutTemplateExercise, see WorkoutsService.buildDetail)
export function parseReorderExerciseInput(body: unknown): ReorderExerciseInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { order } = body as Record<string, unknown>;
  if (typeof order !== 'number' || !Number.isInteger(order) || order < 1 || order > 1000) {
    throw new BadRequestException('order must be an integer between 1 and 1000');
  }
  return { order };
}

export interface SetInput {
  weightKg?: number;
  reps?: number;
  rpe?: number;
  setType?: SetType;
}

// used both for logging a new set (all fields optional — a bodyweight set
// may have reps only) and for PATCHing an existing one (partial edit)
export function parseSetInput(body: unknown): SetInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { weightKg, reps, rpe, setType } = body as Record<string, unknown>;

  const result: SetInput = {};

  if (weightKg !== undefined && weightKg !== null) {
    if (typeof weightKg !== 'number' || !Number.isFinite(weightKg) || weightKg < 0) {
      throw new BadRequestException('weightKg must be a non-negative number');
    }
    result.weightKg = weightKg;
  }

  if (reps !== undefined && reps !== null) {
    if (typeof reps !== 'number' || !Number.isInteger(reps) || reps < 0) {
      throw new BadRequestException('reps must be a non-negative integer');
    }
    result.reps = reps;
  }

  if (rpe !== undefined && rpe !== null) {
    if (typeof rpe !== 'number' || !Number.isFinite(rpe) || rpe < 0 || rpe > 10) {
      throw new BadRequestException('rpe must be a number between 0 and 10');
    }
    result.rpe = rpe;
  }

  if (setType !== undefined && setType !== null) {
    if (typeof setType !== 'string' || !Object.values(SetType).includes(setType as SetType)) {
      throw new BadRequestException(
        `Invalid setType. Expected one of: ${Object.values(SetType).join(', ')}`,
      );
    }
    result.setType = setType as SetType;
  }

  return result;
}

export interface AddSetInput extends SetInput {
  clientId?: string;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// POST only: PATCH never takes clientId (it's the identity of the set
// creation, not an editable field)
export function parseAddSetInput(body: unknown): AddSetInput {
  const result: AddSetInput = parseSetInput(body);
  const { clientId } = body as Record<string, unknown>;
  if (clientId !== undefined && clientId !== null) {
    if (typeof clientId !== 'string' || !UUID_RE.test(clientId)) {
      throw new BadRequestException('clientId must be a UUID');
    }
    result.clientId = clientId;
  }
  return result;
}

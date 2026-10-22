import { BadRequestException } from '@nestjs/common';

// Manual validation, no class-validator — same convention as
// UsersController.update / exercises/dto.ts / workouts/dto.ts

const MIN_TARGET_SETS = 1;
const MAX_TARGET_SETS = 20;
const MIN_TARGET_REPS = 1;
const MAX_TARGET_REPS = 100;
const MIN_REST_SECONDS = 15;
const MAX_REST_SECONDS = 600;

export interface TemplateExerciseTargets {
  targetSets?: number;
  targetRepsMin?: number;
  targetRepsMax?: number;
  restSeconds?: number;
}

function parseOptionalInt(
  field: string,
  value: unknown,
  min: number,
  max: number,
): number | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'number' || !Number.isInteger(value) || value < min || value > max) {
    throw new BadRequestException(
      `${field} must be an integer between ${min} and ${max}`,
    );
  }
  return value;
}

function parseTargets(body: Record<string, unknown>): TemplateExerciseTargets {
  const targetSets = parseOptionalInt(
    'targetSets',
    body.targetSets,
    MIN_TARGET_SETS,
    MAX_TARGET_SETS,
  );
  const targetRepsMin = parseOptionalInt(
    'targetRepsMin',
    body.targetRepsMin,
    MIN_TARGET_REPS,
    MAX_TARGET_REPS,
  );
  const targetRepsMax = parseOptionalInt(
    'targetRepsMax',
    body.targetRepsMax,
    MIN_TARGET_REPS,
    MAX_TARGET_REPS,
  );

  if (targetRepsMin !== undefined && targetRepsMax !== undefined && targetRepsMin > targetRepsMax) {
    throw new BadRequestException('targetRepsMin must be <= targetRepsMax');
  }

  const restSeconds = parseOptionalInt(
    'restSeconds',
    body.restSeconds,
    MIN_REST_SECONDS,
    MAX_REST_SECONDS,
  );

  return { targetSets, targetRepsMin, targetRepsMax, restSeconds };
}

export interface CreateTemplateExerciseInput extends TemplateExerciseTargets {
  exerciseId: string;
}

// shared by create (exercises required, defaults to []) and update
// (exercises optional — presence means "replace the whole list", see
// parseUpdateTemplateInput)
function parseTemplateExercises(value: unknown): CreateTemplateExerciseInput[] {
  if (!Array.isArray(value)) {
    throw new BadRequestException('exercises must be an array');
  }
  return value.map((raw, idx) => {
    if (typeof raw !== 'object' || raw === null) {
      throw new BadRequestException(`exercises[${idx}] must be an object`);
    }
    const { exerciseId, ...rest } = raw as Record<string, unknown>;
    if (typeof exerciseId !== 'string' || exerciseId.trim().length === 0) {
      throw new BadRequestException(`exercises[${idx}].exerciseId is required`);
    }
    return { exerciseId, ...parseTargets(rest) };
  });
}

export interface CreateTemplateInput {
  name: string;
  description?: string;
  exercises: CreateTemplateExerciseInput[];
}

export function parseCreateTemplateInput(body: unknown): CreateTemplateInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { name, description, exercises } = body as Record<string, unknown>;

  if (typeof name !== 'string' || name.trim().length === 0) {
    throw new BadRequestException('name is required');
  }
  if (description !== undefined && description !== null && typeof description !== 'string') {
    throw new BadRequestException('description must be a string');
  }

  const parsedExercises =
    exercises !== undefined && exercises !== null ? parseTemplateExercises(exercises) : [];

  return {
    name: name.trim(),
    description: description ?? undefined,
    exercises: parsedExercises,
  };
}

export interface UpdateTemplateInput {
  name?: string;
  description?: string | null;
  // undefined = leave the exercise list untouched; an array (including [])
  // replaces it wholesale — the editor always sends the full list it built
  // in memory, there's no partial/diffed update
  exercises?: CreateTemplateExerciseInput[];
}

export function parseUpdateTemplateInput(body: unknown): UpdateTemplateInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { name, description, exercises } = body as Record<string, unknown>;

  const result: UpdateTemplateInput = {};
  if (name !== undefined) {
    if (typeof name !== 'string' || name.trim().length === 0) {
      throw new BadRequestException('name must be a non-empty string');
    }
    result.name = name.trim();
  }
  if (description !== undefined) {
    if (description !== null && typeof description !== 'string') {
      throw new BadRequestException('description must be a string or null');
    }
    result.description = description;
  }
  if (exercises !== undefined) {
    result.exercises = parseTemplateExercises(exercises);
  }
  return result;
}

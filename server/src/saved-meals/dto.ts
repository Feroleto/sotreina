import { BadRequestException } from '@nestjs/common';

// Manual validation, no class-validator — same convention as foods/dto.ts,
// food-logs/dto.ts, workout-templates/dto.ts

export interface CreateSavedMealItemInput {
  foodId: string;
  quantity: number;
}

// shared by create (items required, defaults to []) and update (items
// optional — presence means "replace the whole list", see
// parseUpdateSavedMealInput), same undefined-vs-array semantics as
// workout-templates/dto.ts parseTemplateExercises
function parseSavedMealItems(value: unknown): CreateSavedMealItemInput[] {
  if (!Array.isArray(value)) {
    throw new BadRequestException('items must be an array');
  }
  return value.map((raw, idx) => {
    if (typeof raw !== 'object' || raw === null) {
      throw new BadRequestException(`items[${idx}] must be an object`);
    }
    const { foodId, quantity } = raw as Record<string, unknown>;
    if (typeof foodId !== 'string' || foodId.trim().length === 0) {
      throw new BadRequestException(`items[${idx}].foodId is required`);
    }
    if (typeof quantity !== 'number' || !Number.isFinite(quantity) || quantity <= 0) {
      throw new BadRequestException(`items[${idx}].quantity must be a positive number`);
    }
    return { foodId, quantity };
  });
}

export interface CreateSavedMealInput {
  name: string;
  items: CreateSavedMealItemInput[];
}

export function parseCreateSavedMealInput(body: unknown): CreateSavedMealInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { name, items } = body as Record<string, unknown>;

  if (typeof name !== 'string' || name.trim().length === 0) {
    throw new BadRequestException('name is required');
  }

  return {
    name: name.trim(),
    items: items !== undefined && items !== null ? parseSavedMealItems(items) : [],
  };
}

export interface UpdateSavedMealInput {
  name?: string;
  // undefined = leave the item list untouched; an array (including [])
  // replaces it wholesale — same semantics as UpdateTemplateInput.exercises
  items?: CreateSavedMealItemInput[];
}

export function parseUpdateSavedMealInput(body: unknown): UpdateSavedMealInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { name, items } = body as Record<string, unknown>;

  const result: UpdateSavedMealInput = {};
  if (name !== undefined) {
    if (typeof name !== 'string' || name.trim().length === 0) {
      throw new BadRequestException('name must be a non-empty string');
    }
    result.name = name.trim();
  }
  if (items !== undefined) {
    result.items = parseSavedMealItems(items);
  }
  return result;
}

export interface ApplySavedMealInput {
  /** id of one of the user's Meal rows — ownership asserted in applyToLog */
  mealId: string;
  loggedAt: Date;
  /**
   * optional idempotency key for the whole apply (the iOS app sends one):
   * a resend after a lost response returns the Registros already written
   * instead of a second copy of the saved meal. The web never sends it.
   */
  clientId?: string;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// same mealId/loggedAt validation as food-logs/dto.ts parseCreateFoodLogInput
export function parseApplySavedMealInput(body: unknown): ApplySavedMealInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }
  const { mealId, loggedAt, clientId } = body as Record<string, unknown>;

  if (typeof mealId !== 'string' || mealId.trim().length === 0) {
    throw new BadRequestException('mealId is required');
  }
  if (typeof loggedAt !== 'string') {
    throw new BadRequestException('loggedAt is required');
  }
  const parsedLoggedAt = new Date(loggedAt);
  if (Number.isNaN(parsedLoggedAt.getTime())) {
    throw new BadRequestException('loggedAt must be a valid ISO date string');
  }

  const result: ApplySavedMealInput = { mealId: mealId.trim(), loggedAt: parsedLoggedAt };
  if (clientId !== undefined && clientId !== null) {
    if (typeof clientId !== 'string' || !UUID_RE.test(clientId)) {
      throw new BadRequestException('clientId must be a UUID');
    }
    result.clientId = clientId;
  }
  return result;
}

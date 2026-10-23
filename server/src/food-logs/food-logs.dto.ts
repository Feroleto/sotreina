import { BadRequestException } from '@nestjs/common';

// Manual validation, no class-validator — same convention as foods/dto.ts

export interface CreateFoodLogInput {
  foodId: string;
  /** always grams, whatever unit the UI offered */
  quantity: number;
  /** display hint only — see FoodLog.enteredAsServing in schema.prisma */
  enteredAsServing: boolean;
  /**
   * id of one of the user's Meal rows. Unlike the closed MealType enum this
   * replaced, shape validation proves nothing here — FoodLogsService.create
   * asserts ownership before writing.
   */
  mealId: string;
  loggedAt: Date;
  /**
   * optional idempotency key (the iOS app sends one per cart item): a resend
   * after a lost response returns the stored log instead of a duplicate.
   * Same contract as WorkoutSet.clientId; the web never sends it.
   */
  clientId?: string;
}

export interface UpdateFoodLogInput {
  quantity: number;
  enteredAsServing: boolean;
}

export function parseCreateFoodLogInput(body: unknown): CreateFoodLogInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }

  const { foodId, quantity, enteredAsServing, mealId, loggedAt, clientId } = body as Record<
    string,
    unknown
  >;

  if (typeof foodId !== 'string' || foodId.trim().length === 0) {
    throw new BadRequestException('foodId is required');
  }
  const parsedQuantity = parseQuantity(quantity);
  const parsedEnteredAsServing = parseEnteredAsServing(enteredAsServing);
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

  const result: CreateFoodLogInput = {
    foodId: foodId.trim(),
    quantity: parsedQuantity,
    enteredAsServing: parsedEnteredAsServing,
    mealId: mealId.trim(),
    loggedAt: parsedLoggedAt,
  };
  if (clientId !== undefined && clientId !== null) {
    if (typeof clientId !== 'string' || !UUID_RE.test(clientId)) {
      throw new BadRequestException('clientId must be a UUID');
    }
    result.clientId = clientId;
  }
  return result;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// PATCH only ever changes how much was eaten — foodId/mealId/loggedAt are
// not editable (moving a log to another meal would be a different feature)
export function parseUpdateFoodLogInput(body: unknown): UpdateFoodLogInput {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be an object');
  }

  const { quantity, enteredAsServing } = body as Record<string, unknown>;

  return {
    quantity: parseQuantity(quantity),
    enteredAsServing: parseEnteredAsServing(enteredAsServing),
  };
}

function parseQuantity(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    throw new BadRequestException('quantity must be a positive number');
  }
  return value;
}

function parseEnteredAsServing(value: unknown): boolean {
  if (value === undefined || value === null) return false;
  if (typeof value !== 'boolean') {
    throw new BadRequestException('enteredAsServing must be a boolean');
  }
  return value;
}

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

// day boundary is computed in UTC — same accepted imprecision already
// documented for GET /activities/weekly-distance (see CLAUDE.md "Problemas
// conhecidos"); a log made between 21h and midnight BRT can land on the
// "wrong" day
export function parseDateQuery(date?: string): string {
  if (!date || !DATE_PATTERN.test(date)) {
    throw new BadRequestException('date must be in YYYY-MM-DD format');
  }
  return date;
}

const ALLOWED_HISTORY_DAYS = [7, 14];

export function parseDaysQuery(days?: string): number {
  const parsed = Number(days);
  if (!ALLOWED_HISTORY_DAYS.includes(parsed)) {
    throw new BadRequestException(
      `days must be one of: ${ALLOWED_HISTORY_DAYS.join(', ')}`,
    );
  }
  return parsed;
}

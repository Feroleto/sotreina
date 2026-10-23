import { describe, it, expect } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import {
  parseCreateFoodLogInput,
  parseDateQuery,
  parseDaysQuery,
  parseUpdateFoodLogInput,
} from 'src/food-logs/food-logs.dto';

describe('parseCreateFoodLogInput', () => {
  const validBody = {
    foodId: 'food1',
    quantity: 150,
    mealId: 'meal1',
    loggedAt: '2026-07-29T12:00:00.000Z',
  };

  it('accepts a valid body and parses loggedAt into a Date', () => {
    const result = parseCreateFoodLogInput(validBody);

    expect(result.foodId).toBe('food1');
    expect(result.quantity).toBe(150);
    expect(result.mealId).toBe('meal1');
    expect(result.loggedAt).toEqual(new Date('2026-07-29T12:00:00.000Z'));
  });

  it('defaults enteredAsServing to false when the client omits it', () => {
    expect(parseCreateFoodLogInput(validBody).enteredAsServing).toBe(false);
  });

  it('accepts an explicit enteredAsServing flag', () => {
    expect(parseCreateFoodLogInput({ ...validBody, enteredAsServing: true }).enteredAsServing).toBe(
      true,
    );
  });

  it('rejects a non-boolean enteredAsServing', () => {
    expect(() => parseCreateFoodLogInput({ ...validBody, enteredAsServing: 'yes' })).toThrow(
      BadRequestException,
    );
  });

  it('rejects a non-object body', () => {
    expect(() => parseCreateFoodLogInput(null)).toThrow(BadRequestException);
  });

  it('rejects a non-positive quantity', () => {
    expect(() => parseCreateFoodLogInput({ ...validBody, quantity: 0 })).toThrow(
      BadRequestException,
    );
  });

  // the mealId can only be shape-checked here — it names a row, so the real
  // guard is the ownership assert in FoodLogsService.create
  it('rejects a missing or blank mealId', () => {
    expect(() => parseCreateFoodLogInput({ ...validBody, mealId: undefined })).toThrow(
      BadRequestException,
    );
    expect(() => parseCreateFoodLogInput({ ...validBody, mealId: '   ' })).toThrow(
      BadRequestException,
    );
  });

  it('rejects an unparseable loggedAt', () => {
    expect(() => parseCreateFoodLogInput({ ...validBody, loggedAt: 'not-a-date' })).toThrow(
      BadRequestException,
    );
  });

  it('accepts a UUID clientId (Swift sends it uppercase)', () => {
    const clientId = '6F1C2B7E-3D4A-4B5C-9E8F-0A1B2C3D4E5F';
    expect(parseCreateFoodLogInput({ ...validBody, clientId }).clientId).toBe(clientId);
  });

  it('treats a missing or null clientId as absent (the web never sends one)', () => {
    expect(parseCreateFoodLogInput(validBody).clientId).toBeUndefined();
    expect(parseCreateFoodLogInput({ ...validBody, clientId: null }).clientId).toBeUndefined();
  });

  it.each([123, '', 'not-a-uuid'])('rejects clientId %j', (clientId) => {
    expect(() => parseCreateFoodLogInput({ ...validBody, clientId })).toThrow(BadRequestException);
  });
});

describe('parseDateQuery', () => {
  it('accepts a well-formed YYYY-MM-DD date', () => {
    expect(parseDateQuery('2026-07-29')).toBe('2026-07-29');
  });

  it('rejects a missing or malformed date', () => {
    expect(() => parseDateQuery(undefined)).toThrow(BadRequestException);
    expect(() => parseDateQuery('07/29/2026')).toThrow(BadRequestException);
    expect(() => parseDateQuery('2026-7-29')).toThrow(BadRequestException);
  });
});

describe('parseUpdateFoodLogInput', () => {
  it('accepts a quantity and defaults enteredAsServing to false', () => {
    expect(parseUpdateFoodLogInput({ quantity: 150 })).toEqual({
      quantity: 150,
      enteredAsServing: false,
    });
  });

  it('accepts an explicit enteredAsServing flag', () => {
    expect(parseUpdateFoodLogInput({ quantity: 100, enteredAsServing: true })).toEqual({
      quantity: 100,
      enteredAsServing: true,
    });
  });

  it('rejects a missing or non-positive quantity', () => {
    expect(() => parseUpdateFoodLogInput({})).toThrow(BadRequestException);
    expect(() => parseUpdateFoodLogInput({ quantity: 0 })).toThrow(BadRequestException);
    expect(() => parseUpdateFoodLogInput({ quantity: -10 })).toThrow(BadRequestException);
  });

  it('ignores fields it does not own (foodId/mealId are not editable)', () => {
    expect(parseUpdateFoodLogInput({ quantity: 80, foodId: 'other', mealId: 'meal2' })).toEqual({
      quantity: 80,
      enteredAsServing: false,
    });
  });

  it('rejects a non-object body', () => {
    expect(() => parseUpdateFoodLogInput(null)).toThrow(BadRequestException);
  });
});

describe('parseDaysQuery', () => {
  it('accepts 7 and 14', () => {
    expect(parseDaysQuery('7')).toBe(7);
    expect(parseDaysQuery('14')).toBe(14);
  });

  it('rejects anything else', () => {
    expect(() => parseDaysQuery(undefined)).toThrow(BadRequestException);
    expect(() => parseDaysQuery('30')).toThrow(BadRequestException);
    expect(() => parseDaysQuery('abc')).toThrow(BadRequestException);
  });
});

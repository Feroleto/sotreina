import { describe, it, expect } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import {
  parseApplySavedMealInput,
  parseCreateSavedMealInput,
  parseUpdateSavedMealInput,
} from 'src/saved-meals/dto';

describe('parseCreateSavedMealInput', () => {
  it('accepts a valid body with items', () => {
    const result = parseCreateSavedMealInput({
      name: 'Café da manhã de sempre',
      items: [
        { foodId: 'food1', quantity: 100 },
        { foodId: 'food2', quantity: 50 },
      ],
    });

    expect(result.name).toBe('Café da manhã de sempre');
    expect(result.items).toEqual([
      { foodId: 'food1', quantity: 100 },
      { foodId: 'food2', quantity: 50 },
    ]);
  });

  it('defaults items to an empty array when omitted', () => {
    const result = parseCreateSavedMealInput({ name: 'Empty meal' });
    expect(result.items).toEqual([]);
  });

  it('rejects a non-object body', () => {
    expect(() => parseCreateSavedMealInput(null)).toThrow(BadRequestException);
  });

  it('rejects a missing name', () => {
    expect(() => parseCreateSavedMealInput({ items: [] })).toThrow(BadRequestException);
  });

  it('rejects a non-array items value', () => {
    expect(() => parseCreateSavedMealInput({ name: 'x', items: 'nope' })).toThrow(
      BadRequestException,
    );
  });

  it('rejects an item missing foodId', () => {
    expect(() =>
      parseCreateSavedMealInput({ name: 'x', items: [{ quantity: 100 }] }),
    ).toThrow(BadRequestException);
  });

  it('rejects an item with a non-positive quantity', () => {
    expect(() =>
      parseCreateSavedMealInput({ name: 'x', items: [{ foodId: 'food1', quantity: 0 }] }),
    ).toThrow(BadRequestException);
  });
});

describe('parseUpdateSavedMealInput', () => {
  it('leaves items undefined when omitted, only touching name', () => {
    const result = parseUpdateSavedMealInput({ name: 'New name' });
    expect(result).toEqual({ name: 'New name' });
  });

  it('accepts an empty items array (wholesale clear)', () => {
    const result = parseUpdateSavedMealInput({ items: [] });
    expect(result.items).toEqual([]);
  });

  it('rejects an empty-string name', () => {
    expect(() => parseUpdateSavedMealInput({ name: '  ' })).toThrow(BadRequestException);
  });
});

describe('parseApplySavedMealInput', () => {
  const validBody = { mealId: 'meal1', loggedAt: '2026-07-30T12:00:00.000Z' };

  it('accepts a valid body and parses loggedAt into a Date', () => {
    const result = parseApplySavedMealInput(validBody);
    expect(result.mealId).toBe('meal1');
    expect(result.loggedAt).toEqual(new Date('2026-07-30T12:00:00.000Z'));
  });

  // shape only — ownership of the target meal is asserted in applyToLog
  it('rejects a missing or blank mealId', () => {
    expect(() => parseApplySavedMealInput({ ...validBody, mealId: undefined })).toThrow(
      BadRequestException,
    );
    expect(() => parseApplySavedMealInput({ ...validBody, mealId: '  ' })).toThrow(
      BadRequestException,
    );
  });

  it('rejects an unparseable loggedAt', () => {
    expect(() => parseApplySavedMealInput({ ...validBody, loggedAt: 'nope' })).toThrow(
      BadRequestException,
    );
  });

  it('leaves clientId out when absent or null (the web never sends it)', () => {
    expect(parseApplySavedMealInput(validBody)).not.toHaveProperty('clientId');
    expect(parseApplySavedMealInput({ ...validBody, clientId: null })).not.toHaveProperty(
      'clientId',
    );
  });

  it('accepts a UUID clientId', () => {
    const clientId = '0f8fad5b-d9cb-469f-a165-70867728950e';
    expect(parseApplySavedMealInput({ ...validBody, clientId }).clientId).toBe(clientId);
  });

  it('rejects a clientId that is not a UUID', () => {
    expect(() => parseApplySavedMealInput({ ...validBody, clientId: 'abc' })).toThrow(
      BadRequestException,
    );
    expect(() => parseApplySavedMealInput({ ...validBody, clientId: 42 })).toThrow(
      BadRequestException,
    );
  });
});

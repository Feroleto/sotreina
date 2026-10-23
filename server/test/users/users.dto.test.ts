import { describe, it, expect } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import { parseDistanceUnit, parseEnabledAreas, parseWeightUnit } from 'src/users/dto';
import { parseFirstName } from 'src/auth/dto';

describe('parseEnabledAreas', () => {
  it('returns undefined when absent (field untouched by the PATCH)', () => {
    expect(parseEnabledAreas(undefined)).toBeUndefined();
  });

  it('dedupes and returns the canonical RUN/GYM/DIET order', () => {
    expect(parseEnabledAreas(['DIET', 'RUN', 'DIET'])).toEqual(['RUN', 'DIET']);
  });

  // [] is the "not chosen yet" marker — accepting it would re-trigger onboarding
  it('rejects an empty list', () => {
    expect(() => parseEnabledAreas([])).toThrow(BadRequestException);
  });

  it.each([['SWIM'], 'RUN', [1], null, [null]])('rejects %j', (value) => {
    expect(() => parseEnabledAreas(value)).toThrow(BadRequestException);
  });
});

describe('parseFirstName', () => {
  it('trims', () => {
    expect(parseFirstName('  Ana  ')).toBe('Ana');
  });

  it.each(['', '   ', 42, null, 'x'.repeat(61)])('rejects %j', (value) => {
    expect(() => parseFirstName(value)).toThrow(BadRequestException);
  });
});

describe('parseDistanceUnit / parseWeightUnit', () => {
  it('returns undefined when absent (field untouched by the PATCH)', () => {
    expect(parseDistanceUnit(undefined)).toBeUndefined();
    expect(parseWeightUnit(undefined)).toBeUndefined();
  });

  it('accepts the enum values', () => {
    expect(parseDistanceUnit('MI')).toBe('MI');
    expect(parseWeightUnit('LB')).toBe('LB');
  });

  // the client sends the enum, never a label or a lowercase variant
  it.each(['mi', 'KG', '', null, 1])('rejects distanceUnit %j', (value) => {
    expect(() => parseDistanceUnit(value)).toThrow(BadRequestException);
  });

  it.each(['lb', 'KM', '', null, 1])('rejects weightUnit %j', (value) => {
    expect(() => parseWeightUnit(value)).toThrow(BadRequestException);
  });
});

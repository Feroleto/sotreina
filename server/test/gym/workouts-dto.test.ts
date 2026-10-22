import { describe, it, expect } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import { parseAddSetInput, parseSetInput } from 'src/workouts/dto';

describe('parseAddSetInput', () => {
  it('accepts a UUID clientId alongside the set fields (Swift sends it uppercase)', () => {
    const clientId = '6F1C2B7E-3D4A-4B5C-9E8F-0A1B2C3D4E5F';
    expect(parseAddSetInput({ weightKg: 80, reps: 5, clientId })).toEqual({
      weightKg: 80,
      reps: 5,
      clientId,
    });
  });

  it('treats a missing or null clientId as absent (the web never sends one)', () => {
    expect(parseAddSetInput({ reps: 5 })).toEqual({ reps: 5 });
    expect(parseAddSetInput({ reps: 5, clientId: null })).toEqual({ reps: 5 });
  });

  it.each([123, '', 'not-a-uuid', 'x'.repeat(36)])('rejects clientId %j', (clientId) => {
    expect(() => parseAddSetInput({ reps: 5, clientId })).toThrow(BadRequestException);
  });

  it('PATCH parsing ignores clientId — it identifies the creation, not an editable field', () => {
    expect(
      parseSetInput({ reps: 5, clientId: '6f1c2b7e-3d4a-4b5c-9e8f-0a1b2c3d4e5f' }),
    ).toEqual({ reps: 5 });
  });
});

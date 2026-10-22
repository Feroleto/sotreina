import { describe, it, expect } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import { parseCreateTemplateInput, parseUpdateTemplateInput } from 'src/workout-templates/dto';

describe('workout template restSeconds', () => {
  it('accepts a per-exercise rest between 15 and 600 seconds', () => {
    const input = parseCreateTemplateInput({
      name: 'Upper',
      exercises: [
        { exerciseId: 'ex1', restSeconds: 15 },
        { exerciseId: 'ex2', restSeconds: 600 },
      ],
    });
    expect(input.exercises.map((e) => e.restSeconds)).toEqual([15, 600]);
  });

  it('treats a missing or null restSeconds as "use the global default"', () => {
    const input = parseUpdateTemplateInput({
      exercises: [{ exerciseId: 'ex1' }, { exerciseId: 'ex2', restSeconds: null }],
    });
    expect(input.exercises!.map((e) => e.restSeconds)).toEqual([undefined, undefined]);
  });

  it.each([14, 601, 90.5, '90'])('rejects restSeconds %j', (restSeconds) => {
    expect(() =>
      parseCreateTemplateInput({ name: 'Upper', exercises: [{ exerciseId: 'ex1', restSeconds }] }),
    ).toThrow(BadRequestException);
  });
});

import { describe, it, expect } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import {
  parseDate,
  parseDayChangeInput,
  parseDaysQuery,
  parseMoveInput,
  parseSavePatternInput,
} from 'src/plans/dto';

describe('plans dto', () => {
  it('parseDate rejects malformed and impossible days', () => {
    expect(parseDate('2026-10-26', 'date')).toBe('2026-10-26');
    for (const bad of [
      '2026-02-30',
      '26-10-2026',
      '2026-10-26T00:00',
      20261026,
      undefined,
    ]) {
      expect(() => parseDate(bad, 'date')).toThrow(BadRequestException);
    }
  });

  describe('parseSavePatternInput', () => {
    it('accepts slots and an empty list (turns the plan off)', () => {
      expect(
        parseSavePatternInput({
          slots: [
            { weekday: 1, area: 'GYM', templateId: 't1' },
            { weekday: 1, area: 'RUN' },
          ],
        }),
      ).toEqual({
        slots: [
          { weekday: 1, area: 'GYM', templateId: 't1' },
          { weekday: 1, area: 'RUN', templateId: null },
        ],
      });
      expect(parseSavePatternInput({ slots: [] })).toEqual({ slots: [] });
    });

    it.each([
      ['a missing list', {}],
      ['weekday 0', { slots: [{ weekday: 0, area: 'RUN' }] }],
      ['weekday 8', { slots: [{ weekday: 8, area: 'RUN' }] }],
      ['a fractional weekday', { slots: [{ weekday: 1.5, area: 'RUN' }] }],
      ['DIET', { slots: [{ weekday: 1, area: 'DIET' }] }],
      [
        'a routine on a run',
        { slots: [{ weekday: 1, area: 'RUN', templateId: 't' }] },
      ],
      [
        'the same area twice on a day',
        {
          slots: [
            { weekday: 2, area: 'GYM' },
            { weekday: 2, area: 'GYM', templateId: 't' },
          ],
        },
      ],
    ])('rejects %s', (_, body) => {
      expect(() => parseSavePatternInput(body)).toThrow(BadRequestException);
    });
  });

  it('parseDaysQuery caps the range at 62 days and keeps from ≤ to', () => {
    expect(parseDaysQuery('2026-10-01', '2026-12-01')).toEqual({
      from: '2026-10-01',
      to: '2026-12-01',
    });
    expect(() => parseDaysQuery('2026-10-01', '2026-12-02')).toThrow(
      BadRequestException,
    );
    expect(() => parseDaysQuery('2026-10-02', '2026-10-01')).toThrow(
      BadRequestException,
    );
  });

  describe('parseDayChangeInput', () => {
    it('keeps absent keys absent and null as undo', () => {
      expect(parseDayChangeInput({ entries: { GYM: null } })).toEqual({
        GYM: null,
      });
      expect(
        parseDayChangeInput({
          entries: {
            RUN: { state: 'SKIPPED' },
            GYM: { state: 'PLANNED', templateId: 't' },
          },
        }),
      ).toEqual({
        RUN: { state: 'SKIPPED', templateId: null },
        GYM: { state: 'PLANNED', templateId: 't' },
      });
    });

    it.each([
      ['no entries', { entries: {} }],
      ['DIET', { entries: { DIET: { state: 'SKIPPED' } } }],
      ['an unknown state', { entries: { RUN: { state: 'DONE' } } }],
      [
        'a routine on a Folga',
        { entries: { GYM: { state: 'SKIPPED', templateId: 't' } } },
      ],
    ])('rejects %s', (_, body) => {
      expect(() => parseDayChangeInput(body)).toThrow(BadRequestException);
    });
  });

  it('parseMoveInput needs an area and two dates', () => {
    expect(
      parseMoveInput({ area: 'RUN', from: '2026-10-28', to: '2026-10-29' }),
    ).toEqual({
      area: 'RUN',
      from: '2026-10-28',
      to: '2026-10-29',
    });
    expect(() => parseMoveInput({ area: 'RUN', from: '2026-10-28' })).toThrow(
      BadRequestException,
    );
  });
});

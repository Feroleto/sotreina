import { describe, it, expect } from 'vitest';
import { isoWeekday, planWindow, daysInRange } from 'src/plans/plan-dates';
import {
  resolveDays,
  patternEntry,
  type VersionInput,
  type AdjustmentInput,
} from 'src/plans/plan-resolver';

// 2026-10-26 is a Monday
const MON = '2026-10-26';

function version(
  effectiveFrom: string,
  slots: VersionInput['slots'],
): VersionInput {
  return { effectiveFrom, slots };
}

function adjustment(
  partial: Partial<AdjustmentInput> &
    Pick<AdjustmentInput, 'date' | 'area' | 'state'>,
): AdjustmentInput {
  return {
    templateId: null,
    templateName: null,
    movedFromDate: null,
    movedToDate: null,
    ...partial,
  };
}

describe('plan dates', () => {
  it('isoWeekday is 1 on Monday and 7 on Sunday', () => {
    expect(isoWeekday(MON)).toBe(1);
    expect(isoWeekday('2026-11-01')).toBe(7);
  });

  it('planWindow runs from this Monday to next Sunday, whatever the day', () => {
    expect(planWindow(MON)).toEqual({ from: MON, to: '2026-11-08' });
    expect(planWindow('2026-11-01')).toEqual({ from: MON, to: '2026-11-08' });
    expect(planWindow('2026-10-29')).toEqual({ from: MON, to: '2026-11-08' });
  });

  it('daysInRange is inclusive on both ends and crosses a DST change', () => {
    // US DST ends on 2026-11-01; dates are calendar days, so nothing shifts
    expect(daysInRange('2026-10-31', '2026-11-02')).toEqual([
      '2026-10-31',
      '2026-11-01',
      '2026-11-02',
    ]);
  });
});

describe('resolveDays', () => {
  const gymMonWedFri = version('2026-10-01', [
    { weekday: 1, area: 'GYM', templateId: 't-chest', templateName: 'Peito' },
    { weekday: 3, area: 'GYM', templateId: null, templateName: null },
    { weekday: 2, area: 'RUN', templateId: null, templateName: null },
  ]);

  it('fills every day of the range and follows the pattern', () => {
    const days = resolveDays({
      versions: [gymMonWedFri],
      adjustments: [],
      from: MON,
      to: '2026-10-28',
    });

    expect(days.map((d) => d.date)).toEqual([MON, '2026-10-27', '2026-10-28']);
    expect(days[0]).toEqual({
      date: MON,
      active: true,
      entries: [
        {
          area: 'GYM',
          state: 'PLANNED',
          source: 'PATTERN',
          templateId: 't-chest',
          templateName: 'Peito',
          movedFrom: null,
          movedTo: null,
        },
      ],
    });
    expect(days[1].entries.map((e) => e.area)).toEqual(['RUN']);
    expect(days[2].entries[0]).toMatchObject({ area: 'GYM', templateId: null });
  });

  it('lists RUN before GYM on a day with both', () => {
    const v = version('2026-10-01', [
      { weekday: 1, area: 'GYM', templateId: null, templateName: null },
      { weekday: 1, area: 'RUN', templateId: null, templateName: null },
    ]);
    const [day] = resolveDays({
      versions: [v],
      adjustments: [],
      from: MON,
      to: MON,
    });
    expect(day.entries.map((e) => e.area)).toEqual(['RUN', 'GYM']);
  });

  it('judges each day by the version in force on it (the past stays frozen)', () => {
    // pattern changed on Wednesday: Mon/Tue keep the old one
    const newer = version('2026-10-28', [
      { weekday: 2, area: 'GYM', templateId: null, templateName: null },
    ]);
    const days = resolveDays({
      versions: [gymMonWedFri, newer],
      adjustments: [],
      from: MON,
      to: '2026-11-03',
    });
    const byDate = Object.fromEntries(
      days.map((d) => [d.date, d.entries.map((e) => e.area)]),
    );

    expect(byDate[MON]).toEqual(['GYM']);
    expect(byDate['2026-10-27']).toEqual(['RUN']);
    expect(byDate['2026-10-28']).toEqual([]);
    expect(byDate['2026-11-03']).toEqual(['GYM']);
  });

  it('is inactive before the first version and after an empty one', () => {
    const empty = version('2026-10-28', []);
    const days = resolveDays({
      versions: [
        version('2026-10-27', [
          { weekday: 2, area: 'RUN', templateId: null, templateName: null },
        ]),
        empty,
      ],
      adjustments: [],
      from: MON,
      to: '2026-10-28',
    });
    expect(days.map((d) => d.active)).toEqual([false, true, false]);
  });

  it('an adjustment beats the pattern, including a newer pattern', () => {
    const newer = version('2026-10-28', [
      { weekday: 5, area: 'GYM', templateId: 't-legs', templateName: 'Pernas' },
    ]);
    const [fri] = resolveDays({
      versions: [gymMonWedFri, newer],
      adjustments: [
        adjustment({ date: '2026-10-30', area: 'GYM', state: 'SKIPPED' }),
      ],
      from: '2026-10-30',
      to: '2026-10-30',
    });
    expect(fri.entries).toEqual([
      expect.objectContaining({
        area: 'GYM',
        state: 'SKIPPED',
        source: 'ADJUSTMENT',
      }),
    ]);
  });

  it('a planned adjustment carries its own routine', () => {
    const [mon] = resolveDays({
      versions: [gymMonWedFri],
      adjustments: [
        adjustment({
          date: MON,
          area: 'GYM',
          state: 'PLANNED',
          templateId: 't-back',
          templateName: 'Costas',
        }),
      ],
      from: MON,
      to: MON,
    });
    expect(mon.entries[0]).toMatchObject({
      state: 'PLANNED',
      source: 'ADJUSTMENT',
      templateName: 'Costas',
    });
  });

  it('both halves of a move point at each other, across a Sunday', () => {
    const days = resolveDays({
      versions: [gymMonWedFri],
      adjustments: [
        adjustment({
          date: '2026-10-28',
          area: 'GYM',
          state: 'SKIPPED',
          movedToDate: '2026-11-02',
        }),
        adjustment({
          date: '2026-11-02',
          area: 'GYM',
          state: 'PLANNED',
          movedFromDate: '2026-10-28',
        }),
      ],
      from: '2026-10-28',
      to: '2026-11-02',
    });
    const wed = days.find((d) => d.date === '2026-10-28')!;
    const nextMon = days.find((d) => d.date === '2026-11-02')!;

    expect(wed.entries[0]).toMatchObject({
      state: 'SKIPPED',
      movedTo: '2026-11-02',
      movedFrom: null,
    });
    expect(nextMon.entries[0]).toMatchObject({
      state: 'PLANNED',
      movedFrom: '2026-10-28',
    });
  });

  it('drops a Folga the current pattern no longer plans (nothing left to skip)', () => {
    const newer = version('2026-10-28', [
      { weekday: 1, area: 'GYM', templateId: null, templateName: null },
    ]);
    const [fri] = resolveDays({
      versions: [gymMonWedFri, newer],
      adjustments: [
        adjustment({ date: '2026-10-28', area: 'GYM', state: 'SKIPPED' }),
      ],
      from: '2026-10-28',
      to: '2026-10-28',
    });
    expect(fri.entries).toEqual([]);
  });

  it('ignores adjustments on a day with no active plan', () => {
    const [day] = resolveDays({
      versions: [],
      adjustments: [adjustment({ date: MON, area: 'RUN', state: 'PLANNED' })],
      from: MON,
      to: MON,
    });
    expect(day).toEqual({ date: MON, active: false, entries: [] });
  });
});

describe('patternEntry', () => {
  it('returns what the pattern alone says, ignoring adjustments', () => {
    const v = version('2026-10-01', [
      { weekday: 1, area: 'GYM', templateId: 't', templateName: 'Peito' },
    ]);
    expect(patternEntry([v], MON, 'GYM')).toEqual({
      templateId: 't',
      templateName: 'Peito',
    });
    expect(patternEntry([v], MON, 'RUN')).toBeNull();
    expect(patternEntry([v], '2026-09-28', 'GYM')).toBeNull();
  });
});

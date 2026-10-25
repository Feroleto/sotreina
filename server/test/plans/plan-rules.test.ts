import { describe, it, expect } from 'vitest';
import { BadRequestException } from '@nestjs/common';
import {
  planDayChange,
  planMove,
  type AreaContext,
} from 'src/plans/plan-rules';

// Wednesday of the week 2026-10-26 … 2026-11-01; the window ends 2026-11-08
const TODAY = '2026-10-28';
const WINDOW = { from: '2026-10-26', to: '2026-11-08' };

function ctx(
  partial: Partial<AreaContext> & Pick<AreaContext, 'date'>,
): AreaContext {
  return {
    today: TODAY,
    window: WINDOW,
    active: true,
    pattern: null,
    adjustment: null,
    ...partial,
  };
}

const PLANNED_BY_PATTERN = {
  pattern: { templateId: 't-chest', templateName: 'Peito' },
};

describe('planDayChange', () => {
  it('rejects a date outside the window or without an active plan', () => {
    expect(() =>
      planDayChange(ctx({ date: '2026-11-09', ...PLANNED_BY_PATTERN }), 'GYM', {
        state: 'SKIPPED',
        templateId: null,
      }),
    ).toThrow(BadRequestException);
    expect(() =>
      planDayChange(ctx({ date: '2026-10-25', ...PLANNED_BY_PATTERN }), 'GYM', {
        state: 'SKIPPED',
        templateId: null,
      }),
    ).toThrow(BadRequestException);
    expect(() =>
      planDayChange(ctx({ date: TODAY, active: false }), 'RUN', {
        state: 'PLANNED',
        templateId: null,
      }),
    ).toThrow(BadRequestException);
  });

  describe('Folga', () => {
    it('on a day the pattern plans, stores a SKIPPED adjustment', () => {
      expect(
        planDayChange(ctx({ date: TODAY, ...PLANNED_BY_PATTERN }), 'GYM', {
          state: 'SKIPPED',
          templateId: null,
        }),
      ).toEqual({
        kind: 'upsert',
        state: 'SKIPPED',
        templateId: null,
      });
    });

    it('on an added area just removes the addition', () => {
      const added = {
        date: TODAY,
        area: 'RUN' as const,
        state: 'PLANNED' as const,
        templateId: null,
        templateName: null,
        movedFromDate: null,
        movedToDate: null,
      };
      expect(
        planDayChange(ctx({ date: TODAY, adjustment: added }), 'RUN', {
          state: 'SKIPPED',
          templateId: null,
        }),
      ).toEqual({
        kind: 'delete',
      });
    });

    it('on a day with nothing planned is a 400', () => {
      expect(() =>
        planDayChange(ctx({ date: TODAY }), 'RUN', {
          state: 'SKIPPED',
          templateId: null,
        }),
      ).toThrow(BadRequestException);
    });

    it('is allowed on a past day of this week (sick yesterday)', () => {
      expect(
        planDayChange(
          ctx({ date: '2026-10-26', ...PLANNED_BY_PATTERN }),
          'GYM',
          { state: 'SKIPPED', templateId: null },
        ),
      ).toEqual({ kind: 'upsert', state: 'SKIPPED', templateId: null });
    });

    it('repeating it is a no-op', () => {
      const skipped = {
        date: TODAY,
        area: 'GYM' as const,
        state: 'SKIPPED' as const,
        templateId: null,
        templateName: null,
        movedFromDate: null,
        movedToDate: null,
      };
      expect(
        planDayChange(
          ctx({ date: TODAY, ...PLANNED_BY_PATTERN, adjustment: skipped }),
          'GYM',
          { state: 'SKIPPED', templateId: null },
        ),
      ).toEqual({ kind: 'none' });
    });
  });

  describe('PLANNED (add or change routine)', () => {
    it('adds an area the pattern leaves free', () => {
      expect(
        planDayChange(ctx({ date: TODAY }), 'RUN', {
          state: 'PLANNED',
          templateId: null,
        }),
      ).toEqual({
        kind: 'upsert',
        state: 'PLANNED',
        templateId: null,
      });
    });

    it('changes the routine of a planned Treino', () => {
      expect(
        planDayChange(
          ctx({ date: '2026-11-02', ...PLANNED_BY_PATTERN }),
          'GYM',
          { state: 'PLANNED', templateId: 't-back' },
        ),
      ).toEqual({ kind: 'upsert', state: 'PLANNED', templateId: 't-back' });
    });

    it('matching the pattern exactly drops the adjustment instead of storing a redundant one', () => {
      const changed = {
        date: TODAY,
        area: 'GYM' as const,
        state: 'PLANNED' as const,
        templateId: 't-back',
        templateName: 'Costas',
        movedFromDate: null,
        movedToDate: null,
      };
      expect(
        planDayChange(
          ctx({ date: TODAY, ...PLANNED_BY_PATTERN, adjustment: changed }),
          'GYM',
          { state: 'PLANNED', templateId: 't-chest' },
        ),
      ).toEqual({ kind: 'delete' });
      expect(
        planDayChange(ctx({ date: TODAY, ...PLANNED_BY_PATTERN }), 'GYM', {
          state: 'PLANNED',
          templateId: 't-chest',
        }),
      ).toEqual({ kind: 'none' });
    });

    it('is a 400 on a past day', () => {
      expect(() =>
        planDayChange(ctx({ date: '2026-10-27' }), 'RUN', {
          state: 'PLANNED',
          templateId: null,
        }),
      ).toThrow(BadRequestException);
    });

    it('a routine on a Corrida is a 400', () => {
      expect(() =>
        planDayChange(ctx({ date: TODAY }), 'RUN', {
          state: 'PLANNED',
          templateId: 't',
        }),
      ).toThrow(BadRequestException);
    });
  });

  describe('undo (null)', () => {
    it('deletes a plain adjustment, or is a no-op without one', () => {
      const skipped = {
        date: TODAY,
        area: 'GYM' as const,
        state: 'SKIPPED' as const,
        templateId: null,
        templateName: null,
        movedFromDate: null,
        movedToDate: null,
      };
      expect(
        planDayChange(
          ctx({ date: TODAY, ...PLANNED_BY_PATTERN, adjustment: skipped }),
          'GYM',
          null,
        ),
      ).toEqual({
        kind: 'delete',
      });
      expect(planDayChange(ctx({ date: TODAY }), 'GYM', null)).toEqual({
        kind: 'none',
      });
    });

    it('undoes a past Folga, but not a past addition', () => {
      const skipped = {
        date: '2026-10-26',
        area: 'GYM' as const,
        state: 'SKIPPED' as const,
        templateId: null,
        templateName: null,
        movedFromDate: null,
        movedToDate: null,
      };
      expect(
        planDayChange(
          ctx({
            date: '2026-10-26',
            ...PLANNED_BY_PATTERN,
            adjustment: skipped,
          }),
          'GYM',
          null,
        ),
      ).toEqual({
        kind: 'delete',
      });
      const added = { ...skipped, state: 'PLANNED' as const };
      expect(() =>
        planDayChange(
          ctx({ date: '2026-10-26', adjustment: added }),
          'GYM',
          null,
        ),
      ).toThrow(BadRequestException);
    });

    it('on either half of a move deletes both', () => {
      const source = {
        date: TODAY,
        area: 'GYM' as const,
        state: 'SKIPPED' as const,
        templateId: null,
        templateName: null,
        movedFromDate: null,
        movedToDate: '2026-10-30',
      };
      expect(
        planDayChange(
          ctx({ date: TODAY, ...PLANNED_BY_PATTERN, adjustment: source }),
          'GYM',
          null,
        ),
      ).toEqual({
        kind: 'deletePair',
        otherDate: '2026-10-30',
      });
    });

    it('refuses to undo a move once either half is in the past', () => {
      const target = {
        date: '2026-10-29',
        area: 'GYM' as const,
        state: 'PLANNED' as const,
        templateId: null,
        templateName: null,
        movedFromDate: '2026-10-27',
        movedToDate: null,
      };
      expect(() =>
        planDayChange(
          ctx({ date: '2026-10-29', adjustment: target }),
          'GYM',
          null,
        ),
      ).toThrow(BadRequestException);
    });
  });

  it('any other change to a half of a move is a 400 (undo the move first)', () => {
    const target = {
      date: '2026-10-30',
      area: 'GYM' as const,
      state: 'PLANNED' as const,
      templateId: null,
      templateName: null,
      movedFromDate: TODAY,
      movedToDate: null,
    };
    expect(() =>
      planDayChange(ctx({ date: '2026-10-30', adjustment: target }), 'GYM', {
        state: 'SKIPPED',
        templateId: null,
      }),
    ).toThrow(BadRequestException);
    expect(() =>
      planDayChange(ctx({ date: '2026-10-30', adjustment: target }), 'GYM', {
        state: 'PLANNED',
        templateId: 't-back',
      }),
    ).toThrow(BadRequestException);
  });
});

describe('planMove', () => {
  const from = ctx({ date: TODAY, ...PLANNED_BY_PATTERN });

  it('skips the source and plans the target with the same routine, across a Sunday', () => {
    expect(planMove('GYM', from, ctx({ date: '2026-11-02' }))).toEqual({
      from: {
        state: 'SKIPPED',
        templateId: null,
        movedToDate: '2026-11-02',
        movedFromDate: null,
      },
      to: {
        state: 'PLANNED',
        templateId: 't-chest',
        movedFromDate: TODAY,
        movedToDate: null,
      },
    });
  });

  it('carries the routine of an adjustment that changed it', () => {
    const changed = {
      date: TODAY,
      area: 'GYM' as const,
      state: 'PLANNED' as const,
      templateId: 't-back',
      templateName: 'Costas',
      movedFromDate: null,
      movedToDate: null,
    };
    const move = planMove(
      'GYM',
      ctx({ date: TODAY, ...PLANNED_BY_PATTERN, adjustment: changed }),
      ctx({ date: '2026-10-29' }),
    );
    expect(move.to.templateId).toBe('t-back');
  });

  it('may land on a Folga of the same area (it replaces it)', () => {
    const skipped = {
      date: '2026-10-30',
      area: 'GYM' as const,
      state: 'SKIPPED' as const,
      templateId: null,
      templateName: null,
      movedFromDate: null,
      movedToDate: null,
    };
    expect(() =>
      planMove(
        'GYM',
        from,
        ctx({ date: '2026-10-30', ...PLANNED_BY_PATTERN, adjustment: skipped }),
      ),
    ).not.toThrow();
  });

  it.each([
    [
      'the source is in the past',
      ctx({ date: '2026-10-27', ...PLANNED_BY_PATTERN }),
      ctx({ date: '2026-10-29' }),
    ],
    ['the target is in the past', from, ctx({ date: '2026-10-27' })],
    ['the target is outside the window', from, ctx({ date: '2026-11-09' })],
    ['source and target are the same day', from, ctx({ date: TODAY })],
    [
      'nothing is planned at the source',
      ctx({ date: TODAY }),
      ctx({ date: '2026-10-29' }),
    ],
    [
      'the target already has the area planned',
      from,
      ctx({ date: '2026-10-30', ...PLANNED_BY_PATTERN }),
    ],
    [
      'the target has no active plan',
      from,
      ctx({ date: '2026-10-29', active: false }),
    ],
    [
      'the source is already half of a move',
      ctx({
        date: TODAY,
        adjustment: {
          date: TODAY,
          area: 'GYM',
          state: 'PLANNED',
          templateId: null,
          templateName: null,
          movedFromDate: '2026-10-27',
          movedToDate: null,
        },
      }),
      ctx({ date: '2026-10-29' }),
    ],
    [
      'the target is the emptied half of another move',
      from,
      ctx({
        date: '2026-10-30',
        ...PLANNED_BY_PATTERN,
        adjustment: {
          date: '2026-10-30',
          area: 'GYM',
          state: 'SKIPPED',
          templateId: null,
          templateName: null,
          movedFromDate: null,
          movedToDate: '2026-10-31',
        },
      }),
    ],
  ])('is a 400 when %s', (_, source, target) => {
    expect(() => planMove('GYM', source, target)).toThrow(BadRequestException);
  });
});

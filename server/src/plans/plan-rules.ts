import { BadRequestException } from '@nestjs/common';
import type {
  AdjustmentInput,
  PlanArea,
  PlanEntryState,
} from './plan-resolver';

// Which Ajuste a request turns into, or why it's refused (spec §5.3). Pure:
// the service loads the context, these decide, the service writes. Past days
// of the current week only accept a Folga (and undoing one); everything else
// is from today on, inside this week + next

export interface AreaContext {
  date: string;
  today: string;
  window: { from: string; to: string };
  active: boolean;
  /** what the Padrão alone plans for this area on this date */
  pattern: { templateId: string | null; templateName?: string | null } | null;
  /** the Ajuste already stored for this area on this date */
  adjustment: AdjustmentInput | null;
}

export type DayChange = {
  state: PlanEntryState;
  templateId: string | null;
} | null;

export type DayOp =
  | { kind: 'none' }
  | { kind: 'upsert'; state: PlanEntryState; templateId: string | null }
  | { kind: 'delete' }
  /** undo a move: delete this half and the one on `otherDate` */
  | { kind: 'deletePair'; otherDate: string };

export interface MoveHalf {
  state: PlanEntryState;
  templateId: string | null;
  movedFromDate: string | null;
  movedToDate: string | null;
}

// deliberately not a type guard: its false branch would narrow `a` to null
function isMoveHalf(a: AdjustmentInput | null): boolean {
  return !!a && (a.movedFromDate !== null || a.movedToDate !== null);
}

function assertEditable(ctx: AreaContext): void {
  if (ctx.date < ctx.window.from || ctx.date > ctx.window.to) {
    throw new BadRequestException('date must be within this week or the next');
  }
  if (!ctx.active) {
    throw new BadRequestException('there is no active plan on this date');
  }
}

/** the routine of whatever is planned right now (Ajuste over Padrão), or undefined if nothing */
function currentPlanned(
  ctx: AreaContext,
): { templateId: string | null } | undefined {
  if (ctx.adjustment) {
    return ctx.adjustment.state === 'PLANNED'
      ? { templateId: ctx.adjustment.templateId }
      : undefined;
  }
  return ctx.pattern ? { templateId: ctx.pattern.templateId } : undefined;
}

export function planDayChange(
  ctx: AreaContext,
  area: PlanArea,
  change: DayChange,
): DayOp {
  assertEditable(ctx);
  const past = ctx.date < ctx.today;
  const adj = ctx.adjustment;

  if (change === null) {
    if (!adj) return { kind: 'none' };
    if (isMoveHalf(adj)) {
      const otherDate = (adj.movedToDate ?? adj.movedFromDate) as string;
      if (past || otherDate < ctx.today) {
        throw new BadRequestException(
          'a move with a day in the past can no longer be undone',
        );
      }
      return { kind: 'deletePair', otherDate };
    }
    if (past && adj.state !== 'SKIPPED') {
      throw new BadRequestException('past days only accept a Folga');
    }
    return { kind: 'delete' };
  }

  if (isMoveHalf(adj)) {
    throw new BadRequestException(
      'this day is part of a move; undo the move first',
    );
  }

  if (change.state === 'SKIPPED') {
    if (adj?.state === 'SKIPPED') return { kind: 'none' };
    if (!currentPlanned(ctx)) {
      throw new BadRequestException(
        `nothing is planned for ${area} on this date`,
      );
    }
    if (past && !ctx.pattern) {
      throw new BadRequestException(
        'past days only accept a Folga of what the pattern planned',
      );
    }
    // skipping an area that only an Ajuste added just takes the addition back
    if (!ctx.pattern) return { kind: 'delete' };
    return { kind: 'upsert', state: 'SKIPPED', templateId: null };
  }

  // PLANNED: add an area, or change the routine of a planned Treino
  if (past) throw new BadRequestException('past days only accept a Folga');
  if (area === 'RUN' && change.templateId !== null) {
    throw new BadRequestException('templateId is only valid for GYM');
  }
  if (ctx.pattern && ctx.pattern.templateId === change.templateId) {
    // back to exactly what the Padrão says: no Ajuste needed
    return adj ? { kind: 'delete' } : { kind: 'none' };
  }
  if (adj?.state === 'PLANNED' && adj.templateId === change.templateId)
    return { kind: 'none' };
  return { kind: 'upsert', state: 'PLANNED', templateId: change.templateId };
}

export function planMove(
  area: PlanArea,
  from: AreaContext,
  to: AreaContext,
): { from: MoveHalf; to: MoveHalf } {
  assertEditable(from);
  assertEditable(to);
  if (from.date < from.today || to.date < to.today) {
    throw new BadRequestException('a move only goes from today on');
  }
  if (from.date === to.date)
    throw new BadRequestException('from and to must differ');
  if (isMoveHalf(from.adjustment) || isMoveHalf(to.adjustment)) {
    throw new BadRequestException(
      'this day is part of a move; undo the move first',
    );
  }
  const source = currentPlanned(from);
  if (!source)
    throw new BadRequestException(
      `nothing is planned for ${area} on ${from.date}`,
    );
  if (currentPlanned(to))
    throw new BadRequestException(`${area} is already planned on ${to.date}`);

  return {
    from: {
      state: 'SKIPPED',
      templateId: null,
      movedFromDate: null,
      movedToDate: to.date,
    },
    to: {
      state: 'PLANNED',
      templateId: source.templateId,
      movedFromDate: from.date,
      movedToDate: null,
    },
  };
}

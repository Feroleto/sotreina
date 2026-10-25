import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { localDateString } from '../common/timezone';
import { WorkoutTemplatesService } from '../workout-templates/workout-templates.service';
import { fromDbDate, planWindow, toDbDate } from './plan-dates';
import {
  patternEntry,
  isActiveOn,
  resolveDays,
  versionOn,
  PLAN_AREAS,
  type AdjustmentInput,
  type PlanArea,
  type PlanDay,
  type VersionInput,
} from './plan-resolver';
import {
  planDayChange,
  planMove,
  type AreaContext,
  type DayOp,
  type MoveHalf,
} from './plan-rules';
import type { DayChangeInput, MoveInput, SavePatternInput } from './dto';

export interface PatternResponse {
  /** first day the Padrão in force today applies to; null = never had a plan */
  effectiveFrom: string | null;
  slots: {
    weekday: number;
    area: PlanArea;
    templateId: string | null;
    templateName: string | null;
  }[];
}

const TEMPLATE_NAME = { select: { name: true } } as const;

function slotSignature(
  slots: { weekday: number; area: string; templateId: string | null }[],
): string {
  return slots
    .map((s) => `${s.weekday}|${s.area}|${s.templateId ?? ''}`)
    .sort()
    .join(',');
}

// Plano da semana (spec .plans/plano-semanal-spec.md §5). Reads resolve the
// Padrão version in force on each day plus that day's Ajustes
// (plan-resolver.ts); writes go through plan-rules.ts, which decides what a
// request becomes or why it's refused. "Today" is always the caller's local
// day (X-Time-Zone). Every day-level mutation returns the editable window
// (this week + next) resolved, so the client replaces its state without a refetch
@Injectable()
export class PlansService {
  private readonly prisma: PrismaClient;

  constructor(
    private readonly config: ConfigService,
    private readonly templates: WorkoutTemplatesService,
  ) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  private today(timeZone: string): string {
    return localDateString(new Date(), timeZone);
  }

  // every version up to `upTo`, not just those inside a range: the one in
  // force on the first day of a range usually started before it
  private async loadVersions(
    userId: string,
    upTo: string,
  ): Promise<VersionInput[]> {
    const rows = await this.prisma.weekPlanVersion.findMany({
      where: { userId, effectiveFrom: { lte: toDbDate(upTo) } },
      orderBy: { effectiveFrom: 'asc' },
      select: {
        effectiveFrom: true,
        slots: {
          select: {
            weekday: true,
            area: true,
            templateId: true,
            template: TEMPLATE_NAME,
          },
          orderBy: [{ weekday: 'asc' }, { area: 'asc' }],
        },
      },
    });
    return rows.map((v) => ({
      effectiveFrom: fromDbDate(v.effectiveFrom),
      slots: v.slots.map((s) => ({
        weekday: s.weekday,
        area: s.area as PlanArea,
        templateId: s.templateId,
        templateName: s.template?.name ?? null,
      })),
    }));
  }

  private async loadAdjustments(
    userId: string,
    dates: { from: string; to: string },
  ): Promise<AdjustmentInput[]> {
    const rows = await this.prisma.planAdjustment.findMany({
      where: {
        userId,
        date: { gte: toDbDate(dates.from), lte: toDbDate(dates.to) },
      },
      select: {
        date: true,
        area: true,
        state: true,
        templateId: true,
        template: TEMPLATE_NAME,
        movedFromDate: true,
        movedToDate: true,
      },
    });
    return rows.map((a) => ({
      date: fromDbDate(a.date),
      area: a.area as PlanArea,
      state: a.state,
      templateId: a.templateId,
      templateName: a.template?.name ?? null,
      movedFromDate: a.movedFromDate ? fromDbDate(a.movedFromDate) : null,
      movedToDate: a.movedToDate ? fromDbDate(a.movedToDate) : null,
    }));
  }

  async getPattern(userId: string, timeZone: string): Promise<PatternResponse> {
    const today = this.today(timeZone);
    const version = versionOn(await this.loadVersions(userId, today), today);
    return {
      effectiveFrom: version?.effectiveFrom ?? null,
      slots: version?.slots ?? [],
    };
  }

  // Saves the Padrão as the version starting today, so every past day keeps
  // being judged by the one in force back then. Ajustes are left alone: they
  // were explicit decisions for their dates and beat any Padrão
  async savePattern(
    userId: string,
    input: SavePatternInput,
    timeZone: string,
  ): Promise<PatternResponse> {
    const templateIds = new Set(
      input.slots
        .map((s) => s.templateId)
        .filter((id): id is string => id !== null),
    );
    for (const id of templateIds)
      await this.templates.assertOwnedTemplate(userId, id);

    const current = await this.getPattern(userId, timeZone);
    if (
      current.effectiveFrom !== null &&
      slotSignature(current.slots) === slotSignature(input.slots)
    ) {
      return current;
    }
    // nothing to turn off for someone who never had a plan
    if (current.effectiveFrom === null && input.slots.length === 0)
      return current;

    const effectiveFrom = toDbDate(this.today(timeZone));
    const gymDays = input.slots.filter((s) => s.area === 'GYM').length;
    await this.prisma.$transaction(async (tx) => {
      const version = await tx.weekPlanVersion.upsert({
        where: { userId_effectiveFrom: { userId, effectiveFrom } },
        create: { userId, effectiveFrom },
        update: {},
        select: { id: true },
      });
      await tx.weekPlanSlot.deleteMany({ where: { versionId: version.id } });
      if (input.slots.length > 0) {
        await tx.weekPlanSlot.createMany({
          data: input.slots.map((s) => ({ versionId: version.id, ...s })),
        });
      }
      // keeps the Meta semanal of Treinos coherent for clients that don't
      // read the plan (the web, for now); an emptied plan keeps the last value
      if (gymDays > 0) {
        await tx.user.update({
          where: { id: userId },
          data: { weeklyWorkoutsGoal: gymDays },
        });
      }
    });
    return this.getPattern(userId, timeZone);
  }

  async getDays(
    userId: string,
    range: { from: string; to: string },
  ): Promise<PlanDay[]> {
    const [versions, adjustments] = await Promise.all([
      this.loadVersions(userId, range.to),
      this.loadAdjustments(userId, range),
    ]);
    return resolveDays({ versions, adjustments, ...range });
  }

  async getWindow(userId: string, timeZone: string): Promise<PlanDay[]> {
    return this.getDays(userId, planWindow(this.today(timeZone)));
  }

  private async contexts(userId: string, dates: string[], timeZone: string) {
    const today = this.today(timeZone);
    const window = planWindow(today);
    const sorted = [...dates].sort();
    const [versions, adjustments] = await Promise.all([
      this.loadVersions(userId, window.to),
      this.loadAdjustments(userId, {
        from: sorted[0],
        to: sorted[sorted.length - 1],
      }),
    ]);
    return (date: string, area: PlanArea): AreaContext => ({
      date,
      today,
      window,
      active: isActiveOn(versions, date),
      pattern: patternEntry(versions, date, area),
      adjustment:
        adjustments.find((a) => a.date === date && a.area === area) ?? null,
    });
  }

  async updateDay(
    userId: string,
    date: string,
    input: DayChangeInput,
    timeZone: string,
  ): Promise<PlanDay[]> {
    for (const change of Object.values(input)) {
      if (change?.templateId)
        await this.templates.assertOwnedTemplate(userId, change.templateId);
    }
    const contextFor = await this.contexts(userId, [date], timeZone);
    // decide every area before writing any, so a refused one leaves the day untouched
    const ops: [PlanArea, DayOp][] = PLAN_AREAS.filter(
      (area) => area in input,
    ).map((area) => [
      area,
      planDayChange(contextFor(date, area), area, input[area]!),
    ]);

    const writes: Prisma.PrismaPromise<unknown>[] = [];
    for (const [area, op] of ops) {
      const day = toDbDate(date);
      if (op.kind === 'upsert') {
        const half = {
          state: op.state,
          templateId: op.templateId,
          movedFromDate: null,
          movedToDate: null,
        };
        writes.push(this.upsertAdjustment(userId, area, date, half));
      } else if (op.kind === 'delete') {
        writes.push(
          this.prisma.planAdjustment.deleteMany({
            where: { userId, area, date: day },
          }),
        );
      } else if (op.kind === 'deletePair') {
        writes.push(
          this.prisma.planAdjustment.deleteMany({
            where: {
              userId,
              area,
              date: { in: [day, toDbDate(op.otherDate)] },
            },
          }),
        );
      }
    }
    if (writes.length > 0) await this.prisma.$transaction(writes);
    return this.getWindow(userId, timeZone);
  }

  private upsertAdjustment(
    userId: string,
    area: PlanArea,
    date: string,
    half: MoveHalf,
  ) {
    const day = toDbDate(date);
    const data = {
      state: half.state,
      templateId: half.templateId,
      movedFromDate: half.movedFromDate ? toDbDate(half.movedFromDate) : null,
      movedToDate: half.movedToDate ? toDbDate(half.movedToDate) : null,
    };
    return this.prisma.planAdjustment.upsert({
      where: { userId_date_area: { userId, date: day, area } },
      create: { userId, date: day, area, ...data },
      update: data,
    });
  }

  async move(
    userId: string,
    input: MoveInput,
    timeZone: string,
  ): Promise<PlanDay[]> {
    const contextFor = await this.contexts(
      userId,
      [input.from, input.to],
      timeZone,
    );
    const halves = planMove(
      input.area,
      contextFor(input.from, input.area),
      contextFor(input.to, input.area),
    );

    await this.prisma.$transaction([
      this.upsertAdjustment(userId, input.area, input.from, halves.from),
      this.upsertAdjustment(userId, input.area, input.to, halves.to),
    ]);
    return this.getWindow(userId, timeZone);
  }
}

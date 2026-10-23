import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { MealsService } from '../meals/meals.service';
import type { CreateFoodLogInput, UpdateFoodLogInput } from './food-logs.dto';
import type { FoodListItem } from '../foods/foods.service';
import {
  addDays,
  DEFAULT_TIME_ZONE,
  localDateString,
  localDayBoundaries,
} from '../common/timezone';

export interface FoodLogItem {
  id: string;
  quantity: number;
  enteredAsServing: boolean;
  mealId: string;
  loggedAt: Date;
  food: FoodListItem;
}

export interface DailySummary {
  totalKcal: number;
  totalProtein: number;
  totalCarbs: number;
  totalFat: number;
}

export interface DailyHistoryPoint extends DailySummary {
  date: string;
}

const FOOD_LOG_SELECT = {
  id: true,
  quantity: true,
  enteredAsServing: true,
  mealId: true,
  loggedAt: true,
  food: {
    select: {
      id: true,
      name: true,
      brand: true,
      source: true,
      imageUrl: true,
      kcal: true,
      protein: true,
      carbs: true,
      fat: true,
      fiber: true,
      sodium: true,
      servingLabel: true,
      servingGrams: true,
    },
  },
} satisfies Prisma.FoodLogSelect;

@Injectable()
export class FoodLogsService {
  private readonly prisma: PrismaClient;

  constructor(
    private readonly config: ConfigService,
    private readonly mealsService: MealsService,
  ) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  async create(userId: string, input: CreateFoodLogInput): Promise<FoodLogItem> {
    // a mealId off the wire is a guessable string, unlike the closed enum it
    // replaced — without this, a log could be attached to another user's meal
    await this.mealsService.assertOwned(userId, input.mealId);

    // a resend of a log the server already has (response lost on the way
    // back) answers with the stored row instead of a duplicate — same
    // contract as WorkoutsService.addSet
    const { clientId } = input;
    if (clientId) {
      const existing = await this.prisma.foodLog.findFirst({
        where: { userId, clientId },
        select: FOOD_LOG_SELECT,
      });
      if (existing) return existing;
    }

    try {
      return await this.prisma.foodLog.create({
        data: {
          userId,
          foodId: input.foodId,
          quantity: input.quantity,
          enteredAsServing: input.enteredAsServing,
          mealId: input.mealId,
          loggedAt: input.loggedAt,
          clientId,
        },
        select: FOOD_LOG_SELECT,
      });
    } catch (e) {
      // two resends racing past the findFirst above: the unique
      // [userId, clientId] lets exactly one through. Duck-typed rather than
      // instanceof PrismaClientKnownRequestError — tests mock @prisma/client
      if (!(clientId && (e as { code?: unknown }).code === 'P2002')) throw e;
      const winner = await this.prisma.foodLog.findFirst({
        where: { userId, clientId },
        select: FOOD_LOG_SELECT,
      });
      if (!winner) throw e;
      return winner;
    }
  }

  // updateMany (not update) for the same reason as remove() below: ownership
  // lives in the where clause, so another user's log is a 404, never a 403
  async update(userId: string, id: string, input: UpdateFoodLogInput): Promise<FoodLogItem> {
    const result = await this.prisma.foodLog.updateMany({
      where: { id, userId },
      data: { quantity: input.quantity, enteredAsServing: input.enteredAsServing },
    });
    if (result.count === 0) {
      throw new NotFoundException(`Food log ${id} not found`);
    }
    // updateMany can't select, so read the row back in the shape callers expect
    const updated = await this.prisma.foodLog.findUniqueOrThrow({
      where: { id },
      select: FOOD_LOG_SELECT,
    });
    return updated;
  }

  // `date` is a calendar day in the caller's time zone (X-Time-Zone), so the
  // window is local midnight → next local midnight, not UTC
  async findByDate(
    userId: string,
    date: string,
    timeZone: string = DEFAULT_TIME_ZONE,
  ): Promise<FoodLogItem[]> {
    const { start, end } = localDayBoundaries(date, timeZone);
    return this.prisma.foodLog.findMany({
      where: { userId, loggedAt: { gte: start, lt: end } },
      orderBy: { loggedAt: 'asc' },
      select: FOOD_LOG_SELECT,
    });
  }

  // deleteMany (not delete) — folds ownership into the where clause itself,
  // same 404-not-403 convention as assertOwnedWorkout in workouts.service.ts
  async remove(userId: string, id: string): Promise<void> {
    const result = await this.prisma.foodLog.deleteMany({ where: { id, userId } });
    if (result.count === 0) {
      throw new NotFoundException(`Food log ${id} not found`);
    }
  }

  // mirror of PersonalBestsService.topRecords: tagged-template $queryRaw,
  // parameters interpolated (Prisma parameterizes these safely). No ::int
  // cast needed here (unlike ROW_NUMBER()/COUNT) — every summed column is
  // Postgres double precision, which Prisma already maps to a JS number.
  async getDailySummary(
    userId: string,
    date: string,
    timeZone: string = DEFAULT_TIME_ZONE,
  ): Promise<DailySummary> {
    const { start, end } = localDayBoundaries(date, timeZone);
    const rows = await this.prisma.$queryRaw<DailySummary[]>`
      SELECT
        COALESCE(SUM(f.kcal * fl.quantity / 100), 0) AS "totalKcal",
        COALESCE(SUM(f.protein * fl.quantity / 100), 0) AS "totalProtein",
        COALESCE(SUM(f.carbs * fl.quantity / 100), 0) AS "totalCarbs",
        COALESCE(SUM(f.fat * fl.quantity / 100), 0) AS "totalFat"
      FROM "food_logs" fl
      JOIN "foods" f ON f.id = fl."food_id"
      WHERE fl."user_id" = ${userId} AND fl."logged_at" >= ${start} AND fl."logged_at" < ${end}
    `;
    return rows[0] ?? { totalKcal: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0 };
  }

  // zero-fills days with no logs via generate_series, so callers never have
  // to reconcile a sparse result against the requested date range themselves.
  // Days are the caller's local days: "today" comes from their time zone, and
  // each day's window is converted to the naive-UTC timestamps logged_at holds
  // (`local AT TIME ZONE tz` → timestamptz, `AT TIME ZONE 'UTC'` → naive UTC),
  // which also stays right across a DST change
  async getHistory(
    userId: string,
    days: number,
    timeZone: string = DEFAULT_TIME_ZONE,
  ): Promise<DailyHistoryPoint[]> {
    const end = localDateString(new Date(), timeZone);
    const start = addDays(end, -(days - 1));

    const rows = await this.prisma.$queryRaw<
      { date: Date; totalKcal: number; totalProtein: number; totalCarbs: number; totalFat: number }[]
    >`
      SELECT
        d::date AS date,
        COALESCE(SUM(f.kcal * fl.quantity / 100), 0) AS "totalKcal",
        COALESCE(SUM(f.protein * fl.quantity / 100), 0) AS "totalProtein",
        COALESCE(SUM(f.carbs * fl.quantity / 100), 0) AS "totalCarbs",
        COALESCE(SUM(f.fat * fl.quantity / 100), 0) AS "totalFat"
      FROM generate_series(${start}::date::timestamp, ${end}::date::timestamp, '1 day') d
      LEFT JOIN "food_logs" fl
        ON fl."user_id" = ${userId}
        AND fl."logged_at" >= (d AT TIME ZONE ${timeZone}) AT TIME ZONE 'UTC'
        AND fl."logged_at" < ((d + interval '1 day') AT TIME ZONE ${timeZone}) AT TIME ZONE 'UTC'
      LEFT JOIN "foods" f ON f.id = fl."food_id"
      GROUP BY d
      ORDER BY d ASC
    `;

    return rows.map((r) => ({
      date: r.date.toISOString().slice(0, 10),
      totalKcal: r.totalKcal,
      totalProtein: r.totalProtein,
      totalCarbs: r.totalCarbs,
      totalFat: r.totalFat,
    }));
  }
}

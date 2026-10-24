import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { FoodsService } from '../foods/foods.service';
import { MealsService } from '../meals/meals.service';
import type { FoodListItem } from '../foods/foods.service';
import type { FoodLogItem } from '../food-logs/food-logs.service';
import type { ApplySavedMealInput, CreateSavedMealInput, UpdateSavedMealInput } from './dto';

export interface SavedMealItemDetail {
  id: string;
  quantity: number;
  order: number;
  food: FoodListItem;
}

export interface SavedMealDetail {
  id: string;
  name: string;
  items: SavedMealItemDetail[];
}

export interface SavedMealSummary {
  id: string;
  name: string;
  itemCount: number;
  itemPreview: string[];
  totalKcal: number;
}

const FOOD_SELECT = {
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
} satisfies Prisma.FoodSelect;

const SAVED_MEAL_DETAIL_SELECT = {
  id: true,
  name: true,
  items: {
    orderBy: { order: 'asc' as const },
    select: {
      id: true,
      quantity: true,
      order: true,
      food: { select: FOOD_SELECT },
    },
  },
} satisfies Prisma.SavedMealSelect;

// mirrors FOOD_LOG_SELECT in food-logs/food-logs.service.ts — duplicated
// rather than imported since FoodLogsService isn't a dependency of this
// module: applyToLog writes FoodLog rows directly through this service's own
// PrismaClient (each service owns its client, same convention as the rest of
// the project), so there's no shared transaction to hand off to another
// service's method
const FOOD_LOG_ITEM_SELECT = {
  id: true,
  quantity: true,
  enteredAsServing: true,
  mealId: true,
  loggedAt: true,
  food: { select: FOOD_SELECT },
} satisfies Prisma.FoodLogSelect;

type SavedMealWithItems = {
  id: string;
  name: string;
  items: SavedMealItemDetail[];
};

function toDetail(meal: SavedMealWithItems): SavedMealDetail {
  return { id: meal.id, name: meal.name, items: meal.items };
}

@Injectable()
export class SavedMealsService {
  private readonly prisma: PrismaClient;

  constructor(
    private readonly config: ConfigService,
    private readonly foodsService: FoodsService,
    private readonly mealsService: MealsService,
  ) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  async create(userId: string, input: CreateSavedMealInput): Promise<SavedMealDetail> {
    await this.foodsService.assertVisible(
      userId,
      input.items.map((i) => i.foodId),
    );

    const meal = await this.prisma.savedMeal.create({
      data: {
        userId,
        name: input.name,
        items: {
          create: input.items.map((i, idx) => ({
            foodId: i.foodId,
            quantity: i.quantity,
            order: idx + 1,
          })),
        },
      },
      select: SAVED_MEAL_DETAIL_SELECT,
    });

    return toDetail(meal);
  }

  async list(userId: string): Promise<SavedMealSummary[]> {
    const meals = await this.prisma.savedMeal.findMany({
      where: { userId },
      orderBy: { updatedAt: 'desc' },
      select: {
        id: true,
        name: true,
        items: {
          orderBy: { order: 'asc' },
          select: { quantity: true, food: { select: { name: true, kcal: true } } },
        },
      },
    });

    return meals.map((m) => ({
      id: m.id,
      name: m.name,
      itemCount: m.items.length,
      itemPreview: m.items.slice(0, 3).map((i) => i.food.name),
      totalKcal: m.items.reduce((sum, i) => sum + (i.food.kcal * i.quantity) / 100, 0),
    }));
  }

  async findById(userId: string, id: string): Promise<SavedMealDetail | null> {
    const meal = await this.prisma.savedMeal.findFirst({
      where: { id, userId },
      select: SAVED_MEAL_DETAIL_SELECT,
    });
    return meal ? toDetail(meal) : null;
  }

  // name update and items replace run in one transaction — the editor always
  // sends the full state it built in memory (see useSavedMealEditor), so
  // there's nothing to diff. `order` comes from array position (1-based),
  // matching create() — same delete+createMany shape as
  // WorkoutTemplatesService.update
  async update(userId: string, id: string, input: UpdateSavedMealInput): Promise<SavedMealDetail> {
    await this.assertOwned(userId, id);
    if (input.items !== undefined) {
      await this.foodsService.assertVisible(
        userId,
        input.items.map((i) => i.foodId),
      );
    }

    const ops: Prisma.PrismaPromise<unknown>[] = [
      this.prisma.savedMeal.update({
        where: { id },
        data: {
          ...(input.name !== undefined && { name: input.name }),
        },
      }),
    ];
    if (input.items !== undefined) {
      const items = input.items;
      ops.push(
        this.prisma.savedMealItem.deleteMany({ where: { savedMealId: id } }),
        this.prisma.savedMealItem.createMany({
          data: items.map((i, idx) => ({
            savedMealId: id,
            foodId: i.foodId,
            quantity: i.quantity,
            order: idx + 1,
          })),
        }),
      );
    }
    await this.prisma.$transaction(ops);

    return (await this.findById(userId, id))!;
  }

  async remove(userId: string, id: string): Promise<void> {
    await this.assertOwned(userId, id);
    // cascades to SavedMealItem
    await this.prisma.savedMeal.delete({ where: { id } });
  }

  // Single-call "apply" — mirrors WorkoutsService.startOrResume instantiating
  // a Workout from a WorkoutTemplate in one call, instead of the
  // N-sequential-POST loop AddMealPage's ad-hoc cart uses for its own cart.
  // Every item becomes an ordinary FoodLog row, indistinguishable from one
  // added by hand — no savedMealId provenance, deliberately (see plan)
  async applyToLog(userId: string, id: string, input: ApplySavedMealInput): Promise<FoodLogItem[]> {
    const meal = await this.findById(userId, id);
    if (!meal) {
      throw new NotFoundException(`Saved meal ${id} not found`);
    }
    if (meal.items.length === 0) {
      throw new BadRequestException('Saved meal has no items to apply');
    }
    // same reason as FoodLogsService.create — the target meal id arrives from
    // the client and only ownership makes it safe to write
    await this.mealsService.assertOwned(userId, input.mealId);

    // A resend with the same clientId answers with what the first apply
    // wrote. Each Registro carries `<clientId>:<n>` in FoodLog.clientId (no
    // column of its own): POST /food-logs only accepts a bare UUID there, so
    // the two can't collide, and the transaction below is all-or-nothing, so
    // any match means the whole apply landed
    const { clientId } = input;
    if (clientId) {
      const stored = await this.findApplied(userId, clientId);
      if (stored.length > 0) return stored;
    }

    try {
      return await this.prisma.$transaction(
        meal.items.map((item, idx) =>
          this.prisma.foodLog.create({
            data: {
              userId,
              foodId: item.food.id,
              quantity: item.quantity,
              mealId: input.mealId,
              loggedAt: input.loggedAt,
              ...(clientId && { clientId: `${clientId}:${idx + 1}` }),
            },
            select: FOOD_LOG_ITEM_SELECT,
          }),
        ),
      );
    } catch (e) {
      // two resends racing past the lookup: the unique [userId, clientId]
      // lets one transaction through — same duck-typed check as
      // FoodLogsService.create
      if (!(clientId && (e as { code?: unknown }).code === 'P2002')) throw e;
      const winner = await this.findApplied(userId, clientId);
      if (winner.length === 0) throw e;
      return winner;
    }
  }

  // ordered by the `:<n>` suffix — as strings `:10` would sort before `:2`
  private async findApplied(userId: string, clientId: string): Promise<FoodLogItem[]> {
    const prefix = `${clientId}:`;
    const rows = await this.prisma.foodLog.findMany({
      where: { userId, clientId: { startsWith: prefix } },
      select: { ...FOOD_LOG_ITEM_SELECT, clientId: true },
    });
    const position = (key: string | null) => Number((key ?? '').slice(prefix.length));
    return rows
      .sort((a, b) => position(a.clientId) - position(b.clientId))
      .map((row) => {
        const log: Partial<typeof row> = { ...row };
        delete log.clientId;
        return log as FoodLogItem;
      });
  }

  private async assertOwned(userId: string, id: string): Promise<void> {
    const meal = await this.prisma.savedMeal.findFirst({
      where: { id, userId },
      select: { id: true },
    });
    if (!meal) {
      throw new NotFoundException(`Saved meal ${id} not found`);
    }
  }
}

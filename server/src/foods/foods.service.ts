import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import type { CreateCustomFoodInput } from './foods.dto';
import { OpenFoodFactsService } from './open-food-facts.service';

const MAX_SEARCH_RESULTS = 50;

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

export interface FoodListItem {
  id: string;
  name: string;
  brand: string | null;
  source: string;
  imageUrl: string | null;
  kcal: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber: number | null;
  sodium: number | null;
  /** closed slug from serving-units.ts, or null for grams-only foods */
  servingLabel: string | null;
  /** grams in one serving — the client converts units → grams with it */
  servingGrams: number | null;
}

@Injectable()
export class FoodsService {
  private readonly prisma: PrismaClient;

  constructor(
    private readonly config: ConfigService,
    private readonly openFoodFacts: OpenFoodFactsService,
  ) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  // TACO/OFF are shared reference data (visible to everyone, same as SEED
  // exercises); CUSTOM foods are scoped to their creator, same as USER
  // exercises — see ExercisesService.visibilityWhere for the precedent
  private visibilityWhere(userId: string): Prisma.FoodWhereInput {
    return {
      OR: [{ source: { in: ['TACO', 'OFF'] } }, { source: 'CUSTOM', createdByUserId: userId }],
    };
  }

  // batched visibility check for a set of foodIds coming from client input
  // (e.g. SavedMealsService.create/update) — single count query rather than
  // the one-by-one findById loop WorkoutTemplatesService.assertExercisesVisible
  // uses, since foods have no per-id detail lookup worth reusing here
  async assertVisible(userId: string, foodIds: string[]): Promise<void> {
    const uniqueIds = [...new Set(foodIds)];
    const count = await this.prisma.food.count({
      where: { id: { in: uniqueIds }, ...this.visibilityWhere(userId) },
    });
    if (count !== uniqueIds.length) {
      throw new BadRequestException('One or more foodId values are invalid or not visible');
    }
  }

  // local-only lookup — never calls Open Food Facts here, its docs prohibit
  // using the product endpoint as search-as-you-type
  async search(userId: string, query: string): Promise<FoodListItem[]> {
    return this.prisma.food.findMany({
      where: {
        AND: [this.visibilityWhere(userId), { name: { contains: query, mode: 'insensitive' } }],
      },
      orderBy: { name: 'asc' },
      take: MAX_SEARCH_RESULTS,
      select: FOOD_SELECT,
    });
  }

  // A scanned code with no match comes back here as externalId, so the next
  // scan finds the food (see findByBarcode). @@unique([source, externalId])
  // is global, though: a resend returns the caller's food already linked,
  // and a code another user linked first saves this food unlinked, without a
  // 500 and without saying whose food holds it.
  async createCustom(userId: string, input: CreateCustomFoodInput): Promise<FoodListItem> {
    const { externalId } = input;
    if (externalId) {
      const own = await this.findOwnLinked(userId, externalId);
      if (own) return own;
    }
    try {
      return await this.insertCustom(userId, input, externalId);
    } catch (e) {
      // duck-typed rather than instanceof — tests mock @prisma/client
      if (!(externalId && (e as { code?: unknown }).code === 'P2002')) throw e;
      return (await this.findOwnLinked(userId, externalId)) ?? this.insertCustom(userId, input, undefined);
    }
  }

  private insertCustom(
    userId: string,
    input: CreateCustomFoodInput,
    externalId: string | undefined,
  ): Promise<FoodListItem> {
    return this.prisma.food.create({
      data: {
        name: input.name,
        source: 'CUSTOM',
        externalId,
        createdByUserId: userId,
        kcal: input.kcal,
        protein: input.protein,
        carbs: input.carbs,
        fat: input.fat,
        fiber: input.fiber,
        sodium: input.sodium,
        servingLabel: input.servingLabel,
        servingGrams: input.servingGrams,
      },
      select: FOOD_SELECT,
    });
  }

  private findOwnLinked(userId: string, barcode: string): Promise<FoodListItem | null> {
    return this.prisma.food.findFirst({
      where: { source: 'CUSTOM', externalId: barcode, createdByUserId: userId },
      select: FOOD_SELECT,
    });
  }

  // the caller's own CUSTOM food linked to the code (a manual cadastro after
  // an earlier 404) → local cache (source OFF, externalId = barcode) → Open
  // Food Facts → upsert into the cache → 404 if none has it, so the frontend
  // can offer manual cadastro. Never hits OFF for a barcode already cached,
  // except to fill in a serving size the cache predates (see below).
  async findByBarcode(userId: string, barcode: string): Promise<FoodListItem> {
    const own = await this.findOwnLinked(userId, barcode);
    if (own) return own;

    const cached = await this.prisma.food.findUnique({
      where: { source_externalId: { source: 'OFF', externalId: barcode } },
      select: FOOD_SELECT,
    });
    if (cached) return this.backfillCachedServing(cached, barcode);

    const off = await this.openFoodFacts.lookupByBarcode(barcode);
    if (!off) {
      throw new NotFoundException(`No food found for barcode ${barcode}`);
    }

    return this.prisma.food.create({
      data: {
        name: off.name,
        brand: off.brand,
        source: 'OFF',
        externalId: barcode,
        imageUrl: off.imageUrl,
        kcal: off.kcal,
        protein: off.protein,
        carbs: off.carbs,
        fat: off.fat,
        fiber: off.fiber,
        sodium: off.sodium,
        servingLabel: off.servingGrams === null ? null : 'serving',
        servingGrams: off.servingGrams,
      },
      select: FOOD_SELECT,
    });
  }

  // Rows cached before serving sizes existed have servingGrams null, and a
  // plain cache hit would keep them grams-only forever. One re-lookup fills
  // them in; best-effort, so a null result (network, or OFF genuinely has no
  // serving for this product) just returns the cached row untouched — never
  // downgrades a hit we already have into a 404. Only fires while the value
  // is missing, so it's a one-shot cost per stale product, not per scan.
  private async backfillCachedServing(
    cached: FoodListItem,
    barcode: string,
  ): Promise<FoodListItem> {
    if (cached.servingGrams !== null) return cached;

    const off = await this.openFoodFacts.lookupByBarcode(barcode);
    if (!off || off.servingGrams === null) return cached;

    return this.prisma.food.update({
      where: { id: cached.id },
      data: { servingLabel: 'serving', servingGrams: off.servingGrams },
      select: FOOD_SELECT,
    });
  }
}

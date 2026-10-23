import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { FoodsService } from 'src/foods/foods.service';
import { OpenFoodFactsService } from 'src/foods/open-food-facts.service';

const { mockPrisma } = vi.hoisted(() => {
  return {
    mockPrisma: {
      food: {
        findMany: vi.fn(),
        create: vi.fn(),
        findUnique: vi.fn(),
        findFirst: vi.fn(),
        update: vi.fn(),
        count: vi.fn(),
      },
    },
  };
});

vi.mock('@prisma/client', () => {
  return {
    Prisma: {},
    PrismaClient: vi.fn().mockImplementation(function (this: any) {
      return mockPrisma;
    }),
  };
});

vi.mock('@prisma/adapter-pg', () => {
  return {
    PrismaPg: class {},
  };
});

const USER_ID = 'user_test_123';

describe('FoodsService', () => {
  let service: FoodsService;
  let mockOpenFoodFacts: { lookupByBarcode: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    vi.clearAllMocks();
    mockOpenFoodFacts = { lookupByBarcode: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FoodsService,
        {
          provide: ConfigService,
          useValue: { get: vi.fn(() => 'postgresql://test') },
        },
        { provide: OpenFoodFactsService, useValue: mockOpenFoodFacts },
      ],
    }).compile();

    service = module.get(FoodsService);
  });

  describe('search', () => {
    it('scopes results to shared TACO/OFF library plus the caller-owned CUSTOM foods', async () => {
      mockPrisma.food.findMany.mockResolvedValueOnce([]);

      await service.search(USER_ID, 'arroz');

      const where = mockPrisma.food.findMany.mock.calls[0][0].where;
      expect(where.AND[0]).toEqual({
        OR: [{ source: { in: ['TACO', 'OFF'] } }, { source: 'CUSTOM', createdByUserId: USER_ID }],
      });
    });

    it('filters by case-insensitive name match on the query', async () => {
      mockPrisma.food.findMany.mockResolvedValueOnce([]);

      await service.search(USER_ID, 'Arroz');

      const where = mockPrisma.food.findMany.mock.calls[0][0].where;
      expect(where.AND[1]).toEqual({ name: { contains: 'Arroz', mode: 'insensitive' } });
    });
  });

  describe('createCustom', () => {
    it('always sets source CUSTOM and createdByUserId from the authenticated caller', async () => {
      mockPrisma.food.create.mockResolvedValueOnce({ id: 'food1' });

      await service.createCustom(USER_ID, {
        name: 'Homemade granola',
        kcal: 450,
        protein: 10,
        carbs: 60,
        fat: 15,
      });

      const data = mockPrisma.food.create.mock.calls[0][0].data;
      expect(data.source).toBe('CUSTOM');
      expect(data.createdByUserId).toBe(USER_ID);
      expect(data.externalId).toBeUndefined();
    });

    it('links the custom food to a scanned barcode when externalId is provided', async () => {
      mockPrisma.food.create.mockResolvedValueOnce({ id: 'food2' });

      await service.createCustom(USER_ID, {
        name: 'Local snack',
        kcal: 200,
        protein: 5,
        carbs: 30,
        fat: 8,
        externalId: '7891234567890',
      });

      const data = mockPrisma.food.create.mock.calls[0][0].data;
      expect(data.externalId).toBe('7891234567890');
    });

    // a resend (double tap, retry) of the same scanned-code cadastro
    it("returns the caller's food already linked to the barcode instead of creating another", async () => {
      mockPrisma.food.findFirst.mockResolvedValueOnce({ id: 'linked-food' });

      const result = await service.createCustom(USER_ID, {
        name: 'Local snack',
        kcal: 200,
        protein: 5,
        carbs: 30,
        fat: 8,
        externalId: '7891234567890',
      });

      expect(result).toEqual({ id: 'linked-food' });
      expect(mockPrisma.food.findFirst.mock.calls[0][0].where).toEqual({
        source: 'CUSTOM',
        externalId: '7891234567890',
        createdByUserId: USER_ID,
      });
      expect(mockPrisma.food.create).not.toHaveBeenCalled();
    });

    // @@unique([source, externalId]) is global: another user's link must not
    // turn this cadastro into a 500, nor reveal whose food holds the code
    it('saves the food unlinked when another user already linked the barcode', async () => {
      mockPrisma.food.findFirst.mockResolvedValue(null);
      mockPrisma.food.create
        .mockRejectedValueOnce(Object.assign(new Error('unique'), { code: 'P2002' }))
        .mockResolvedValueOnce({ id: 'unlinked-food' });

      const result = await service.createCustom(USER_ID, {
        name: 'Local snack',
        kcal: 200,
        protein: 5,
        carbs: 30,
        fat: 8,
        externalId: '7891234567890',
      });

      expect(result).toEqual({ id: 'unlinked-food' });
      expect(mockPrisma.food.create.mock.calls[1][0].data.externalId).toBeUndefined();
      mockPrisma.food.findFirst.mockReset();
    });

    it('rethrows a unique violation when no barcode was sent', async () => {
      mockPrisma.food.create.mockRejectedValueOnce(Object.assign(new Error('unique'), { code: 'P2002' }));

      await expect(
        service.createCustom(USER_ID, { name: 'Granola', kcal: 450, protein: 10, carbs: 60, fat: 15 }),
      ).rejects.toThrow('unique');
    });
  });

  describe('assertVisible', () => {
    it('resolves when every foodId is visible to the caller', async () => {
      mockPrisma.food.count.mockResolvedValueOnce(2);

      await expect(
        service.assertVisible(USER_ID, ['food1', 'food2']),
      ).resolves.toBeUndefined();
      const where = mockPrisma.food.count.mock.calls[0][0].where;
      expect(where.id).toEqual({ in: ['food1', 'food2'] });
    });

    it('dedupes foodIds before comparing against the count', async () => {
      mockPrisma.food.count.mockResolvedValueOnce(1);

      await expect(
        service.assertVisible(USER_ID, ['food1', 'food1']),
      ).resolves.toBeUndefined();
      const where = mockPrisma.food.count.mock.calls[0][0].where;
      expect(where.id).toEqual({ in: ['food1'] });
    });

    it('rejects when some foodId is missing or not visible to the caller', async () => {
      mockPrisma.food.count.mockResolvedValueOnce(1); // only 1 of 2 matched

      await expect(service.assertVisible(USER_ID, ['food1', 'food2'])).rejects.toThrow();
    });
  });

  describe('findByBarcode', () => {
    const BARCODE = '7891234567890';

    // the manual cadastro after a 404 links the CUSTOM food to the code
    it("returns the caller's own food linked to the barcode before the cache and Open Food Facts", async () => {
      mockPrisma.food.findFirst.mockResolvedValueOnce({ id: 'own-food' });

      const result = await service.findByBarcode(USER_ID, BARCODE);

      expect(result).toEqual({ id: 'own-food' });
      expect(mockPrisma.food.findFirst.mock.calls[0][0].where).toEqual({
        source: 'CUSTOM',
        externalId: BARCODE,
        createdByUserId: USER_ID,
      });
      expect(mockPrisma.food.findUnique).not.toHaveBeenCalled();
      expect(mockOpenFoodFacts.lookupByBarcode).not.toHaveBeenCalled();
    });

    it('returns the local cache hit without calling Open Food Facts', async () => {
      mockPrisma.food.findUnique.mockResolvedValueOnce({ id: 'cached-food', servingGrams: 30 });

      const result = await service.findByBarcode(USER_ID, BARCODE);

      expect(result).toEqual({ id: 'cached-food', servingGrams: 30 });
      expect(mockOpenFoodFacts.lookupByBarcode).not.toHaveBeenCalled();
      expect(mockPrisma.food.create).not.toHaveBeenCalled();
    });

    // rows cached before serving sizes existed would otherwise stay grams-only forever
    it('re-queries Open Food Facts for a cache hit missing the serving size', async () => {
      mockPrisma.food.findUnique.mockResolvedValueOnce({ id: 'stale-food', servingGrams: null });
      mockOpenFoodFacts.lookupByBarcode.mockResolvedValueOnce({ servingGrams: 30 });
      mockPrisma.food.update.mockResolvedValueOnce({ id: 'stale-food', servingGrams: 30 });

      const result = await service.findByBarcode(USER_ID, BARCODE);

      expect(mockOpenFoodFacts.lookupByBarcode).toHaveBeenCalledWith(BARCODE);
      expect(mockPrisma.food.update.mock.calls[0][0]).toMatchObject({
        where: { id: 'stale-food' },
        data: { servingLabel: 'serving', servingGrams: 30 },
      });
      expect(result).toEqual({ id: 'stale-food', servingGrams: 30 });
    });

    it('keeps the cached row when Open Food Facts has no serving size either', async () => {
      mockPrisma.food.findUnique.mockResolvedValueOnce({ id: 'stale-food', servingGrams: null });
      mockOpenFoodFacts.lookupByBarcode.mockResolvedValueOnce({ servingGrams: null });

      const result = await service.findByBarcode(USER_ID, BARCODE);

      expect(result).toEqual({ id: 'stale-food', servingGrams: null });
      expect(mockPrisma.food.update).not.toHaveBeenCalled();
    });

    it('falls back to Open Food Facts and caches the result locally on a miss', async () => {
      mockPrisma.food.findUnique.mockResolvedValueOnce(null);
      mockOpenFoodFacts.lookupByBarcode.mockResolvedValueOnce({
        name: 'Nutella',
        brand: 'Ferrero',
        imageUrl: 'https://images.openfoodfacts.org/nutella.jpg',
        kcal: 539,
        protein: 6.3,
        carbs: 57.5,
        fat: 30.9,
        fiber: null,
        sodium: 42.8,
      });
      mockPrisma.food.create.mockResolvedValueOnce({ id: 'new-food' });

      const result = await service.findByBarcode(USER_ID, BARCODE);

      expect(mockOpenFoodFacts.lookupByBarcode).toHaveBeenCalledWith(BARCODE);
      const data = mockPrisma.food.create.mock.calls[0][0].data;
      expect(data).toMatchObject({ source: 'OFF', externalId: BARCODE, name: 'Nutella' });
      expect(result).toEqual({ id: 'new-food' });
    });

    it('throws NotFoundException when neither the cache nor Open Food Facts has it', async () => {
      mockPrisma.food.findUnique.mockResolvedValueOnce(null);
      mockOpenFoodFacts.lookupByBarcode.mockResolvedValueOnce(null);

      await expect(service.findByBarcode(USER_ID, BARCODE)).rejects.toThrow();
      expect(mockPrisma.food.create).not.toHaveBeenCalled();
    });
  });
});

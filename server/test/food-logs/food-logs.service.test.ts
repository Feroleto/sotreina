import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { FoodLogsService } from 'src/food-logs/food-logs.service';
import { MealsService } from 'src/meals/meals.service';

const { mockPrisma } = vi.hoisted(() => {
  return {
    mockPrisma: {
      $queryRaw: vi.fn(),
      foodLog: {
        create: vi.fn(),
        findFirst: vi.fn(),
        findMany: vi.fn(),
        findUniqueOrThrow: vi.fn(),
        updateMany: vi.fn(),
        deleteMany: vi.fn(),
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

describe('FoodLogsService', () => {
  let service: FoodLogsService;
  let assertOwned: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    vi.clearAllMocks();
    assertOwned = vi.fn().mockResolvedValue(undefined);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FoodLogsService,
        {
          provide: ConfigService,
          useValue: { get: vi.fn(() => 'postgresql://test') },
        },
        { provide: MealsService, useValue: { assertOwned } },
      ],
    }).compile();

    service = module.get(FoodLogsService);
  });

  describe('create', () => {
    it('creates a log scoped to the authenticated user', async () => {
      mockPrisma.foodLog.create.mockResolvedValueOnce({ id: 'log1' });

      await service.create(USER_ID, {
        foodId: 'food1',
        quantity: 150,
        enteredAsServing: false,
        mealId: 'meal1',
        loggedAt: new Date('2026-07-29T12:00:00.000Z'),
      });

      const data = mockPrisma.foodLog.create.mock.calls[0][0].data;
      expect(data.userId).toBe(USER_ID);
      expect(data.foodId).toBe('food1');
      expect(data.quantity).toBe(150);
      expect(data.mealId).toBe('meal1');
      expect(assertOwned).toHaveBeenCalledWith(USER_ID, 'meal1');
    });

    // a mealId is guessable in a way the closed MealType enum it replaced
    // never was — the ownership assert is the only thing standing between a
    // forged body and a log attached to someone else's meal
    it('refuses to write when the meal is not the caller’s', async () => {
      assertOwned.mockRejectedValueOnce(new NotFoundException());

      await expect(
        service.create(USER_ID, {
          foodId: 'food1',
          quantity: 150,
          enteredAsServing: false,
          mealId: 'someone_elses_meal',
          loggedAt: new Date('2026-07-29T12:00:00.000Z'),
        }),
      ).rejects.toThrow(NotFoundException);

      expect(mockPrisma.foodLog.create).not.toHaveBeenCalled();
    });

    it('persists the enteredAsServing display hint alongside the grams', async () => {
      mockPrisma.foodLog.create.mockResolvedValueOnce({ id: 'log1' });

      await service.create(USER_ID, {
        foodId: 'food1',
        // 2 eggs of 50g — stored as grams, flagged as entered in servings
        quantity: 100,
        enteredAsServing: true,
        mealId: 'meal1',
        loggedAt: new Date('2026-07-29T09:00:00.000Z'),
      });

      const data = mockPrisma.foodLog.create.mock.calls[0][0].data;
      expect(data.quantity).toBe(100);
      expect(data.enteredAsServing).toBe(true);
    });

    describe('clientId', () => {
      const CLIENT_ID = '6f1c2b7e-3d4a-4b5c-9e8f-0a1b2c3d4e5f';
      const input = {
        foodId: 'food1',
        quantity: 150,
        enteredAsServing: false,
        mealId: 'meal1',
        loggedAt: new Date('2026-07-29T12:00:00.000Z'),
        clientId: CLIENT_ID,
      };

      it('stores the clientId on a new log', async () => {
        mockPrisma.foodLog.findFirst.mockResolvedValueOnce(null);
        mockPrisma.foodLog.create.mockResolvedValueOnce({ id: 'log1' });

        await service.create(USER_ID, input);

        expect(mockPrisma.foodLog.findFirst).toHaveBeenCalledWith(
          expect.objectContaining({ where: { userId: USER_ID, clientId: CLIENT_ID } }),
        );
        expect(mockPrisma.foodLog.create.mock.calls[0][0].data.clientId).toBe(CLIENT_ID);
      });

      it('a resend with a known clientId returns the stored log without creating a duplicate', async () => {
        mockPrisma.foodLog.findFirst.mockResolvedValueOnce({ id: 'log1' });

        const log = await service.create(USER_ID, input);

        expect(log).toEqual({ id: 'log1' });
        expect(mockPrisma.foodLog.create).not.toHaveBeenCalled();
      });

      it('two resends racing past the lookup: the P2002 is swallowed and the winner is returned', async () => {
        mockPrisma.foodLog.findFirst.mockResolvedValueOnce(null).mockResolvedValueOnce({ id: 'log1' });
        mockPrisma.foodLog.create.mockRejectedValueOnce({ code: 'P2002' });

        const log = await service.create(USER_ID, input);

        expect(log).toEqual({ id: 'log1' });
      });

      it('without a clientId a P2002 is not swallowed and no lookup happens', async () => {
        mockPrisma.foodLog.create.mockRejectedValueOnce({ code: 'P2002' });

        await expect(service.create(USER_ID, { ...input, clientId: undefined })).rejects.toEqual({
          code: 'P2002',
        });
        expect(mockPrisma.foodLog.findFirst).not.toHaveBeenCalled();
      });

      it('checks meal ownership before answering a resend', async () => {
        assertOwned.mockRejectedValueOnce(new NotFoundException());

        await expect(service.create(USER_ID, input)).rejects.toThrow(NotFoundException);
        expect(mockPrisma.foodLog.findFirst).not.toHaveBeenCalled();
      });
    });
  });

  describe('update', () => {
    it('updates scoped by id and userId together, then reads the row back', async () => {
      mockPrisma.foodLog.updateMany.mockResolvedValueOnce({ count: 1 });
      mockPrisma.foodLog.findUniqueOrThrow.mockResolvedValueOnce({ id: 'log1', quantity: 150 });

      const result = await service.update(USER_ID, 'log1', {
        quantity: 150,
        enteredAsServing: false,
      });

      expect(mockPrisma.foodLog.updateMany).toHaveBeenCalledWith({
        where: { id: 'log1', userId: USER_ID },
        data: { quantity: 150, enteredAsServing: false },
      });
      expect(result).toEqual({ id: 'log1', quantity: 150 });
    });

    it('throws NotFoundException for another user’s log, without reading it back', async () => {
      mockPrisma.foodLog.updateMany.mockResolvedValueOnce({ count: 0 });

      await expect(
        service.update(USER_ID, 'log1', { quantity: 150, enteredAsServing: false }),
      ).rejects.toThrow();
      expect(mockPrisma.foodLog.findUniqueOrThrow).not.toHaveBeenCalled();
    });
  });

  describe('findByDate', () => {
    it('scopes to the user and the UTC day boundary for the given date', async () => {
      mockPrisma.foodLog.findMany.mockResolvedValueOnce([]);

      await service.findByDate(USER_ID, '2026-07-29');

      const where = mockPrisma.foodLog.findMany.mock.calls[0][0].where;
      expect(where.userId).toBe(USER_ID);
      expect(where.loggedAt.gte).toEqual(new Date('2026-07-29T00:00:00.000Z'));
      expect(where.loggedAt.lt).toEqual(new Date('2026-07-30T00:00:00.000Z'));
    });

    it("uses the caller's local midnight when a time zone is given", async () => {
      mockPrisma.foodLog.findMany.mockResolvedValueOnce([]);

      await service.findByDate(USER_ID, '2026-07-29', 'America/Sao_Paulo');

      const where = mockPrisma.foodLog.findMany.mock.calls[0][0].where;
      expect(where.loggedAt.gte).toEqual(new Date('2026-07-29T03:00:00.000Z'));
      expect(where.loggedAt.lt).toEqual(new Date('2026-07-30T03:00:00.000Z'));
    });
  });

  describe('remove', () => {
    it('deletes scoped by id and userId together (404-not-403 convention)', async () => {
      mockPrisma.foodLog.deleteMany.mockResolvedValueOnce({ count: 1 });

      await service.remove(USER_ID, 'log1');

      expect(mockPrisma.foodLog.deleteMany).toHaveBeenCalledWith({
        where: { id: 'log1', userId: USER_ID },
      });
    });

    it('throws NotFoundException when nothing matched (not owned, or does not exist)', async () => {
      mockPrisma.foodLog.deleteMany.mockResolvedValueOnce({ count: 0 });

      await expect(service.remove(USER_ID, 'log1')).rejects.toThrow();
    });
  });

  describe('getDailySummary', () => {
    it('returns the summed macros from $queryRaw', async () => {
      const row = { totalKcal: 900, totalProtein: 40, totalCarbs: 100, totalFat: 30 };
      mockPrisma.$queryRaw.mockResolvedValueOnce([row]);

      const result = await service.getDailySummary(USER_ID, '2026-07-29');

      expect(result).toEqual(row);
      expect(mockPrisma.$queryRaw).toHaveBeenCalledTimes(1);
    });

    it('returns all-zero totals when there are no logs for the day', async () => {
      mockPrisma.$queryRaw.mockResolvedValueOnce([]);

      const result = await service.getDailySummary(USER_ID, '2026-07-29');

      expect(result).toEqual({ totalKcal: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0 });
    });
  });

  describe('getHistory', () => {
    it('formats each row date to YYYY-MM-DD and passes through the totals', async () => {
      mockPrisma.$queryRaw.mockResolvedValueOnce([
        {
          date: new Date('2026-07-29T00:00:00.000Z'),
          totalKcal: 1800,
          totalProtein: 120,
          totalCarbs: 200,
          totalFat: 60,
        },
      ]);

      const result = await service.getHistory(USER_ID, 7);

      expect(result).toEqual([
        { date: '2026-07-29', totalKcal: 1800, totalProtein: 120, totalCarbs: 200, totalFat: 60 },
      ]);
      expect(mockPrisma.$queryRaw).toHaveBeenCalledTimes(1);
    });

    it('returns an empty array when generate_series produces no rows (defensive)', async () => {
      mockPrisma.$queryRaw.mockResolvedValueOnce([]);

      const result = await service.getHistory(USER_ID, 14);

      expect(result).toEqual([]);
    });
  });
});

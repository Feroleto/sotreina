import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { UsersService } from 'src/users/users.service';

const { mockPrisma } = vi.hoisted(() => {
  return {
    mockPrisma: {
      user: {
        findUniqueOrThrow: vi.fn(),
        update: vi.fn(),
      },
    },
  };
});

vi.mock('@prisma/client', () => {
  return {
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

const FULL_SNAPSHOT = {
  maxHr: 185,
  dailyKcalGoal: 2000,
  dailyProteinGoal: 150,
  dailyCarbsGoal: 250,
  dailyFatGoal: 65,
  weeklyRunKmGoal: 20,
  weeklyWorkoutsGoal: 3,
};

describe('UsersService', () => {
  let service: UsersService;

  beforeEach(async () => {
    vi.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: ConfigService,
          useValue: { get: vi.fn(() => 'postgresql://test') },
        },
      ],
    }).compile();

    service = module.get(UsersService);
  });

  describe('getMe', () => {
    it('returns the maxHr and nutrition goals from the user row', async () => {
      mockPrisma.user.findUniqueOrThrow.mockResolvedValueOnce(FULL_SNAPSHOT);

      const result = await service.getMe(USER_ID);

      expect(result).toEqual(FULL_SNAPSHOT);
      expect(mockPrisma.user.findUniqueOrThrow).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: USER_ID } }),
      );
    });

    it('returns null maxHr when it has not been set yet', async () => {
      mockPrisma.user.findUniqueOrThrow.mockResolvedValueOnce({ ...FULL_SNAPSHOT, maxHr: null });

      const result = await service.getMe(USER_ID);

      expect(result.maxHr).toBeNull();
    });
  });

  describe('updateMe', () => {
    it('updates and returns the new maxHr', async () => {
      mockPrisma.user.update.mockResolvedValueOnce({ ...FULL_SNAPSHOT, maxHr: 190 });

      const result = await service.updateMe(USER_ID, { maxHr: 190 });

      expect(result.maxHr).toBe(190);
      expect(mockPrisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: USER_ID },
          data: { maxHr: 190 },
        }),
      );
    });

    it('updates and returns the new nutrition goals', async () => {
      const updated = { ...FULL_SNAPSHOT, dailyKcalGoal: 2500, dailyProteinGoal: 180 };
      mockPrisma.user.update.mockResolvedValueOnce(updated);

      const result = await service.updateMe(USER_ID, {
        dailyKcalGoal: 2500,
        dailyProteinGoal: 180,
      });

      expect(result).toEqual(updated);
      expect(mockPrisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: USER_ID },
          data: { dailyKcalGoal: 2500, dailyProteinGoal: 180 },
        }),
      );
    });

    it('updates the weekly goals and selects them back in the snapshot', async () => {
      const updated = { ...FULL_SNAPSHOT, weeklyRunKmGoal: 35, weeklyWorkoutsGoal: 4 };
      mockPrisma.user.update.mockResolvedValueOnce(updated);

      const result = await service.updateMe(USER_ID, {
        weeklyRunKmGoal: 35,
        weeklyWorkoutsGoal: 4,
      });

      expect(result).toEqual(updated);
      expect(mockPrisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: { weeklyRunKmGoal: 35, weeklyWorkoutsGoal: 4 },
          select: expect.objectContaining({ weeklyRunKmGoal: true, weeklyWorkoutsGoal: true }),
        }),
      );
    });
  });
});

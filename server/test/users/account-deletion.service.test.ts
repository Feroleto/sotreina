import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { AccountDeletionService } from 'src/users/account-deletion.service';
import { StravaAuthService } from 'src/strava/auth/strava-auth.service';

const { mockPrisma } = vi.hoisted(() => ({
  mockPrisma: {
    user: { findUnique: vi.fn(), delete: vi.fn() },
    food: { findMany: vi.fn(), deleteMany: vi.fn() },
    exercise: { findMany: vi.fn(), deleteMany: vi.fn() },
    $transaction: vi.fn((ops: unknown[]) => Promise.all(ops as Promise<unknown>[])),
  },
}));

vi.mock('@prisma/client', () => ({
  PrismaClient: vi.fn().mockImplementation(function (this: any) {
    return mockPrisma;
  }),
}));

vi.mock('@prisma/adapter-pg', () => ({ PrismaPg: class {} }));

vi.mock('src/auth/password', () => ({
  verifyPassword: vi.fn(async (hash: string, plain: string) => hash === `hashed:${plain}`),
}));

const USER_ID = 'user_test_123';

describe('AccountDeletionService', () => {
  let service: AccountDeletionService;
  let stravaAuth: { revokeToken: ReturnType<typeof vi.fn> };
  const calls: string[] = [];

  beforeEach(async () => {
    vi.clearAllMocks();
    calls.length = 0;
    stravaAuth = {
      revokeToken: vi.fn(async () => {
        calls.push('revoke');
      }),
    };
    mockPrisma.$transaction.mockImplementation(async (ops: unknown[]) => {
      calls.push('transaction');
      return Promise.all(ops as Promise<unknown>[]);
    });
    mockPrisma.food.findMany.mockResolvedValue([{ id: 'food_1' }]);
    mockPrisma.exercise.findMany.mockResolvedValue([{ id: 'ex_1' }, { id: 'ex_2' }]);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AccountDeletionService,
        { provide: ConfigService, useValue: { get: vi.fn(() => 'postgresql://test') } },
        { provide: StravaAuthService, useValue: stravaAuth },
      ],
    }).compile();

    service = module.get(AccountDeletionService);
  });

  it('revokes Strava first, then deletes the user plus the custom foods and exercises it created', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce({
      passwordHash: 'hashed:senha12345',
      stravaAccount: { refreshToken: 'refresh_abc' },
    });

    await service.deleteAccount(USER_ID, 'senha12345');

    expect(stravaAuth.revokeToken).toHaveBeenCalledWith('refresh_abc');
    expect(calls).toEqual(['revoke', 'transaction']);
    expect(mockPrisma.food.findMany).toHaveBeenCalledWith({
      where: { createdByUserId: USER_ID, source: 'CUSTOM' },
      select: { id: true },
    });
    expect(mockPrisma.exercise.findMany).toHaveBeenCalledWith({
      where: { createdByUserId: USER_ID, source: 'USER' },
      select: { id: true },
    });
    expect(mockPrisma.user.delete).toHaveBeenCalledWith({ where: { id: USER_ID } });
    expect(mockPrisma.food.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: ['food_1'] } },
    });
    expect(mockPrisma.exercise.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: ['ex_1', 'ex_2'] } },
    });
  });

  it('skips the revoke when there is no Strava connection', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce({
      passwordHash: 'hashed:senha12345',
      stravaAccount: null,
    });

    await service.deleteAccount(USER_ID, 'senha12345');

    expect(stravaAuth.revokeToken).not.toHaveBeenCalled();
    expect(mockPrisma.user.delete).toHaveBeenCalled();
  });

  it('throws ForbiddenException (not 401) on a wrong password and deletes nothing', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce({
      passwordHash: 'hashed:senha12345',
      stravaAccount: { refreshToken: 'refresh_abc' },
    });

    await expect(service.deleteAccount(USER_ID, 'errada')).rejects.toThrow(
      ForbiddenException,
    );
    expect(stravaAuth.revokeToken).not.toHaveBeenCalled();
    expect(mockPrisma.$transaction).not.toHaveBeenCalled();
  });

  it('throws BadRequestException for an account with no password', async () => {
    mockPrisma.user.findUnique.mockResolvedValueOnce({
      passwordHash: null,
      stravaAccount: { refreshToken: 'refresh_abc' },
    });

    await expect(service.deleteAccount(USER_ID, 'qualquer')).rejects.toThrow(
      BadRequestException,
    );
    expect(mockPrisma.$transaction).not.toHaveBeenCalled();
  });
});

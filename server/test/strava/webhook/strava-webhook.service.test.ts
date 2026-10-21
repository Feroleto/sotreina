import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { StravaWebhookService } from 'src/strava/webhook/strava-webhook.service';
import { StravaClientService } from 'src/strava/client/strava-client.service';

const { mockPrisma, mockPurge } = vi.hoisted(() => {
  return {
    mockPrisma: {
      stravaAccount: {
        findUnique: vi.fn(),
      },
      activity: {
        deleteMany: vi.fn(),
        updateMany: vi.fn(),
      },
    },
    mockPurge: vi.fn(),
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

vi.mock('src/strava/strava-data-purge', () => ({ purgeStravaData: mockPurge }));

const ATHLETE_ID = 105494700n;
const USER_ID = 'user_1';

describe('StravaWebhookService', () => {
  let service: StravaWebhookService;
  let stravaClient: { isAuthorizationValid: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    vi.clearAllMocks();
    mockPurge.mockResolvedValue({ accountDeleted: false });
    stravaClient = { isAuthorizationValid: vi.fn().mockResolvedValue(false) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        StravaWebhookService,
        { provide: ConfigService, useValue: { get: vi.fn(() => 'postgresql://test') } },
        { provide: StravaClientService, useValue: stravaClient },
      ],
    }).compile();

    service = module.get(StravaWebhookService);
  });

  describe('handleDeauthorization', () => {
    it('purges all Strava data of the user once Strava confirms the revocation', async () => {
      mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce({ userId: USER_ID });

      await service.handleDeauthorization(ATHLETE_ID);

      expect(mockPrisma.stravaAccount.findUnique).toHaveBeenCalledWith({
        where: { stravaAthleteId: ATHLETE_ID },
        select: { userId: true },
      });
      expect(stravaClient.isAuthorizationValid).toHaveBeenCalledWith(USER_ID);
      expect(mockPurge).toHaveBeenCalledWith(mockPrisma, USER_ID);
    });

    it('ignores a forged event when Strava still accepts our token', async () => {
      mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce({ userId: USER_ID });
      stravaClient.isAuthorizationValid.mockResolvedValueOnce(true);

      await service.handleDeauthorization(ATHLETE_ID);

      expect(mockPurge).not.toHaveBeenCalled();
    });

    it('purges anyway when Strava cannot confirm either way', async () => {
      mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce({ userId: USER_ID });
      stravaClient.isAuthorizationValid.mockResolvedValueOnce(null);

      await service.handleDeauthorization(ATHLETE_ID);

      expect(mockPurge).toHaveBeenCalledWith(mockPrisma, USER_ID);
    });

    it('does nothing when no matching account is found (already disconnected)', async () => {
      mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce(null);

      await expect(service.handleDeauthorization(999n)).resolves.toBeUndefined();
      expect(stravaClient.isAuthorizationValid).not.toHaveBeenCalled();
      expect(mockPurge).not.toHaveBeenCalled();
    });
  });

  describe('activity events', () => {
    const ownerScope = { user: { stravaAccount: { stravaAthleteId: ATHLETE_ID } } };

    it('deletes the activity only within the owner athlete scope', async () => {
      mockPrisma.activity.deleteMany.mockResolvedValueOnce({ count: 1 });

      await service.handleActivityDeleted(12345n, ATHLETE_ID);

      expect(mockPrisma.activity.deleteMany).toHaveBeenCalledWith({
        where: { stravaId: 12345n, ...ownerScope },
      });
    });

    it('mirrors title and type changes', async () => {
      await service.handleActivityUpdated(12345n, ATHLETE_ID, { title: 'Long run', type: 'Run' });

      expect(mockPrisma.activity.updateMany).toHaveBeenCalledWith({
        where: { stravaId: 12345n, ...ownerScope },
        data: { name: 'Long run', type: 'Run' },
      });
    });

    it('skips updates that touch nothing we store (e.g. privacy)', async () => {
      await service.handleActivityUpdated(12345n, ATHLETE_ID, { private: 'true' } as any);

      expect(mockPrisma.activity.updateMany).not.toHaveBeenCalled();
    });
  });
});

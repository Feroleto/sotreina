import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { StravaClientService } from 'src/strava/client/strava-client.service';

const { mockPrisma } = vi.hoisted(() => {
  return {
    mockPrisma: {
      stravaAccount: {
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
const WINDOW_MS = 15 * 60 * 1000;

function stravaResponse(
  body: unknown,
  rateHeaders: Record<string, string> = {},
  status = 200,
) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: new Headers(rateHeaders),
    json: async () => body,
  };
}

describe('StravaClientService', () => {
  let service: StravaClientService;
  let fetchMock: ReturnType<typeof vi.fn>;
  let sleepSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(async () => {
    vi.clearAllMocks();

    mockPrisma.stravaAccount.findUniqueOrThrow.mockResolvedValue({
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: new Date(Date.now() + 3_600_000),
    });

    fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        StravaClientService,
        {
          provide: ConfigService,
          useValue: {
            get: vi.fn((key: string) => {
              if (key === 'DATABASE_URL') return 'postgresql://test';
              return undefined;
            }),
          },
        },
      ],
    }).compile();

    service = module.get<StravaClientService>(StravaClientService);
    sleepSpy = vi
      .spyOn(service as any, 'sleep')
      .mockResolvedValue(undefined) as any;
  });

  describe('adaptive throttle', () => {
    it('does not wait while the 15-min budget has slack', async () => {
      fetchMock.mockResolvedValue(
        stravaResponse(
          { id: 1 },
          {
            'x-ratelimit-limit': '200,2000',
            'x-ratelimit-usage': '50,300',
          },
        ),
      );

      await service.get(USER_ID, '/activities/1');
      await service.get(USER_ID, '/activities/2');

      expect(fetchMock).toHaveBeenCalledTimes(2);
      expect(sleepSpy).not.toHaveBeenCalled();
    });

    it('waits for the next quarter-hour window when the 15-min budget is nearly spent', async () => {
      fetchMock.mockResolvedValue(
        stravaResponse(
          { id: 1 },
          {
            'x-ratelimit-limit': '200,2000',
            'x-ratelimit-usage': '197,300',
          },
        ),
      );

      await service.get(USER_ID, '/activities/1');
      expect(sleepSpy).not.toHaveBeenCalled();

      await service.get(USER_ID, '/activities/2');

      expect(sleepSpy).toHaveBeenCalledTimes(1);
      const waitMs = sleepSpy.mock.calls[0][0] as number;
      // remainder of the current 15-min window plus a small buffer
      expect(waitMs).toBeGreaterThan(0);
      expect(waitMs).toBeLessThanOrEqual(WINDOW_MS + 5_000);
      expect(fetchMock).toHaveBeenCalledTimes(2);
    });

    it('throttles on the read limit even with overall budget left', async () => {
      fetchMock.mockResolvedValue(
        stravaResponse(
          { id: 1 },
          {
            'x-ratelimit-limit': '200,2000',
            'x-ratelimit-usage': '99,300',
            'x-readratelimit-limit': '100,1000',
            'x-readratelimit-usage': '99,300',
          },
        ),
      );

      await service.get(USER_ID, '/activities/1');
      await service.get(USER_ID, '/activities/2');

      expect(sleepSpy).toHaveBeenCalledTimes(1);
    });

    it('does not wait when the snapshot is from a previous window (budget already reset)', async () => {
      fetchMock.mockResolvedValue(stravaResponse({ id: 1 }));
      (service as any).rateLimit = {
        shortLimit: 200,
        shortUsage: 200,
        dailyLimit: 2000,
        dailyUsage: 300,
        readShortLimit: null,
        readShortUsage: null,
        readDailyLimit: null,
        readDailyUsage: null,
        windowId: Math.floor(Date.now() / WINDOW_MS) - 1,
      };

      await service.get(USER_ID, '/activities/1');

      expect(sleepSpy).not.toHaveBeenCalled();
      expect(fetchMock).toHaveBeenCalledTimes(1);
    });

    it('throws STRAVA_RATE_LIMIT without calling the API when the daily budget is exhausted', async () => {
      fetchMock.mockResolvedValue(stravaResponse({ id: 1 }));
      (service as any).rateLimit = {
        shortLimit: 200,
        shortUsage: 10,
        dailyLimit: 2000,
        dailyUsage: 1998,
        readShortLimit: null,
        readShortUsage: null,
        readDailyLimit: null,
        readDailyUsage: null,
        windowId: Math.floor(Date.now() / WINDOW_MS),
      };

      await expect(service.get(USER_ID, '/activities/1')).rejects.toThrow(
        'STRAVA_RATE_LIMIT',
      );
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('still surfaces a real 429 as STRAVA_RATE_LIMIT', async () => {
      fetchMock.mockResolvedValue(stravaResponse(null, {}, 429));

      await expect(service.get(USER_ID, '/activities/1')).rejects.toThrow(
        'STRAVA_RATE_LIMIT',
      );
    });

    it('exposes the window-reset timestamp via getWaitUntil while sleeping, then clears it', async () => {
      fetchMock.mockResolvedValue(
        stravaResponse(
          { id: 1 },
          {
            'x-ratelimit-limit': '200,2000',
            'x-ratelimit-usage': '197,300',
          },
        ),
      );
      await service.get(USER_ID, '/activities/1');
      expect(service.getWaitUntil()).toBeNull();

      // hold the sleep open so we can observe getWaitUntil() mid-wait
      let releaseSleep: () => void = () => {};
      sleepSpy.mockImplementationOnce(
        () => new Promise<void>((resolve) => (releaseSleep = resolve)),
      );

      const before = Date.now();
      const pending = service.get(USER_ID, '/activities/2');

      await vi.waitFor(() => expect(service.getWaitUntil()).not.toBeNull());
      expect(service.getWaitUntil()!).toBeGreaterThan(before);

      releaseSleep();
      await pending;

      expect(service.getWaitUntil()).toBeNull();
    });
  });

  describe('estimateEtaSeconds', () => {
    it('returns 0 for no remaining requests', () => {
      expect(service.estimateEtaSeconds(0)).toBe(0);
    });

    it('scales linearly while the requests fit in the current window budget', () => {
      const eta = service.estimateEtaSeconds(10);
      expect(eta).toBeGreaterThan(0);
      expect(eta).toBeLessThan(60);
    });

    it('accounts for window waits when the requests exceed the budget', async () => {
      fetchMock.mockResolvedValue(
        stravaResponse(
          { id: 1 },
          {
            'x-ratelimit-limit': '200,2000',
            'x-ratelimit-usage': '195,300',
          },
        ),
      );
      await service.get(USER_ID, '/activities/1');

      // 400 requests with no budget left this window: at least one full
      // window wait is unavoidable
      const eta = service.estimateEtaSeconds(400);
      expect(eta).toBeGreaterThan(WINDOW_MS / 1000);
    });
  });

  describe('isAuthorizationValid', () => {
    it('is true when Strava accepts the token', async () => {
      fetchMock.mockResolvedValueOnce(stravaResponse({ id: 1 }));
      await expect(service.isAuthorizationValid(USER_ID)).resolves.toBe(true);
    });

    it('is false when Strava answers 401 (access revoked)', async () => {
      fetchMock.mockResolvedValueOnce(stravaResponse({}, {}, 401));
      await expect(service.isAuthorizationValid(USER_ID)).resolves.toBe(false);
    });

    it('is false when refreshing an expired token is rejected', async () => {
      mockPrisma.stravaAccount.findUniqueOrThrow.mockResolvedValueOnce({
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: new Date(Date.now() - 1000),
      });
      fetchMock.mockResolvedValueOnce(stravaResponse({}, {}, 400));
      await expect(service.isAuthorizationValid(USER_ID)).resolves.toBe(false);
    });

    it('is null (unknown) on a server error or network failure', async () => {
      fetchMock.mockResolvedValueOnce(stravaResponse({}, {}, 503));
      await expect(service.isAuthorizationValid(USER_ID)).resolves.toBeNull();
      fetchMock.mockRejectedValueOnce(new Error('network down'));
      await expect(service.isAuthorizationValid(USER_ID)).resolves.toBeNull();
    });
  });
});

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { StravaAccountConflictError, StravaAuthService } from 'src/strava/auth/strava-auth.service';
import { EmailService } from 'src/email/email.service';

const { mockPrisma, mockPurge } = vi.hoisted(() => {
  return {
    mockPurge: vi.fn(),
    mockPrisma: {
      stravaAccount: {
        findUnique: vi.fn(),
        update: vi.fn(),
        create: vi.fn(),
        deleteMany: vi.fn(),
      },
      user: {
        create: vi.fn(),
        update: vi.fn(),
      },
      $transaction: vi.fn(),
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

vi.mock('src/strava/strava-data-purge', () => ({ purgeStravaData: mockPurge }));

const ATHLETE_ID = 105494700n;
const EXISTING_USER_ID = 'user_existing';
const OTHER_USER_ID = 'user_other';

function tokenExchangeResponse() {
  return {
    ok: true,
    json: async () => ({
      access_token: 'access-token',
      refresh_token: 'refresh-token',
      expires_at: 1_700_000_000,
      athlete: { id: Number(ATHLETE_ID), firstname: 'Guilherme', profile: 'https://x/avatar.jpg' },
    }),
  };
}

describe('StravaAuthService.handleCallback', () => {
  let service: StravaAuthService;
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    vi.clearAllMocks();
    fetchMock = vi.fn().mockResolvedValue(tokenExchangeResponse());
    vi.stubGlobal('fetch', fetchMock);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        StravaAuthService,
        { provide: ConfigService, useValue: { get: vi.fn(() => 'test-value') } },
        { provide: EmailService, useValue: { sendWelcomeEmail: vi.fn() } },
      ],
    }).compile();

    service = module.get(StravaAuthService);
  });

  it('creates a new User+StravaAccount when nothing exists and there is no existingUserId (plain login)', async () => {
    mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce(null);
    mockPrisma.user.create.mockResolvedValueOnce({ id: 'user_new', tokenVersion: 0 });

    const result = await service.handleCallback('code', null);

    expect(mockPrisma.user.create).toHaveBeenCalled();
    expect(mockPrisma.stravaAccount.create).not.toHaveBeenCalled();
    expect(result).toEqual({ userId: 'user_new', tokenVersion: 0 });
  });

  it('creates only a StravaAccount (no new User) when nothing exists and existingUserId is present (connect)', async () => {
    mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce(null);
    mockPrisma.stravaAccount.create.mockResolvedValueOnce({
      user: { tokenVersion: 3 },
    });

    const result = await service.handleCallback('code', EXISTING_USER_ID);

    expect(mockPrisma.user.create).not.toHaveBeenCalled();
    expect(mockPrisma.stravaAccount.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ userId: EXISTING_USER_ID, stravaAthleteId: ATHLETE_ID }),
      select: { user: { select: { tokenVersion: true } } },
    });
    expect(result).toEqual({ userId: EXISTING_USER_ID, tokenVersion: 3 });
  });

  it('refreshes tokens when the account already belongs to the same existingUserId (reconnect)', async () => {
    mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce({
      userId: EXISTING_USER_ID,
      stravaAthleteId: ATHLETE_ID,
    });
    mockPrisma.$transaction.mockResolvedValueOnce([
      {},
      { tokenVersion: 5 },
    ]);

    const result = await service.handleCallback('code', EXISTING_USER_ID);

    expect(mockPrisma.stravaAccount.create).not.toHaveBeenCalled();
    expect(result).toEqual({ userId: EXISTING_USER_ID, tokenVersion: 5 });
  });

  it('refreshes tokens the same way for a plain login into an already-linked account', async () => {
    mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce({
      userId: EXISTING_USER_ID,
      stravaAthleteId: ATHLETE_ID,
    });
    mockPrisma.$transaction.mockResolvedValueOnce([{}, { tokenVersion: 5 }]);

    const result = await service.handleCallback('code', null);

    expect(result).toEqual({ userId: EXISTING_USER_ID, tokenVersion: 5 });
  });

  it('throws StravaAccountConflictError when the account belongs to a different user, without writing anything', async () => {
    mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce({
      userId: OTHER_USER_ID,
      stravaAthleteId: ATHLETE_ID,
    });

    await expect(service.handleCallback('code', EXISTING_USER_ID)).rejects.toThrow(
      StravaAccountConflictError,
    );
    expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    expect(mockPrisma.stravaAccount.create).not.toHaveBeenCalled();
  });
});

describe('StravaAuthService.disconnectAccount', () => {
  let service: StravaAuthService;
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    vi.clearAllMocks();
    fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 200 });
    vi.stubGlobal('fetch', fetchMock);
    mockPurge.mockResolvedValue({ accountDeleted: false });

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        StravaAuthService,
        { provide: ConfigService, useValue: { get: vi.fn((key: string) => key) } },
        { provide: EmailService, useValue: { sendWelcomeEmail: vi.fn() } },
      ],
    }).compile();

    service = module.get(StravaAuthService);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('revokes the refresh token on Strava, then purges the Strava data', async () => {
    mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce({ refreshToken: 'refresh-token' });

    const result = await service.disconnectAccount(EXISTING_USER_ID);

    expect(result).toEqual({ accountDeleted: false });
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe('https://www.strava.com/oauth/revoke');
    expect(init.method).toBe('POST');
    expect(init.headers.Authorization).toBe(
      `Basic ${Buffer.from('STRAVA_CLIENT_ID:STRAVA_CLIENT_SECRET').toString('base64')}`,
    );
    expect(new URLSearchParams(init.body).get('token')).toBe('refresh-token');
    expect(mockPurge).toHaveBeenCalledWith(mockPrisma, EXISTING_USER_ID);
  });

  it('still purges locally when the revoke call fails', async () => {
    mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce({ refreshToken: 'refresh-token' });
    fetchMock.mockRejectedValueOnce(new Error('network down'));
    mockPurge.mockResolvedValueOnce({ accountDeleted: true });

    const result = await service.disconnectAccount(EXISTING_USER_ID);

    expect(result).toEqual({ accountDeleted: true });
    expect(mockPurge).toHaveBeenCalledWith(mockPrisma, EXISTING_USER_ID);
  });

  it('is a no-op when there is no Strava account to disconnect', async () => {
    mockPrisma.stravaAccount.findUnique.mockResolvedValueOnce(null);

    await expect(service.disconnectAccount(EXISTING_USER_ID)).resolves.toEqual({
      accountDeleted: false,
    });
    expect(fetchMock).not.toHaveBeenCalled();
    expect(mockPurge).not.toHaveBeenCalled();
  });
});

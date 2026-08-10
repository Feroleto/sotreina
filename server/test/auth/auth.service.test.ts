import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { AuthService } from 'src/auth/auth.service';
import { EmailService } from 'src/email/email.service';

const { mockPrisma } = vi.hoisted(() => {
  return {
    mockPrisma: {
      user: {
        findUnique: vi.fn(),
        update: vi.fn(),
        create: vi.fn(),
      },
      passwordResetToken: {
        create: vi.fn(),
        findUnique: vi.fn(),
        update: vi.fn(),
      },
      $transaction: vi.fn((ops: unknown[]) =>
        Promise.all(ops as Promise<unknown>[]),
      ),
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

vi.mock('src/auth/password', () => ({
  hashPassword: vi.fn(async (plain: string) => `hashed:${plain}`),
  verifyPassword: vi.fn(
    async (hash: string, plain: string) => hash === `hashed:${plain}`,
  ),
}));

const USER_ID = 'user_test_123';

describe('AuthService', () => {
  let service: AuthService;
  let emailService: {
    sendWelcomeEmail: ReturnType<typeof vi.fn>;
    sendPasswordResetEmail: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    vi.clearAllMocks();
    emailService = {
      sendWelcomeEmail: vi.fn(),
      sendPasswordResetEmail: vi.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: ConfigService,
          useValue: { get: vi.fn(() => 'postgresql://test') },
        },
        { provide: EmailService, useValue: emailService },
      ],
    }).compile();

    service = module.get(AuthService);
  });

  describe('authenticate', () => {
    it('returns null without touching Prisma when there is no session', async () => {
      const result = await service.authenticate(null);

      expect(result).toBeNull();
      expect(mockPrisma.user.findUnique).not.toHaveBeenCalled();
    });

    it('returns the MeResponse (without tokenVersion) when the version matches', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: USER_ID,
        firstName: 'Guilherme',
        profileImgUrl: 'https://example.com/avatar.jpg',
        maxHr: 185,
        tokenVersion: 2,
        passwordHash: null,
        stravaAccount: null,
      });

      const result = await service.authenticate({
        userId: USER_ID,
        tokenVersion: 2,
      });

      expect(result).toEqual({
        id: USER_ID,
        firstName: 'Guilherme',
        profileImgUrl: 'https://example.com/avatar.jpg',
        maxHr: 185,
        hasStravaAccount: false,
        hasPassword: false,
      });
      expect(result).not.toHaveProperty('tokenVersion');
      expect(result).not.toHaveProperty('stravaAccount');
      expect(result).not.toHaveProperty('passwordHash');
      expect(result).not.toHaveProperty('email');
    });

    it('reports hasStravaAccount: true when the relation is present, without leaking it', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: USER_ID,
        firstName: 'Guilherme',
        profileImgUrl: null,
        maxHr: null,
        tokenVersion: 0,
        passwordHash: null,
        stravaAccount: { id: 'strava_acc_1' },
      });

      const result = await service.authenticate({
        userId: USER_ID,
        tokenVersion: 0,
      });

      expect(result?.hasStravaAccount).toBe(true);
      expect(result).not.toHaveProperty('stravaAccount');
    });

    it('reports hasPassword: true when passwordHash is set, without leaking it', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: USER_ID,
        firstName: 'Guilherme',
        profileImgUrl: null,
        maxHr: null,
        tokenVersion: 0,
        passwordHash: 'hashed:password123',
        stravaAccount: null,
      });

      const result = await service.authenticate({
        userId: USER_ID,
        tokenVersion: 0,
      });

      expect(result?.hasPassword).toBe(true);
      expect(result).not.toHaveProperty('passwordHash');
    });

    it('returns null when the tokenVersion no longer matches (e.g. logged out elsewhere)', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: USER_ID,
        firstName: 'Guilherme',
        profileImgUrl: null,
        maxHr: null,
        tokenVersion: 3,
        passwordHash: null,
        stravaAccount: null,
      });

      const result = await service.authenticate({
        userId: USER_ID,
        tokenVersion: 2,
      });

      expect(result).toBeNull();
    });

    it('returns null when the user no longer exists', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);

      const result = await service.authenticate({
        userId: USER_ID,
        tokenVersion: 0,
      });

      expect(result).toBeNull();
    });
  });

  describe('invalidateSessions', () => {
    it('increments the tokenVersion for the given user', async () => {
      mockPrisma.user.update.mockResolvedValueOnce({});

      await service.invalidateSessions(USER_ID);

      expect(mockPrisma.user.update).toHaveBeenCalledWith({
        where: { id: USER_ID },
        data: { tokenVersion: { increment: 1 } },
      });
    });
  });

  describe('register', () => {
    it('creates a user with a hashed password and returns userId/tokenVersion', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);
      mockPrisma.user.create.mockResolvedValueOnce({
        id: USER_ID,
        email: 'test@example.com',
        firstName: 'Test',
        tokenVersion: 0,
      });

      const result = await service.register({
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Test',
      });

      expect(mockPrisma.user.create).toHaveBeenCalledWith({
        data: {
          email: 'test@example.com',
          passwordHash: 'hashed:password123',
          firstName: 'Test',
        },
      });
      expect(result).toEqual({ userId: USER_ID, tokenVersion: 0 });
      expect(emailService.sendWelcomeEmail).toHaveBeenCalledWith(
        'test@example.com',
        'Test',
      );
    });

    it('defaults firstName to null when not provided', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);
      mockPrisma.user.create.mockResolvedValueOnce({
        id: USER_ID,
        tokenVersion: 0,
      });

      await service.register({
        email: 'test@example.com',
        password: 'password123',
      });

      expect(mockPrisma.user.create).toHaveBeenCalledWith({
        data: {
          email: 'test@example.com',
          passwordHash: 'hashed:password123',
          firstName: null,
        },
      });
    });

    it('throws ConflictException when the email is already in use', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({ id: USER_ID });

      await expect(
        service.register({
          email: 'test@example.com',
          password: 'password123',
        }),
      ).rejects.toThrow(ConflictException);
      expect(mockPrisma.user.create).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('returns userId/tokenVersion for valid credentials', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: USER_ID,
        tokenVersion: 1,
        passwordHash: 'hashed:password123',
      });

      const result = await service.login({
        email: 'test@example.com',
        password: 'password123',
      });

      expect(result).toEqual({ userId: USER_ID, tokenVersion: 1 });
    });

    it('returns null for an unknown email', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);

      const result = await service.login({
        email: 'nobody@example.com',
        password: 'password123',
      });

      expect(result).toBeNull();
    });

    it('returns null for a Strava-only account with no password set', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: USER_ID,
        tokenVersion: 0,
        passwordHash: null,
      });

      const result = await service.login({
        email: 'test@example.com',
        password: 'password123',
      });

      expect(result).toBeNull();
    });

    it('returns null for the wrong password', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: USER_ID,
        tokenVersion: 0,
        passwordHash: 'hashed:password123',
      });

      const result = await service.login({
        email: 'test@example.com',
        password: 'wrong',
      });

      expect(result).toBeNull();
    });
  });

  describe('setPassword', () => {
    it('sets email + hashed password on a Strava-only account with no password yet', async () => {
      mockPrisma.user.findUnique
        .mockResolvedValueOnce({ passwordHash: null }) // load target user
        .mockResolvedValueOnce(null); // email uniqueness check
      mockPrisma.user.update.mockResolvedValueOnce({});

      await service.setPassword(USER_ID, {
        email: 'test@example.com',
        password: 'password123',
      });

      expect(mockPrisma.user.update).toHaveBeenCalledWith({
        where: { id: USER_ID },
        data: { email: 'test@example.com', passwordHash: 'hashed:password123' },
      });
    });

    it('throws ConflictException when the account already has a password', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        passwordHash: 'hashed:existing',
      });

      await expect(
        service.setPassword(USER_ID, {
          email: 'test@example.com',
          password: 'password123',
        }),
      ).rejects.toThrow(ConflictException);
      expect(mockPrisma.user.update).not.toHaveBeenCalled();
    });

    it('throws ConflictException when the email belongs to another user', async () => {
      mockPrisma.user.findUnique
        .mockResolvedValueOnce({ passwordHash: null })
        .mockResolvedValueOnce({ id: 'someone_else' });

      await expect(
        service.setPassword(USER_ID, {
          email: 'test@example.com',
          password: 'password123',
        }),
      ).rejects.toThrow(ConflictException);
      expect(mockPrisma.user.update).not.toHaveBeenCalled();
    });

    it('allows re-submitting the same email already on the account', async () => {
      mockPrisma.user.findUnique
        .mockResolvedValueOnce({ passwordHash: null })
        .mockResolvedValueOnce({ id: USER_ID });
      mockPrisma.user.update.mockResolvedValueOnce({});

      await service.setPassword(USER_ID, {
        email: 'test@example.com',
        password: 'password123',
      });

      expect(mockPrisma.user.update).toHaveBeenCalled();
    });
  });

  describe('requestPasswordReset', () => {
    it('creates a token and emails a reset link whose token hashes to the stored value', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: USER_ID,
        email: 'test@example.com',
        passwordHash: 'hashed:existing',
      });
      mockPrisma.passwordResetToken.create.mockResolvedValueOnce({});

      await service.requestPasswordReset('test@example.com');

      expect(mockPrisma.passwordResetToken.create).toHaveBeenCalledTimes(1);
      const createArgs = mockPrisma.passwordResetToken.create.mock.calls[0][0];
      expect(createArgs.data.userId).toBe(USER_ID);
      expect(createArgs.data.expiresAt).toBeInstanceOf(Date);
      expect(createArgs.data.expiresAt.getTime()).toBeGreaterThan(Date.now());

      expect(emailService.sendPasswordResetEmail).toHaveBeenCalledTimes(1);
      const [to, resetUrl] = emailService.sendPasswordResetEmail.mock.calls[0];
      expect(to).toBe('test@example.com');
      expect(resetUrl).toContain('/redefinir-senha?token=');

      const rawToken = new URL(resetUrl).searchParams.get('token')!;
      const { createHash } = await import('node:crypto');
      const expectedHash = createHash('sha256').update(rawToken).digest('hex');
      expect(createArgs.data.tokenHash).toBe(expectedHash);
    });

    it('does nothing for an unknown email (no token, no email sent)', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce(null);

      await service.requestPasswordReset('nobody@example.com');

      expect(mockPrisma.passwordResetToken.create).not.toHaveBeenCalled();
      expect(emailService.sendPasswordResetEmail).not.toHaveBeenCalled();
    });

    it('does nothing for a Strava-only account with no password set', async () => {
      mockPrisma.user.findUnique.mockResolvedValueOnce({
        id: USER_ID,
        email: 'test@example.com',
        passwordHash: null,
      });

      await service.requestPasswordReset('test@example.com');

      expect(mockPrisma.passwordResetToken.create).not.toHaveBeenCalled();
      expect(emailService.sendPasswordResetEmail).not.toHaveBeenCalled();
    });
  });

  describe('resetPassword', () => {
    it('updates the password, increments tokenVersion, and marks the token used', async () => {
      const { createHash } = await import('node:crypto');
      const rawToken = 'raw-token-value';
      const tokenHash = createHash('sha256').update(rawToken).digest('hex');

      mockPrisma.passwordResetToken.findUnique.mockResolvedValueOnce({
        id: 'reset_1',
        userId: USER_ID,
        tokenHash,
        usedAt: null,
        expiresAt: new Date(Date.now() + 60_000),
      });
      mockPrisma.user.update.mockResolvedValueOnce({});
      mockPrisma.passwordResetToken.update.mockResolvedValueOnce({});

      await service.resetPassword(rawToken, 'newpassword123');

      expect(mockPrisma.user.update).toHaveBeenCalledWith({
        where: { id: USER_ID },
        data: {
          passwordHash: 'hashed:newpassword123',
          tokenVersion: { increment: 1 },
        },
      });
      expect(mockPrisma.passwordResetToken.update).toHaveBeenCalledWith({
        where: { id: 'reset_1' },
        data: { usedAt: expect.any(Date) },
      });
    });

    it('throws BadRequestException for an unknown token', async () => {
      mockPrisma.passwordResetToken.findUnique.mockResolvedValueOnce(null);

      await expect(
        service.resetPassword('unknown-token', 'newpassword123'),
      ).rejects.toThrow(BadRequestException);
      expect(mockPrisma.user.update).not.toHaveBeenCalled();
    });

    it('throws BadRequestException for an expired token', async () => {
      mockPrisma.passwordResetToken.findUnique.mockResolvedValueOnce({
        id: 'reset_1',
        userId: USER_ID,
        tokenHash: 'irrelevant',
        usedAt: null,
        expiresAt: new Date(Date.now() - 1_000),
      });

      await expect(
        service.resetPassword('expired-token', 'newpassword123'),
      ).rejects.toThrow(BadRequestException);
      expect(mockPrisma.user.update).not.toHaveBeenCalled();
    });

    it('throws BadRequestException for an already-used token', async () => {
      mockPrisma.passwordResetToken.findUnique.mockResolvedValueOnce({
        id: 'reset_1',
        userId: USER_ID,
        tokenHash: 'irrelevant',
        usedAt: new Date(),
        expiresAt: new Date(Date.now() + 60_000),
      });

      await expect(
        service.resetPassword('used-token', 'newpassword123'),
      ).rejects.toThrow(BadRequestException);
      expect(mockPrisma.user.update).not.toHaveBeenCalled();
    });
  });
});

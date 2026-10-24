import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ConflictException,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthController } from 'src/auth/auth.controller';
import { AuthService } from 'src/auth/auth.service';
import { SessionService } from 'src/auth/session.service';

const USER_ID = 'user_test_123';

describe('AuthController', () => {
  let controller: AuthController;
  let session: {
    extractSession: ReturnType<typeof vi.fn>;
    clearCookie: ReturnType<typeof vi.fn>;
    setCookie: ReturnType<typeof vi.fn>;
    signToken: ReturnType<typeof vi.fn>;
  };
  let authService: {
    authenticate: ReturnType<typeof vi.fn>;
    invalidateSessions: ReturnType<typeof vi.fn>;
    register: ReturnType<typeof vi.fn>;
    login: ReturnType<typeof vi.fn>;
    setPassword: ReturnType<typeof vi.fn>;
    requestPasswordReset: ReturnType<typeof vi.fn>;
    resetPassword: ReturnType<typeof vi.fn>;
    sendVerificationCode: ReturnType<typeof vi.fn>;
    verifyEmail: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    session = {
      extractSession: vi.fn(),
      clearCookie: vi.fn(),
      setCookie: vi.fn(),
      signToken: vi.fn().mockReturnValue('signed-jwt'),
    };
    authService = {
      authenticate: vi.fn(),
      invalidateSessions: vi.fn().mockResolvedValue(undefined),
      register: vi.fn(),
      login: vi.fn(),
      setPassword: vi.fn(),
      requestPasswordReset: vi.fn().mockResolvedValue(undefined),
      resetPassword: vi.fn().mockResolvedValue(undefined),
      sendVerificationCode: vi.fn().mockResolvedValue(undefined),
      verifyEmail: vi.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        { provide: SessionService, useValue: session },
        { provide: AuthService, useValue: authService },
      ],
    }).compile();

    controller = module.get(AuthController);
  });

  describe('me', () => {
    it('forwards the extracted session into authenticate and returns its result', async () => {
      const extractedSession = { userId: USER_ID, tokenVersion: 1 };
      session.extractSession.mockReturnValue(extractedSession);
      authService.authenticate.mockResolvedValue({ id: USER_ID });

      const req: any = { cookies: { session: 'valid-token' } };
      const result = await controller.me(req);

      expect(authService.authenticate).toHaveBeenCalledWith(extractedSession);
      expect(result).toEqual({ id: USER_ID });
    });

    it('returns null for a visitor with no session, without treating it as an error', async () => {
      session.extractSession.mockReturnValue(null);
      authService.authenticate.mockResolvedValue(null);

      const req: any = { cookies: {} };
      const result = await controller.me(req);

      expect(result).toBeNull();
    });
  });

  describe('logout', () => {
    it('invalidates the session and clears the cookie when a session cookie is present', async () => {
      session.extractSession.mockReturnValue({
        userId: USER_ID,
        tokenVersion: 0,
      });
      const req: any = { cookies: { session: 'valid-token' } };
      const res: any = {};

      await controller.logout(req, res);

      expect(authService.invalidateSessions).toHaveBeenCalledWith(USER_ID);
      expect(session.clearCookie).toHaveBeenCalledWith(res);
    });

    it('skips invalidation but still clears the cookie when there is no session', async () => {
      session.extractSession.mockReturnValue(null);
      const req: any = { cookies: {} };
      const res: any = {};

      await controller.logout(req, res);

      expect(authService.invalidateSessions).not.toHaveBeenCalled();
      expect(session.clearCookie).toHaveBeenCalledWith(res);
    });

    it('still clears the cookie even when invalidateSessions rejects', async () => {
      session.extractSession.mockReturnValue({
        userId: USER_ID,
        tokenVersion: 0,
      });
      authService.invalidateSessions.mockRejectedValue(new Error('db down'));
      const req: any = { cookies: { session: 'valid-token' } };
      const res: any = {};

      await expect(controller.logout(req, res)).rejects.toThrow('db down');
      expect(session.clearCookie).toHaveBeenCalledWith(res);
    });
  });

  describe('register', () => {
    it('sets the session cookie and returns the MeResponse', async () => {
      authService.register.mockResolvedValue({
        userId: USER_ID,
        tokenVersion: 0,
      });
      authService.authenticate.mockResolvedValue({
        id: USER_ID,
        hasStravaAccount: false,
      });
      const res: any = {};

      const result = await controller.register(
        { email: 'test@example.com', password: 'password123' },
        res,
      );

      expect(session.setCookie).toHaveBeenCalledWith(res, USER_ID, 0);
      expect(result).toEqual({ id: USER_ID, hasStravaAccount: false });
    });

    it('propagates ConflictException from authService.register', async () => {
      authService.register.mockRejectedValue(
        new ConflictException('Email already in use'),
      );
      const res: any = {};

      await expect(
        controller.register(
          { email: 'test@example.com', password: 'password123' },
          res,
        ),
      ).rejects.toThrow(ConflictException);
      expect(session.setCookie).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('sets the session cookie and returns the MeResponse on valid credentials', async () => {
      authService.login.mockResolvedValue({ userId: USER_ID, tokenVersion: 1 });
      authService.authenticate.mockResolvedValue({
        id: USER_ID,
        hasStravaAccount: true,
      });
      const res: any = {};

      const result = await controller.login(
        { email: 'test@example.com', password: 'password123' },
        res,
      );

      expect(session.setCookie).toHaveBeenCalledWith(res, USER_ID, 1);
      expect(result).toEqual({ id: USER_ID, hasStravaAccount: true });
    });

    it('throws UnauthorizedException when authService.login resolves null', async () => {
      authService.login.mockResolvedValue(null);
      const res: any = {};

      await expect(
        controller.login({ email: 'test@example.com', password: 'wrong' }, res),
      ).rejects.toThrow(UnauthorizedException);
      expect(session.setCookie).not.toHaveBeenCalled();
    });
  });

  describe('token', () => {
    it('returns the signed JWT plus the MeResponse in the body, without setting a cookie', async () => {
      authService.login.mockResolvedValue({ userId: USER_ID, tokenVersion: 2 });
      authService.authenticate.mockResolvedValue({ id: USER_ID, hasPassword: true });

      const result = await controller.token({
        email: 'test@example.com',
        password: 'password123',
      });

      expect(session.signToken).toHaveBeenCalledWith(USER_ID, 2);
      expect(session.setCookie).not.toHaveBeenCalled();
      expect(result).toEqual({
        token: 'signed-jwt',
        user: { id: USER_ID, hasPassword: true },
      });
    });

    it('throws UnauthorizedException on bad credentials, signing nothing', async () => {
      authService.login.mockResolvedValue(null);

      await expect(
        controller.token({ email: 'test@example.com', password: 'wrong' }),
      ).rejects.toThrow(UnauthorizedException);
      expect(session.signToken).not.toHaveBeenCalled();
    });

    it('rejects a malformed body before touching the auth service', async () => {
      await expect(controller.token({ email: 'nope' })).rejects.toThrow(BadRequestException);
      expect(authService.login).not.toHaveBeenCalled();
    });
  });

  describe('setPassword', () => {
    it('forwards the session userId + parsed body and returns the refreshed MeResponse', async () => {
      const extractedSession = { userId: USER_ID, tokenVersion: 0 };
      session.extractSession.mockReturnValue(extractedSession);
      authService.setPassword.mockResolvedValue(undefined);
      authService.authenticate.mockResolvedValue({
        id: USER_ID,
        hasStravaAccount: true,
        hasPassword: true,
      });

      const req: any = { cookies: { session: 'valid-token' } };
      const result = await controller.setPassword(req, {
        email: 'test@example.com',
        password: 'password123',
      });

      expect(authService.setPassword).toHaveBeenCalledWith(USER_ID, {
        email: 'test@example.com',
        password: 'password123',
      });
      expect(authService.authenticate).toHaveBeenCalledWith(extractedSession);
      expect(result).toEqual({
        id: USER_ID,
        hasStravaAccount: true,
        hasPassword: true,
      });
    });

    it('propagates ConflictException from authService.setPassword', async () => {
      session.extractSession.mockReturnValue({
        userId: USER_ID,
        tokenVersion: 0,
      });
      authService.setPassword.mockRejectedValue(
        new ConflictException('Password already set'),
      );

      const req: any = { cookies: { session: 'valid-token' } };
      await expect(
        controller.setPassword(req, {
          email: 'test@example.com',
          password: 'password123',
        }),
      ).rejects.toThrow(ConflictException);
      expect(authService.authenticate).not.toHaveBeenCalled();
    });
  });

  describe('forgotPassword', () => {
    it('parses the body, calls requestPasswordReset, and always returns ok', async () => {
      const result = await controller.forgotPassword({
        email: 'test@example.com',
      });

      expect(authService.requestPasswordReset).toHaveBeenCalledWith(
        'test@example.com',
      );
      expect(result).toEqual({ ok: true });
    });

    it('returns the same ok response even though nothing in the service call distinguishes the outcome', async () => {
      // requestPasswordReset resolves the same way whether or not the email
      // exists — this asserts the controller doesn't try to branch on it
      const result = await controller.forgotPassword({
        email: 'nobody@example.com',
      });

      expect(result).toEqual({ ok: true });
    });

    it('rejects a malformed body before calling the service', async () => {
      await expect(
        controller.forgotPassword({ email: 'not-an-email' }),
      ).rejects.toThrow(BadRequestException);
      expect(authService.requestPasswordReset).not.toHaveBeenCalled();
    });
  });

  describe('resetPassword', () => {
    it('parses the body, calls resetPassword, and returns ok', async () => {
      const result = await controller.resetPassword({
        token: 'abc123',
        newPassword: 'newpassword123',
      });

      expect(authService.resetPassword).toHaveBeenCalledWith(
        'abc123',
        'newpassword123',
      );
      expect(result).toEqual({ ok: true });
    });

    it('propagates BadRequestException from authService.resetPassword (invalid/expired token)', async () => {
      authService.resetPassword.mockRejectedValue(
        new BadRequestException('Invalid or expired token'),
      );

      await expect(
        controller.resetPassword({
          token: 'stale',
          newPassword: 'newpassword123',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a malformed body before calling the service', async () => {
      await expect(
        controller.resetPassword({ token: '', newPassword: 'newpassword123' }),
      ).rejects.toThrow(BadRequestException);
      expect(authService.resetPassword).not.toHaveBeenCalled();
    });
  });

  describe('registerToken', () => {
    it('returns the signed JWT plus the MeResponse in the body, without setting a cookie', async () => {
      authService.register.mockResolvedValue({
        userId: USER_ID,
        tokenVersion: 0,
      });
      authService.authenticate.mockResolvedValue({ id: USER_ID });

      const result = await controller.registerToken({
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Ana',
      });

      expect(authService.register).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123',
        firstName: 'Ana',
      });
      expect(session.signToken).toHaveBeenCalledWith(USER_ID, 0);
      expect(session.setCookie).not.toHaveBeenCalled();
      expect(result).toEqual({ token: 'signed-jwt', user: { id: USER_ID } });
    });

    it('propagates ConflictException, signing nothing', async () => {
      authService.register.mockRejectedValue(
        new ConflictException('Email already in use'),
      );

      await expect(
        controller.registerToken({
          email: 'test@example.com',
          password: 'password123',
        }),
      ).rejects.toThrow(ConflictException);
      expect(session.signToken).not.toHaveBeenCalled();
    });
  });

  describe('sendEmailCode', () => {
    it('sends a code for the session user', async () => {
      session.extractSession.mockReturnValue({
        userId: USER_ID,
        tokenVersion: 0,
      });

      const result = await controller.sendEmailCode({} as any);

      expect(authService.sendVerificationCode).toHaveBeenCalledWith(USER_ID);
      expect(result).toEqual({ ok: true });
    });
  });

  describe('verifyEmail', () => {
    it('verifies the parsed code and returns the refreshed MeResponse', async () => {
      const extractedSession = { userId: USER_ID, tokenVersion: 0 };
      session.extractSession.mockReturnValue(extractedSession);
      authService.authenticate.mockResolvedValue({
        id: USER_ID,
        emailVerified: true,
      });

      const result = await controller.verifyEmail({} as any, {
        code: ' 012345 ',
      });

      expect(authService.verifyEmail).toHaveBeenCalledWith(USER_ID, '012345');
      expect(authService.authenticate).toHaveBeenCalledWith(extractedSession);
      expect(result).toEqual({ id: USER_ID, emailVerified: true });
    });

    it('rejects a malformed code before calling the service', async () => {
      session.extractSession.mockReturnValue({
        userId: USER_ID,
        tokenVersion: 0,
      });

      await expect(
        controller.verifyEmail({} as any, { code: '12345' }),
      ).rejects.toThrow(BadRequestException);
      expect(authService.verifyEmail).not.toHaveBeenCalled();
    });
  });
});

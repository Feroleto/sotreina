import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { StravaConnectController } from 'src/strava/auth/strava-connect.controller';
import { StravaAuthService } from 'src/strava/auth/strava-auth.service';
import { SessionService } from 'src/auth/session.service';
import { AuthGuard } from 'src/auth/auth.guard';
import { AccountThrottlerGuard } from 'src/auth/account-throttler.guard';

// AuthGuard's own behavior is covered by test/auth/auth.guard.test.ts —
// overridden here to a pass-through since this file is only exercising the
// controller's handlers directly, not Nest's guard pipeline

const STATE = 'a'.repeat(64);
const USER_ID = 'user_1';

describe('StravaConnectController', () => {
  let controller: StravaConnectController;
  let stravaAuth: { buildAuthUrl: ReturnType<typeof vi.fn>; disconnectAccount: ReturnType<typeof vi.fn> };
  let session: {
    setOauthState: ReturnType<typeof vi.fn>;
    clearCookie: ReturnType<typeof vi.fn>;
    extractSession: ReturnType<typeof vi.fn>;
    signConnectState: ReturnType<typeof vi.fn>;
  };
  let res: { redirect: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    stravaAuth = {
      buildAuthUrl: vi.fn().mockReturnValue('https://www.strava.com/oauth/authorize?state=' + STATE),
      disconnectAccount: vi.fn().mockResolvedValue({ accountDeleted: false }),
    };
    session = {
      setOauthState: vi.fn().mockReturnValue(STATE),
      clearCookie: vi.fn(),
      extractSession: vi.fn().mockReturnValue({ userId: USER_ID, tokenVersion: 3 }),
      signConnectState: vi.fn().mockReturnValue('signed.connect.state'),
    };
    res = { redirect: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [StravaConnectController],
      providers: [
        { provide: StravaAuthService, useValue: stravaAuth },
        { provide: SessionService, useValue: session },
      ],
    })
      .overrideGuard(AuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(AccountThrottlerGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get(StravaConnectController);
  });

  describe('connect', () => {
    it('sets the anti-CSRF state cookie and redirects to Strava with that same state', () => {
      controller.connect(res as any);

      expect(session.setOauthState).toHaveBeenCalled();
      expect(stravaAuth.buildAuthUrl).toHaveBeenCalledWith(STATE);
      expect(res.redirect).toHaveBeenCalledWith(expect.stringContaining('strava.com'));
    });
  });

  describe('start (iOS app)', () => {
    it('returns the Strava authorize URL with a connect state for the caller and their tokenVersion', () => {
      const req = { headers: { authorization: 'Bearer x' } };

      const result = controller.start(req as any);

      expect(session.signConnectState).toHaveBeenCalledWith(USER_ID, 3);
      expect(stravaAuth.buildAuthUrl).toHaveBeenCalledWith('signed.connect.state');
      expect(result).toEqual({ url: 'https://www.strava.com/oauth/authorize?state=' + STATE });
      expect(session.setOauthState).not.toHaveBeenCalled();
    });
  });

  describe('disconnect', () => {
    it('disconnects the Strava account for the current user and keeps the session', async () => {
      const result = await controller.disconnect({ id: USER_ID }, res as any);

      expect(stravaAuth.disconnectAccount).toHaveBeenCalledWith(USER_ID);
      expect(result).toEqual({ accountDeleted: false });
      expect(session.clearCookie).not.toHaveBeenCalled();
    });

    it('clears the session cookie when the Strava-only account was deleted', async () => {
      stravaAuth.disconnectAccount.mockResolvedValueOnce({ accountDeleted: true });

      const result = await controller.disconnect({ id: USER_ID }, res as any);

      expect(result).toEqual({ accountDeleted: true });
      expect(session.clearCookie).toHaveBeenCalledWith(res);
    });
  });
});

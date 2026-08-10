import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { StravaConnectController } from 'src/strava/auth/strava-connect.controller';
import { StravaAuthService } from 'src/strava/auth/strava-auth.service';
import { SessionService } from 'src/auth/session.service';
import { AuthGuard } from 'src/auth/auth.guard';

// AuthGuard's own behavior is covered by test/auth/auth.guard.test.ts —
// overridden here to a pass-through since this file is only exercising the
// controller's handlers directly, not Nest's guard pipeline

const STATE = 'a'.repeat(64);
const USER_ID = 'user_1';

describe('StravaConnectController', () => {
  let controller: StravaConnectController;
  let stravaAuth: { buildAuthUrl: ReturnType<typeof vi.fn>; disconnectAccount: ReturnType<typeof vi.fn> };
  let session: { setOauthState: ReturnType<typeof vi.fn> };
  let res: { redirect: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    stravaAuth = {
      buildAuthUrl: vi.fn().mockReturnValue('https://www.strava.com/oauth/authorize?state=' + STATE),
      disconnectAccount: vi.fn().mockResolvedValue(undefined),
    };
    session = { setOauthState: vi.fn().mockReturnValue(STATE) };
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

  describe('disconnect', () => {
    it('disconnects the Strava account for the current user', async () => {
      await controller.disconnect({ id: USER_ID });

      expect(stravaAuth.disconnectAccount).toHaveBeenCalledWith(USER_ID);
    });
  });
});

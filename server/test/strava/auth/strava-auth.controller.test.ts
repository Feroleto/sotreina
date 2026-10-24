import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { StravaAuthController } from 'src/strava/auth/strava-auth.controller';
import { StravaAccountConflictError, StravaAuthService } from 'src/strava/auth/strava-auth.service';
import { SessionService } from 'src/auth/session.service';
import { AuthService } from 'src/auth/auth.service';
import { StravaSyncService } from 'src/strava/sync/strava-sync.service';

const FRONTEND_URL = 'http://localhost:5173';
const STATE = 'a'.repeat(64);
const USER_ID = 'user_1';
// any JWT-shaped state goes down the app branch; validity is the mock's call
const APP_STATE = 'header.payload.signature';
const APP_RETURN = 'sotreina://strava/connected';

describe('StravaAuthController', () => {
  let controller: StravaAuthController;
  let authService: {
    buildAuthUrl: ReturnType<typeof vi.fn>;
    handleCallback: ReturnType<typeof vi.fn>;
  };
  let session: {
    setOauthState: ReturnType<typeof vi.fn>;
    consumeOauthState: ReturnType<typeof vi.fn>;
    setCookie: ReturnType<typeof vi.fn>;
    extractSession: ReturnType<typeof vi.fn>;
    verifyConnectState: ReturnType<typeof vi.fn>;
  };
  let sync: { sync: ReturnType<typeof vi.fn> };
  let auth: { authenticate: ReturnType<typeof vi.fn> };
  let res: { redirect: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    authService = {
      buildAuthUrl: vi.fn().mockReturnValue('https://www.strava.com/oauth/authorize?state=' + STATE),
      handleCallback: vi.fn().mockResolvedValue({ userId: USER_ID, tokenVersion: 0 }),
    };
    session = {
      setOauthState: vi.fn().mockReturnValue(STATE),
      consumeOauthState: vi.fn().mockReturnValue(STATE),
      setCookie: vi.fn(),
      extractSession: vi.fn().mockReturnValue(null),
      verifyConnectState: vi.fn().mockReturnValue(null),
    };
    sync = { sync: vi.fn().mockResolvedValue({ synced: 0, errors: 0, rateLimited: false }) };
    auth = { authenticate: vi.fn().mockResolvedValue(null) };
    res = { redirect: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [StravaAuthController],
      providers: [
        { provide: StravaAuthService, useValue: authService },
        { provide: SessionService, useValue: session },
        { provide: AuthService, useValue: auth },
        { provide: StravaSyncService, useValue: sync },
        {
          provide: ConfigService,
          useValue: { get: vi.fn().mockReturnValue(FRONTEND_URL) },
        },
      ],
    }).compile();

    controller = module.get(StravaAuthController);
  });

  describe('authorize', () => {
    it('sets the anti-CSRF state cookie and redirects to Strava with that same state', () => {
      controller.authorize(res as any);

      expect(session.setOauthState).toHaveBeenCalled();
      expect(authService.buildAuthUrl).toHaveBeenCalledWith(STATE);
      expect(res.redirect).toHaveBeenCalledWith(expect.stringContaining('strava.com'));
    });
  });

  describe('callback', () => {
    const req = { cookies: {} };

    it('completes the login when the state matches the cookie and there is no session', async () => {
      await controller.callback('the-code', STATE, req as any, res as any);

      expect(authService.handleCallback).toHaveBeenCalledWith('the-code', null);
      expect(session.setCookie).toHaveBeenCalledWith(res, USER_ID, 0);
      expect(res.redirect).toHaveBeenCalledWith(FRONTEND_URL);
    });

    it('passes the existing userId through as a connect flow when a valid session is present', async () => {
      session.extractSession.mockReturnValue({ userId: USER_ID, tokenVersion: 1 });
      auth.authenticate.mockResolvedValue({ id: USER_ID, hasStravaAccount: false });

      await controller.callback('the-code', STATE, req as any, res as any);

      expect(auth.authenticate).toHaveBeenCalledWith({ userId: USER_ID, tokenVersion: 1 });
      expect(authService.handleCallback).toHaveBeenCalledWith('the-code', USER_ID);
    });

    it('treats a stale/invalidated session cookie as anonymous, not as a connect flow', async () => {
      // extractSession succeeds (signature is valid) but authenticate()
      // rejects it (tokenVersion no longer matches, e.g. logged out
      // elsewhere) — this must NOT be treated as a logged-in connect flow
      session.extractSession.mockReturnValue({ userId: USER_ID, tokenVersion: 0 });
      auth.authenticate.mockResolvedValue(null);

      await controller.callback('the-code', STATE, req as any, res as any);

      expect(authService.handleCallback).toHaveBeenCalledWith('the-code', null);
    });

    it('redirects with a distinct error when the Strava account is linked to a different user', async () => {
      authService.handleCallback.mockRejectedValue(
        new StravaAccountConflictError('already linked'),
      );

      await controller.callback('the-code', STATE, req as any, res as any);

      expect(res.redirect).toHaveBeenCalledWith(`${FRONTEND_URL}/?auth_error=strava_conflict`);
    });

    it('rejects a callback whose state does not match the cookie (login CSRF)', async () => {
      await controller.callback('the-code', 'b'.repeat(64), req as any, res as any);

      expect(authService.handleCallback).not.toHaveBeenCalled();
      expect(session.setCookie).not.toHaveBeenCalled();
      expect(res.redirect).toHaveBeenCalledWith(`${FRONTEND_URL}/?auth_error=1`);
    });

    it('rejects a callback with no state cookie (direct/forged callback URL)', async () => {
      session.consumeOauthState.mockReturnValue(null);

      await controller.callback('the-code', STATE, req as any, res as any);

      expect(authService.handleCallback).not.toHaveBeenCalled();
      expect(res.redirect).toHaveBeenCalledWith(`${FRONTEND_URL}/?auth_error=1`);
    });

    it('rejects a callback with an empty state param', async () => {
      await controller.callback('the-code', '' as any, req as any, res as any);

      expect(authService.handleCallback).not.toHaveBeenCalled();
      expect(res.redirect).toHaveBeenCalledWith(`${FRONTEND_URL}/?auth_error=1`);
    });

    describe('from the iOS app (signed connect state)', () => {
      beforeEach(() => {
        session.verifyConnectState.mockReturnValue({ userId: USER_ID, tokenVersion: 2 });
        auth.authenticate.mockResolvedValue({ id: USER_ID, hasStravaAccount: false });
      });

      it('links the account to the state\'s user, starts the sync and returns to the app', async () => {
        await controller.callback('the-code', APP_STATE, req as any, res as any);

        expect(session.verifyConnectState).toHaveBeenCalledWith(APP_STATE);
        expect(auth.authenticate).toHaveBeenCalledWith({ userId: USER_ID, tokenVersion: 2 });
        expect(authService.handleCallback).toHaveBeenCalledWith('the-code', USER_ID);
        expect(sync.sync).toHaveBeenCalledWith(USER_ID);
        expect(session.setCookie).not.toHaveBeenCalled();
        expect(res.redirect).toHaveBeenCalledWith(`${APP_RETURN}?status=ok`);
      });

      // bad signature, expired, other purpose: verifyConnectState says null
      it('returns error to the app without linking when the state does not verify', async () => {
        session.verifyConnectState.mockReturnValue(null);

        await controller.callback('the-code', APP_STATE, req as any, res as any);

        expect(authService.handleCallback).not.toHaveBeenCalled();
        expect(sync.sync).not.toHaveBeenCalled();
        expect(res.redirect).toHaveBeenCalledWith(`${APP_RETURN}?status=error`);
      });

      it('returns error without linking when the state\'s tokenVersion is stale (logged out since)', async () => {
        auth.authenticate.mockResolvedValue(null);

        await controller.callback('the-code', APP_STATE, req as any, res as any);

        expect(authService.handleCallback).not.toHaveBeenCalled();
        expect(res.redirect).toHaveBeenCalledWith(`${APP_RETURN}?status=error`);
      });

      it('returns conflict when the Strava account is linked to another user', async () => {
        authService.handleCallback.mockRejectedValue(new StravaAccountConflictError('already linked'));

        await controller.callback('the-code', APP_STATE, req as any, res as any);

        expect(sync.sync).not.toHaveBeenCalled();
        expect(res.redirect).toHaveBeenCalledWith(`${APP_RETURN}?status=conflict`);
      });

      it('returns error when the token exchange fails', async () => {
        authService.handleCallback.mockRejectedValue(new Error('exchange failed'));

        await controller.callback('the-code', APP_STATE, req as any, res as any);

        expect(res.redirect).toHaveBeenCalledWith(`${APP_RETURN}?status=error`);
      });

      // denying on Strava's screen comes back with error=access_denied, no code
      it('returns error without calling Strava when there is no code', async () => {
        await controller.callback(undefined as any, APP_STATE, req as any, res as any);

        expect(authService.handleCallback).not.toHaveBeenCalled();
        expect(res.redirect).toHaveBeenCalledWith(`${APP_RETURN}?status=error`);
      });
    });

    it('still redirects with auth_error when the token exchange itself fails', async () => {
      authService.handleCallback.mockRejectedValue(new Error('exchange failed'));

      await controller.callback('the-code', STATE, req as any, res as any);

      expect(res.redirect).toHaveBeenCalledWith(`${FRONTEND_URL}/?auth_error=1`);
    });
  });
});

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { SessionService } from 'src/auth/session.service';

const USER_ID = 'user_test_123';
const TOKEN_VERSION = 1;
const SECRET = 'test-secret';

function makeConfig(nodeEnv?: string) {
  return {
    get: vi.fn((key: string) => {
      if (key === 'NODE_ENV') return nodeEnv;
      return undefined;
    }),
  };
}

async function makeService(nodeEnv?: string): Promise<SessionService> {
  const module: TestingModule = await Test.createTestingModule({
    imports: [JwtModule.register({ secret: SECRET })],
    providers: [SessionService, { provide: ConfigService, useValue: makeConfig(nodeEnv) }],
  }).compile();

  return module.get(SessionService);
}

describe('SessionService', () => {
  let res: { cookie: ReturnType<typeof vi.fn>; clearCookie: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    res = { cookie: vi.fn(), clearCookie: vi.fn() };
  });

  describe('setCookie / extractSession round trip', () => {
    it('extracts the same userId and tokenVersion that were signed into the cookie', async () => {
      const service = await makeService('development');
      service.setCookie(res as any, USER_ID, TOKEN_VERSION);

      const [, token] = res.cookie.mock.calls[0];
      const req = { cookies: { session: token } };

      expect(service.extractSession(req as any)).toEqual({
        userId: USER_ID,
        tokenVersion: TOKEN_VERSION,
      });
    });
  });

  describe('extractSession', () => {
    it('returns null when there is no session cookie', async () => {
      const service = await makeService('development');
      expect(service.extractSession({ cookies: {} } as any)).toBeNull();
    });

    it('returns null for a garbage/tampered token', async () => {
      const service = await makeService('development');
      const req = { cookies: { session: 'not-a-real-jwt' } };
      expect(service.extractSession(req as any)).toBeNull();
    });

    it('returns tokenVersion undefined for a legacy token signed before the tv claim existed', async () => {
      const module: TestingModule = await Test.createTestingModule({
        imports: [JwtModule.register({ secret: SECRET })],
        providers: [
          SessionService,
          { provide: ConfigService, useValue: makeConfig('development') },
        ],
      }).compile();

      const service = module.get(SessionService);
      const jwt = module.get(JwtService);
      const legacyToken = jwt.sign({ sub: USER_ID });
      const req = { cookies: { session: legacyToken } };

      expect(service.extractSession(req as any)).toEqual({
        userId: USER_ID,
        tokenVersion: undefined,
      });
    });
  });

  describe('Bearer header', () => {
    it('extracts the session from an Authorization: Bearer header', async () => {
      const service = await makeService('development');
      const token = service.signToken(USER_ID, TOKEN_VERSION);
      const req = { headers: { authorization: `Bearer ${token}` }, cookies: {} };

      expect(service.extractSession(req as any)).toEqual({
        userId: USER_ID,
        tokenVersion: TOKEN_VERSION,
      });
    });

    it('prefers the header over the cookie when both are present', async () => {
      const service = await makeService('development');
      const headerToken = service.signToken('header_user', 3);
      const cookieToken = service.signToken('cookie_user', 1);
      const req = {
        headers: { authorization: `Bearer ${headerToken}` },
        cookies: { session: cookieToken },
      };

      expect(service.extractSession(req as any)).toEqual({
        userId: 'header_user',
        tokenVersion: 3,
      });
    });

    it('does not fall back to the cookie when the header is present but invalid', async () => {
      const service = await makeService('development');
      const cookieToken = service.signToken(USER_ID, TOKEN_VERSION);

      for (const authorization of ['Bearer not-a-jwt', 'Basic abc', 'Bearer', '']) {
        const req = { headers: { authorization }, cookies: { session: cookieToken } };
        expect(service.extractSession(req as any)).toBeNull();
      }
    });
  });

  describe('cookie flags by environment', () => {
    it('uses secure + sameSite=lax in production (Vercel proxies /api/* to Render, so it stays same-site)', async () => {
      const service = await makeService('production');
      service.setCookie(res as any, USER_ID, TOKEN_VERSION);

      const [, , options] = res.cookie.mock.calls[0];
      expect(options).toMatchObject({ httpOnly: true, secure: true, sameSite: 'lax' });
    });

    it('uses non-secure + sameSite=lax in dev (localhost, different ports but same site)', async () => {
      const service = await makeService('development');
      service.setCookie(res as any, USER_ID, TOKEN_VERSION);

      const [, , options] = res.cookie.mock.calls[0];
      expect(options).toMatchObject({ httpOnly: true, secure: false, sameSite: 'lax' });
    });
  });

  describe('OAuth state cookie', () => {
    it('sets a random hex state as a short-lived httpOnly cookie and returns it', async () => {
      const service = await makeService('development');
      const state = service.setOauthState(res as any);

      expect(state).toMatch(/^[0-9a-f]{64}$/);
      const [name, value, options] = res.cookie.mock.calls[0];
      expect(name).toBe('oauth_state');
      expect(value).toBe(state);
      expect(options).toMatchObject({ httpOnly: true, sameSite: 'lax' });
      expect(options.maxAge).toBeLessThanOrEqual(10 * 60 * 1000);
    });

    it('generates a different state on every call', async () => {
      const service = await makeService('development');
      expect(service.setOauthState(res as any)).not.toBe(service.setOauthState(res as any));
    });

    it('consumeOauthState returns the cookie value and always clears the cookie', async () => {
      const service = await makeService('development');
      const req = { cookies: { oauth_state: 'abc123' } };

      expect(service.consumeOauthState(req as any, res as any)).toBe('abc123');
      expect(res.clearCookie).toHaveBeenCalledWith('oauth_state', expect.any(Object));
    });

    it('consumeOauthState returns null when no state cookie exists, still clearing', async () => {
      const service = await makeService('development');

      expect(service.consumeOauthState({ cookies: {} } as any, res as any)).toBeNull();
      expect(res.clearCookie).toHaveBeenCalledWith('oauth_state', expect.any(Object));
    });
  });

  describe('clearCookie', () => {
    it('clears the session cookie with matching flags', async () => {
      const service = await makeService('production');
      service.clearCookie(res as any);

      expect(res.clearCookie).toHaveBeenCalledWith(
        'session',
        expect.objectContaining({ httpOnly: true, secure: true, sameSite: 'lax' }),
      );
    });
  });
});

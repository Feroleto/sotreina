import { randomBytes } from 'crypto';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import type { Request, Response } from 'express';

const COOKIE_NAME = 'session';
// kept in sync with the JwtModule signOptions default (JWT_EXPIRES_IN) — cookie
// maxAge can't be derived from that string without pulling in a date-math lib
// for this one field, so both default to 30 days and must be changed together
const SESSION_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;

const OAUTH_STATE_COOKIE = 'oauth_state';
// long enough for the user to complete the Strava authorize screen, short
// enough that a stale state can't be replayed much later
const OAUTH_STATE_MAX_AGE_MS = 10 * 60 * 1000;

const CONNECT_STATE_PURPOSE = 'strava-connect';
const CONNECT_STATE_TTL_SEC = 10 * 60;

@Injectable()
export class SessionService {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  private get isProd(): boolean {
    return this.config.get<string>('NODE_ENV') === 'production';
  }

  private get cookieOptions() {
    // sameSite:'lax' works in both envs because the browser never talks to
    // the API cross-site: in prod, Vercel's rewrite (client/vercel.json)
    // proxies /api/* to Render server-side, so from the browser's point of
    // view every request (including the OAuth callback) stays on the
    // frontend's own origin; in dev, localhost:5173/:3000 are different
    // ports but the same site already. This also sidesteps Safari's default
    // third-party-cookie blocking, which drops sameSite:'none' cookies set
    // by a genuinely different domain (onrender.com) regardless of the
    // SameSite attribute — confirmed broken on iOS Safari, fine on Chrome
    return {
      httpOnly: true,
      secure: this.isProd,
      sameSite: 'lax' as const,
    };
  }

  // same JWT for both transports: the cookie (web) and the Bearer header
  // (native iOS app, see POST /auth/token) — so tokenVersion invalidation
  // and logout behave identically for both
  signToken(userId: string, tokenVersion: number): string {
    return this.jwt.sign({ sub: userId, tv: tokenVersion });
  }

  setCookie(res: Response, userId: string, tokenVersion: number): void {
    const token = this.signToken(userId, tokenVersion);
    res.cookie(COOKIE_NAME, token, {
      ...this.cookieOptions,
      maxAge: SESSION_MAX_AGE_MS,
    });
  }

  clearCookie(res: Response): void {
    res.clearCookie(COOKIE_NAME, this.cookieOptions);
  }

  // CSRF protection for the OAuth flow: the state travels both in the
  // authorize URL (echoed back by Strava on the callback) and in this cookie;
  // the callback only proceeds if the two match, so an attacker-supplied
  // callback URL (login CSRF) fails — the victim's browser has no matching
  // cookie. Rides the same first-party path as the session cookie (Vercel
  // proxy in prod), so sameSite:'lax' is sent on the top-level redirect back
  setOauthState(res: Response): string {
    const state = randomBytes(32).toString('hex');
    res.cookie(OAUTH_STATE_COOKIE, state, {
      ...this.cookieOptions,
      maxAge: OAUTH_STATE_MAX_AGE_MS,
    });
    return state;
  }

  // single-use: reading the state always clears the cookie, match or not
  consumeOauthState(req: Request, res: Response): string | null {
    const state: string | undefined = req.cookies?.[OAUTH_STATE_COOKIE];
    res.clearCookie(OAUTH_STATE_COOKIE, this.cookieOptions);
    return state ?? null;
  }

  // OAuth state for the iOS app's Strava connect (spec login-app-ios §5.2):
  // the app has no cookie to carry an oauth_state, so the state itself is a
  // short-lived signed JWT that binds the callback to the user who asked
  signConnectState(userId: string, tokenVersion: number): string {
    return this.jwt.sign(
      {
        sub: userId,
        tv: tokenVersion,
        purpose: CONNECT_STATE_PURPOSE,
        client: 'ios',
        nonce: randomBytes(16).toString('hex'),
      },
      { expiresIn: CONNECT_STATE_TTL_SEC },
    );
  }

  verifyConnectState(state: string): { userId: string; tokenVersion: number } | null {
    try {
      const payload = this.jwt.verify<{ sub: string; tv: number; purpose?: string; client?: string }>(state);
      if (payload.purpose !== CONNECT_STATE_PURPOSE || payload.client !== 'ios') return null;
      return { userId: payload.sub, tokenVersion: payload.tv };
    } catch {
      return null;
    }
  }

  // An Authorization header, when present, wins outright over the cookie —
  // a bad Bearer token is a failed session, never a fallback to whatever
  // cookie happens to ride along. A Bearer is never attached automatically
  // by a browser, so accepting it adds no CSRF surface
  extractSession(req: Request): { userId: string; tokenVersion: number } | null {
    const header = req.headers?.authorization;
    const token = header !== undefined ? parseBearer(header) : req.cookies?.[COOKIE_NAME];
    if (!token) return null;

    try {
      const payload = this.jwt.verify<{ sub: string; tv: number; purpose?: string }>(token);
      // a purpose-bound token (the connect state) is not a session, even
      // though it carries sub/tv under the same secret
      if (payload.purpose !== undefined) return null;
      return { userId: payload.sub, tokenVersion: payload.tv };
    } catch {
      return null;
    }
  }
}

function parseBearer(header: string): string | null {
  const match = /^Bearer\s+(\S+)$/i.exec(header.trim());
  return match ? match[1] : null;
}

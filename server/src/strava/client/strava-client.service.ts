import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

const STRAVA_TOKEN_URL = 'https://www.strava.com/oauth/token';
const STRAVA_API_BASE = 'https://www.strava.com/api/v3';

// Strava's short rate-limit windows are aligned to clock quarter-hours
// (…:00, :15, :30, :45) — usage counters reset at each boundary
const WINDOW_MS = 15 * 60 * 1000;
// requests kept in reserve below the reported limit, so a concurrent
// consumer (a manual backfill racing the cron batch, etc) doesn't
// immediately run the app into a 429
const SAFETY_MARGIN = 5;
// resume slightly past the boundary to absorb clock skew vs Strava's
const BOUNDARY_BUFFER_MS = 2000;
// rough per-request pace (network latency + the callers' courtesy sleeps),
// only used for ETA estimates
const SECONDS_PER_REQUEST = 1.5;
// assumed 15-min budget before the first response reveals the real limits
const DEFAULT_WINDOW_LIMIT = 200;

interface RateLimitSnapshot {
  // overall app limits/usage: [15-min window, daily]
  shortLimit: number;
  shortUsage: number;
  dailyLimit: number;
  dailyUsage: number;
  // read-only limits — every sync call is a GET, so when Strava sends these
  // they can be the binding constraint even with overall budget left
  readShortLimit: number | null;
  readShortUsage: number | null;
  readDailyLimit: number | null;
  readDailyUsage: number | null;
  // which 15-min window the snapshot was taken in; usage resets on rollover
  windowId: number;
}

function parsePair(header: string | null): [number, number] | null {
  if (!header) return null;
  const [a, b] = header.split(',').map((s) => Number.parseInt(s.trim(), 10));
  return Number.isFinite(a) && Number.isFinite(b) ? [a, b] : null;
}

@Injectable()
export class StravaClientService {
  private readonly logger = new Logger(StravaClientService.name);
  private readonly prisma: PrismaClient;
  // latest rate-limit headers seen from Strava; shared across all consumers
  // (sync + backfills) since the budget is app-wide
  private rateLimit: RateLimitSnapshot | null = null;
  // set while throttle() is sleeping out a spent 15-min window, so callers
  // (SyncProgress) can surface a "resumes at" countdown instead of looking stalled
  private waitUntil: number | null = null;

  constructor(private readonly config: ConfigService) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  async getValidAccessToken(userId: string): Promise<string> {
    const account = await this.prisma.stravaAccount.findUniqueOrThrow({
      where: { userId },
    });

    if (account.expiresAt > new Date()) {
      return account.accessToken;
    }

    this.logger.log(`Token expired for user ${userId}, refreshing...`);
    return this.refreshToken(userId, account.refreshToken);
  }

  async refreshToken(userId: string, refreshToken: string): Promise<string> {
    const response = await fetch(STRAVA_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: this.config.get('STRAVA_CLIENT_ID'),
        client_secret: this.config.get('STRAVA_CLIENT_SECRET'),
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
      }),
    });

    if (!response.ok) {
      throw new UnauthorizedException('Failed to refresh Strava token');
    }

    const data = await response.json();

    await this.prisma.stravaAccount.update({
      where: { userId },
      data: {
        accessToken: data.access_token,
        refreshToken: data.refresh_token,
        expiresAt: new Date(data.expires_at * 1000),
      },
    });

    this.logger.log(`Token refreshed for user ${userId}`);
    return data.access_token;
  }

  // asks Strava whether our stored grant for this user still works: false
  // when the refresh or the call itself is rejected as unauthorized (access
  // really revoked), true when it succeeds, null when Strava couldn't say
  // (network error, 5xx, 429). Used to check a deauthorization webhook event
  // before acting on it, since Strava doesn't sign those events
  async isAuthorizationValid(userId: string): Promise<boolean | null> {
    try {
      const token = await this.getValidAccessToken(userId);
      const response = await fetch(`${STRAVA_API_BASE}/athlete`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      this.captureRateLimit(response);
      if (response.ok) return true;
      if (response.status === 401) return false;
      return null;
    } catch (err) {
      return err instanceof UnauthorizedException ? false : null;
    }
  }

  async get<T>(userId: string, path: string, params?: Record<string, string | number>): Promise<T> {
    await this.throttle();

    const token = await this.getValidAccessToken(userId);

    const url = new URL(`${STRAVA_API_BASE}${path}`);
    if (params) {
      Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, String(v)));
    }

    const response = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${token}` },
    });

    this.captureRateLimit(response);

    if (response.status === 429) {
      throw new Error('STRAVA_RATE_LIMIT');
    }

    if (!response.ok) {
      throw new Error(`Strava API error: ${response.status} ${path}`);
    }

    return response.json() as Promise<T>;
  }

  // adaptive throttle: using the usage headers from previous responses, wait
  // for the next quarter-hour window instead of running into a 429 when the
  // 15-min budget is nearly spent. Daily exhaustion can't be waited out
  // mid-sync (the counter only resets at midnight UTC), so it surfaces as
  // the same STRAVA_RATE_LIMIT the callers already handle by aborting
  private async throttle(): Promise<void> {
    const rl = this.rateLimit;
    if (!rl) return;

    const dailyExhausted =
      rl.dailyUsage >= rl.dailyLimit - SAFETY_MARGIN ||
      (rl.readDailyLimit != null &&
        (rl.readDailyUsage ?? 0) >= rl.readDailyLimit - SAFETY_MARGIN);
    if (dailyExhausted) {
      this.logger.warn(
        `Daily Strava budget exhausted (${rl.dailyUsage}/${rl.dailyLimit} overall, ${rl.readDailyUsage ?? '—'}/${rl.readDailyLimit ?? '—'} read)`,
      );
      throw new Error('STRAVA_RATE_LIMIT');
    }

    const now = Date.now();
    // snapshot from a previous window — counters have reset, budget is fresh
    if (Math.floor(now / WINDOW_MS) !== rl.windowId) return;

    const shortExhausted =
      rl.shortUsage >= rl.shortLimit - SAFETY_MARGIN ||
      (rl.readShortLimit != null &&
        (rl.readShortUsage ?? 0) >= rl.readShortLimit - SAFETY_MARGIN);
    if (!shortExhausted) return;

    const waitMs = WINDOW_MS - (now % WINDOW_MS) + BOUNDARY_BUFFER_MS;
    this.logger.log(
      `15-min Strava budget nearly spent (${rl.shortUsage}/${rl.shortLimit} overall, ${rl.readShortUsage ?? '—'}/${rl.readShortLimit ?? '—'} read) — waiting ${Math.round(waitMs / 1000)}s for the next window`,
    );
    this.waitUntil = now + waitMs;
    try {
      await this.sleep(waitMs);
    } finally {
      this.waitUntil = null;
    }
  }

  // timestamp (ms epoch) the throttle is currently sleeping until, or null
  // when no window wait is in progress — used to drive a "resumes in…"
  // countdown on the frontend during a large initial import
  getWaitUntil(): number | null {
    return this.waitUntil;
  }

  private captureRateLimit(response: { headers: Headers }): void {
    const limit = parsePair(response.headers.get('x-ratelimit-limit'));
    const usage = parsePair(response.headers.get('x-ratelimit-usage'));
    if (!limit || !usage) return;
    const readLimit = parsePair(response.headers.get('x-readratelimit-limit'));
    const readUsage = parsePair(response.headers.get('x-readratelimit-usage'));

    this.rateLimit = {
      shortLimit: limit[0],
      dailyLimit: limit[1],
      shortUsage: usage[0],
      dailyUsage: usage[1],
      readShortLimit: readLimit?.[0] ?? null,
      readDailyLimit: readLimit?.[1] ?? null,
      readShortUsage: readUsage?.[0] ?? null,
      readDailyUsage: readUsage?.[1] ?? null,
      windowId: Math.floor(Date.now() / WINDOW_MS),
    };
  }

  // per-window request budget honoring the safety margin and, when present,
  // the read limit (the tighter of the two — sync traffic is all GETs)
  private windowBudget(): number {
    const rl = this.rateLimit;
    const limit =
      rl == null
        ? DEFAULT_WINDOW_LIMIT
        : Math.min(rl.shortLimit, rl.readShortLimit ?? Infinity);
    return Math.max(limit - SAFETY_MARGIN, 1);
  }

  // projects how long `requests` further calls will take given the current
  // window usage: whatever fits in the remaining budget runs at request
  // pace, the rest waits for as many window resets as needed
  estimateEtaSeconds(requests: number): number {
    if (requests <= 0) return 0;

    const budget = this.windowBudget();
    const now = Date.now();
    const rl = this.rateLimit;

    let available = budget;
    if (rl != null && Math.floor(now / WINDOW_MS) === rl.windowId) {
      const used = Math.max(rl.shortUsage, rl.readShortUsage ?? 0);
      available = Math.max(budget - used, 0);
    }

    if (requests <= available) {
      return Math.round(requests * SECONDS_PER_REQUEST);
    }

    const overflow = requests - available;
    // windows still to be waited for; the first wait is only the remainder
    // of the current window, the others are full 15 minutes
    const windowsToWait = Math.ceil(overflow / budget);
    const secondsToBoundary = (WINDOW_MS - (now % WINDOW_MS)) / 1000;
    const lastChunk = overflow - (windowsToWait - 1) * budget;

    return Math.round(
      available * SECONDS_PER_REQUEST +
        secondsToBoundary +
        (windowsToWait - 1) * (WINDOW_MS / 1000) +
        lastChunk * SECONDS_PER_REQUEST,
    );
  }

  private sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

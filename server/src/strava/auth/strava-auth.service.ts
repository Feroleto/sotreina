import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { EmailService } from '../../email/email.service';
import { purgeStravaData } from '../strava-data-purge';

const STRAVA_AUTH_URL = 'https://www.strava.com/oauth/authorize';
const STRAVA_TOKEN_URL = 'https://www.strava.com/oauth/token';
// replaces the legacy oauth/deauthorize, which stops working 2027-06-01
const STRAVA_REVOKE_URL = 'https://www.strava.com/oauth/revoke';

interface StravaTokenExchangeResponse {
  access_token: string;
  refresh_token: string;
  expires_at: number;
  athlete: {
    id: number;
    firstname: string | null;
    profile: string | null;
  };
}

// thrown when a logged-in user tries to connect a Strava account that's
// already linked to a different User — never silently steals the link
export class StravaAccountConflictError extends Error {}

@Injectable()
export class StravaAuthService {
  private readonly logger = new Logger(StravaAuthService.name);
  private readonly prisma: PrismaClient;

  constructor(
    private readonly config: ConfigService,
    private readonly emailService: EmailService,
  ) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  buildAuthUrl(state: string): string {
    const params = new URLSearchParams({
      client_id: this.config.get<string>('STRAVA_CLIENT_ID')!,
      response_type: 'code',
      redirect_uri: this.config.get<string>('STRAVA_REDIRECT_URI')!,
      approval_prompt: 'force',
      scope: 'read,activity:read_all,profile:read_all',
      state,
    });

    return `${STRAVA_AUTH_URL}?${params.toString()}`;
  }

  // exchanges the OAuth code for tokens, then either:
  //  - existingUserId is set (connect flow, called from an already-logged-in
  //    session): links the resulting StravaAccount to that user, or refreshes
  //    it if already linked to them, or rejects if linked to someone else
  //  - existingUserId is null (plain login flow, unchanged): finds or
  //    creates the User whose StravaAccount matches the returned athlete id
  async handleCallback(
    code: string,
    existingUserId: string | null = null,
  ): Promise<{ userId: string; tokenVersion: number }> {
    const response = await fetch(STRAVA_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: this.config.get('STRAVA_CLIENT_ID'),
        client_secret: this.config.get('STRAVA_CLIENT_SECRET'),
        code,
        grant_type: 'authorization_code',
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Strava token exchange failed: ${response.status} — ${body}`);
    }

    const data = (await response.json()) as StravaTokenExchangeResponse;
    const stravaAthleteId = BigInt(data.athlete.id);
    const tokenFields = {
      accessToken: data.access_token,
      refreshToken: data.refresh_token,
      expiresAt: new Date(data.expires_at * 1000),
    };

    const existing = await this.prisma.stravaAccount.findUnique({
      where: { stravaAthleteId },
    });

    if (existing) {
      if (existingUserId && existing.userId !== existingUserId) {
        throw new StravaAccountConflictError(
          `Strava athlete ${stravaAthleteId} is already linked to a different account`,
        );
      }

      const [, updatedUser] = await this.prisma.$transaction([
        this.prisma.stravaAccount.update({
          where: { stravaAthleteId },
          data: tokenFields,
        }),
        this.prisma.user.update({
          where: { id: existing.userId },
          data: {
            firstName: data.athlete.firstname,
            profileImgUrl: data.athlete.profile,
          },
        }),
      ]);

      this.logger.log(`Strava account reconnected for user ${existing.userId}`);
      return { userId: existing.userId, tokenVersion: updatedUser.tokenVersion };
    }

    if (existingUserId) {
      // connect flow: link to the already-logged-in user, don't create a
      // new User and don't overwrite the name/avatar they already have
      const created = await this.prisma.stravaAccount.create({
        data: { userId: existingUserId, stravaAthleteId, ...tokenFields },
        select: { user: { select: { tokenVersion: true } } },
      });

      this.logger.log(`Strava account linked to existing user ${existingUserId}`);
      return { userId: existingUserId, tokenVersion: created.user.tokenVersion };
    }

    const user = await this.prisma.user.create({
      data: {
        firstName: data.athlete.firstname,
        profileImgUrl: data.athlete.profile,
        stravaAccount: {
          create: { stravaAthleteId, ...tokenFields },
        },
      },
    });

    // guarded, not unconditional: Strava's OAuth payload never includes an
    // email address, so `user.email` is null here today and this is
    // effectively a no-op — kept for the day Strava (or some other
    // email-aware signup path) actually provides one
    if (user.email) {
      void this.emailService.sendWelcomeEmail(user.email, user.firstName);
    }

    this.logger.log(`New user created ${user.id} (athlete ${data.athlete.id})`);
    return { userId: user.id, tokenVersion: user.tokenVersion };
  }

  // revokes our grant on Strava's side, then deletes every piece of Strava
  // data we hold for the user (API Policy 7.4, see purgeStravaData). The
  // revoke is best-effort, like EmailService: a failure there is logged and
  // the local deletion still happens — it's the part the policy is about.
  // accountDeleted tells the caller a Strava-only user was removed entirely.
  // Idempotent — a no-op (not an error) when there's nothing to delete.
  async disconnectAccount(userId: string): Promise<{ accountDeleted: boolean }> {
    const account = await this.prisma.stravaAccount.findUnique({
      where: { userId },
      select: { refreshToken: true },
    });
    if (!account) return { accountDeleted: false };

    await this.revokeToken(account.refreshToken);
    const result = await purgeStravaData(this.prisma, userId);
    this.logger.log(
      `Strava account disconnected for user ${userId}${result.accountDeleted ? ' (Strava-only user deleted)' : ''}`,
    );
    return result;
  }

  private async revokeToken(refreshToken: string): Promise<void> {
    const credentials = Buffer.from(
      `${this.config.get('STRAVA_CLIENT_ID')}:${this.config.get('STRAVA_CLIENT_SECRET')}`,
    ).toString('base64');

    try {
      const response = await fetch(STRAVA_REVOKE_URL, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${credentials}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          token: refreshToken,
          token_type_hint: 'refresh_token',
        }).toString(),
      });
      if (!response.ok) {
        this.logger.warn(`Strava token revoke failed: ${response.status}`);
      }
    } catch (err) {
      this.logger.warn(`Strava token revoke failed: ${(err as Error).message}`);
    }
  }
}

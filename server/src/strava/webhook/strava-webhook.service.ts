import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { purgeStravaData } from '../strava-data-purge';
import { StravaClientService } from '../client/strava-client.service';

@Injectable()
export class StravaWebhookService {
  private readonly logger = new Logger(StravaWebhookService.name);
  private readonly prisma: PrismaClient;

  constructor(
    private readonly config: ConfigService,
    private readonly stravaClient: StravaClientService,
  ) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  // API Policy 7.4: revocation means deleting all of the athlete's Strava
  // Data, not just the tokens (see purgeStravaData). No call to Strava's
  // revoke endpoint here — the athlete already revoked on their side.
  //
  // Strava doesn't sign webhook events and subscription_id is guessable, so
  // a forged event alone must not wipe someone's data: we first ask Strava
  // whether our grant still works, and only a positive "yes, still valid"
  // stops the purge. An inconclusive answer (Strava down, rate limited)
  // purges anyway — failing toward the deletion the policy requires.
  async handleDeauthorization(stravaAthleteId: bigint): Promise<void> {
    const account = await this.prisma.stravaAccount.findUnique({
      where: { stravaAthleteId },
      select: { userId: true },
    });

    if (!account) {
      this.logger.warn(
        `Received deauthorization for athlete ${stravaAthleteId}, but no matching StravaAccount was found`,
      );
      return;
    }

    if ((await this.stravaClient.isAuthorizationValid(account.userId)) === true) {
      this.logger.warn(
        `Ignored deauthorization for athlete ${stravaAthleteId}: Strava still accepts our token (forged event?)`,
      );
      return;
    }

    const { accountDeleted } = await purgeStravaData(this.prisma, account.userId);
    this.logger.log(
      `Athlete ${stravaAthleteId} deauthorized — Strava data purged${accountDeleted ? ' (Strava-only user deleted)' : ''}`,
    );
  }

  // API Policy 6.3: an activity deleted on Strava must disappear here within
  // 48h. Scoped to the owner's own activities, so a forged event can't
  // delete an activity that belongs to a different athlete.
  async handleActivityDeleted(stravaId: bigint, ownerAthleteId: bigint): Promise<void> {
    const { count } = await this.prisma.activity.deleteMany({
      where: { stravaId, user: { stravaAccount: { stravaAthleteId: ownerAthleteId } } },
    });
    if (count > 0) this.logger.log(`Activity ${stravaId} deleted on Strava — removed`);
  }

  // title/type changes arrive in the event itself, no API call needed.
  // Other updates (e.g. privacy) don't affect anything we store.
  async handleActivityUpdated(
    stravaId: bigint,
    ownerAthleteId: bigint,
    updates: { title?: string; type?: string },
  ): Promise<void> {
    const data: { name?: string; type?: string } = {};
    if (typeof updates.title === 'string') data.name = updates.title;
    if (typeof updates.type === 'string') data.type = updates.type;
    if (Object.keys(data).length === 0) return;

    await this.prisma.activity.updateMany({
      where: { stravaId, user: { stravaAccount: { stravaAthleteId: ownerAthleteId } } },
      data,
    });
  }
}

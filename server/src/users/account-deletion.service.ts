import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { verifyPassword } from '../auth/password';
import { StravaAuthService } from '../strava/auth/strava-auth.service';

// DELETE /users/me (spec login-app-ios §3.5/§6; the App Store requires
// in-app deletion). Deleting the User row cascades to everything hung off it
// — Strava data included, so API Policy 7.4 holds without purgeStravaData.
// The exceptions are the custom foods and exercises the user created: their
// createdBy FK is SET NULL, so they'd survive as orphan rows nobody can see.
@Injectable()
export class AccountDeletionService {
  private readonly logger = new Logger(AccountDeletionService.name);
  private readonly prisma: PrismaClient;

  constructor(
    private readonly config: ConfigService,
    private readonly stravaAuth: StravaAuthService,
  ) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  // a wrong password is 403, not 401: the session is valid, only the
  // confirmation failed — and the iOS app reads any 401 as "session expired"
  // and signs out
  async deleteAccount(userId: string, password: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        passwordHash: true,
        stravaAccount: { select: { refreshToken: true } },
      },
    });
    if (!user?.passwordHash) {
      throw new BadRequestException('Account has no password');
    }
    if (!(await verifyPassword(user.passwordHash, password))) {
      throw new ForbiddenException('Invalid password');
    }

    // best-effort and outside the transaction (no network inside one)
    if (user.stravaAccount) {
      await this.stravaAuth.revokeToken(user.stravaAccount.refreshToken);
    }

    // ids first: once the user is gone, SET NULL erases who created them.
    // They can only be deleted after the user, whose own logs, workouts and
    // routines (cascaded) are what still reference them
    const [foods, exercises] = await Promise.all([
      this.prisma.food.findMany({
        where: { createdByUserId: userId, source: 'CUSTOM' },
        select: { id: true },
      }),
      this.prisma.exercise.findMany({
        where: { createdByUserId: userId, source: 'USER' },
        select: { id: true },
      }),
    ]);
    await this.prisma.$transaction([
      this.prisma.user.delete({ where: { id: userId } }),
      this.prisma.food.deleteMany({
        where: { id: { in: foods.map((f) => f.id) } },
      }),
      this.prisma.exercise.deleteMany({
        where: { id: { in: exercises.map((e) => e.id) } },
      }),
    ]);
    this.logger.log(`Account ${userId} deleted`);
  }
}

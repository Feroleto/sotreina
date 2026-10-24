import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient, type Area, type DistanceUnit, type WeightUnit } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { randomBytes, randomInt, createHash } from 'node:crypto';
import { hashPassword, verifyPassword } from './password';
import type { LoginInput, RegisterInput, SetPasswordInput } from './dto';
import { EmailService } from '../email/email.service';

const PASSWORD_RESET_TTL_MS = 30 * 60 * 1000;
const EMAIL_CODE_TTL_MS = 10 * 60 * 1000;
const EMAIL_CODE_MAX_ATTEMPTS = 5;
const EMAIL_CODE_COOLDOWN_MS = 60 * 1000;
const EMAIL_CODE_WINDOW_MS = 60 * 60 * 1000;
const EMAIL_CODE_MAX_PER_WINDOW = 5;

const sha256 = (value: string) =>
  createHash('sha256').update(value).digest('hex');

export interface MeResponse {
  id: string;
  email: string | null;
  firstName: string | null;
  profileImgUrl: string | null;
  maxHr: number | null;
  hasStravaAccount: boolean;
  hasPassword: boolean;
  emailVerified: boolean;
  /** empty = not chosen yet (new account) → the client shows the area picker */
  enabledAreas: Area[];
  /** display/entry preference; the API itself always speaks km and kg */
  distanceUnit: DistanceUnit;
  weightUnit: WeightUnit;
}

@Injectable()
export class AuthService {
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

  // null instead of throwing: a valid cookie for a since-deleted user (or one
  // whose tokenVersion no longer matches, e.g. after logout) should read as
  // "logged out", not a 500
  async authenticate(
    session: { userId: string; tokenVersion: number } | null,
  ): Promise<MeResponse | null> {
    if (!session) return null;

    const user = await this.prisma.user.findUnique({
      where: { id: session.userId },
      select: {
        id: true,
        email: true,
        firstName: true,
        profileImgUrl: true,
        maxHr: true,
        enabledAreas: true,
        distanceUnit: true,
        weightUnit: true,
        tokenVersion: true,
        passwordHash: true,
        emailVerifiedAt: true,
        stravaAccount: { select: { id: true } },
      },
    });
    if (!user || user.tokenVersion !== session.tokenVersion) return null;

    const {
      tokenVersion: _tokenVersion,
      passwordHash,
      emailVerifiedAt,
      stravaAccount,
      ...rest
    } = user;
    return {
      ...rest,
      hasStravaAccount: !!stravaAccount,
      hasPassword: !!passwordHash,
      emailVerified: !!emailVerifiedAt,
    };
  }

  async invalidateSessions(userId: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { tokenVersion: { increment: 1 } },
    });
  }

  // any existing row with this email — with or without a password already
  // set — is treated as a conflict; adding a password to an existing
  // Strava-only account goes through setPassword() below instead, which
  // reuses the already-logged-in session rather than a fresh registration
  async register(
    input: RegisterInput,
  ): Promise<{ userId: string; tokenVersion: number }> {
    const existing = await this.prisma.user.findUnique({
      where: { email: input.email },
    });
    if (existing) throw new ConflictException('Email already in use');

    const passwordHash = await hashPassword(input.password);
    const user = await this.prisma.user.create({
      data: {
        email: input.email,
        passwordHash,
        firstName: input.firstName ?? null,
      },
    });
    // the verification code is the only email a new account gets (it doubles
    // as the welcome). Sending is fire-and-forget inside issueVerificationCode,
    // and verifying is never required — a lost email is "Reenviar código"
    await this.issueVerificationCode(user.id, user.email!);
    return { userId: user.id, tokenVersion: user.tokenVersion };
  }

  // null (not thrown) for both "no such email" and "Strava-only account with
  // no password set" — same "don't leak why" spirit as authenticate()
  async login(
    input: LoginInput,
  ): Promise<{ userId: string; tokenVersion: number } | null> {
    const user = await this.prisma.user.findUnique({
      where: { email: input.email },
    });
    if (!user || !user.passwordHash) return null;

    const valid = await verifyPassword(user.passwordHash, input.password);
    if (!valid) return null;

    return { userId: user.id, tokenVersion: user.tokenVersion };
  }

  // adds email/password login to an account that only had one so far (e.g. a
  // Strava-only user whose email is still null). Only for the "no password
  // yet" case — not a change-password endpoint, so an account that already
  // has a passwordHash is rejected rather than silently overwritten
  async setPassword(userId: string, input: SetPasswordInput): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { passwordHash: true },
    });
    if (user?.passwordHash) throw new ConflictException('Password already set');

    const existing = await this.prisma.user.findUnique({
      where: { email: input.email },
    });
    if (existing && existing.id !== userId)
      throw new ConflictException('Email already in use');

    const passwordHash = await hashPassword(input.password);
    await this.prisma.user.update({
      where: { id: userId },
      data: { email: input.email, passwordHash },
    });
  }

  // no-op (not an error) for an unknown email or a Strava-only account with
  // no password — the controller always returns the same generic response
  // regardless, so nothing here can be used to enumerate accounts
  async requestPasswordReset(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || !user.passwordHash) return;

    const token = randomBytes(32).toString('hex');
    const tokenHash = sha256(token);
    await this.prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt: new Date(Date.now() + PASSWORD_RESET_TTL_MS),
      },
    });

    const frontendUrl = this.config.get<string>(
      'FRONTEND_URL',
      'http://localhost:5173',
    );
    const resetUrl = `${frontendUrl}/redefinir-senha?token=${token}`;
    void this.emailService.sendPasswordResetEmail(user.email!, resetUrl);
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    const tokenHash = sha256(token);
    const resetToken = await this.prisma.passwordResetToken.findUnique({
      where: { tokenHash },
    });
    if (
      !resetToken ||
      resetToken.usedAt !== null ||
      resetToken.expiresAt < new Date()
    ) {
      throw new BadRequestException('Invalid or expired token');
    }

    const passwordHash = await hashPassword(newPassword);
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: resetToken.userId },
        data: { passwordHash, tokenVersion: { increment: 1 } },
      }),
      this.prisma.passwordResetToken.update({
        where: { id: resetToken.id },
        data: { usedAt: new Date() },
      }),
      // the link only reached the inbox, so the reset proves ownership of
      // the address; updateMany so an earlier verification date is kept
      this.prisma.user.updateMany({
        where: { id: resetToken.userId, emailVerifiedAt: null },
        data: { emailVerifiedAt: new Date() },
      }),
    ]);
  }

  // per-account limits (1 per 60s, 5 per hour) are counted from the codes
  // themselves rather than a throttler bucket, so they hold across Bearer and
  // cookie, across IPs, and survive a restart. retryAfterSeconds lets the
  // client show the countdown instead of a generic error
  async sendVerificationCode(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true, emailVerifiedAt: true },
    });
    if (!user?.email) throw new BadRequestException('Account has no email');
    if (user.emailVerifiedAt)
      throw new ConflictException('Email already verified');

    const now = Date.now();
    const recent = await this.prisma.emailVerificationCode.findMany({
      where: { userId, createdAt: { gte: new Date(now - EMAIL_CODE_WINDOW_MS) } },
      select: { createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
    let retryAt: number | null = null;
    if (recent.length >= EMAIL_CODE_MAX_PER_WINDOW) {
      retryAt =
        recent[EMAIL_CODE_MAX_PER_WINDOW - 1].createdAt.getTime() +
        EMAIL_CODE_WINDOW_MS;
    } else if (
      recent[0] &&
      now - recent[0].createdAt.getTime() < EMAIL_CODE_COOLDOWN_MS
    ) {
      retryAt = recent[0].createdAt.getTime() + EMAIL_CODE_COOLDOWN_MS;
    }
    if (retryAt !== null) {
      throw new HttpException(
        {
          statusCode: HttpStatus.TOO_MANY_REQUESTS,
          message: 'Too many verification codes requested',
          retryAfterSeconds: Math.ceil((retryAt - now) / 1000),
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    await this.issueVerificationCode(userId, user.email);
  }

  // idempotent once verified. A wrong code spends one of the live code's 5
  // attempts and the 5th kills it — with 10^6 codes and a fresh code at most
  // 5 times an hour, guessing is out of reach
  async verifyEmail(userId: string, code: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { emailVerifiedAt: true },
    });
    if (user?.emailVerifiedAt) return;

    const live = await this.prisma.emailVerificationCode.findFirst({
      where: { userId, consumedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!live || live.attempts >= EMAIL_CODE_MAX_ATTEMPTS) {
      throw new BadRequestException('Invalid or expired code');
    }

    if (sha256(code) !== live.codeHash) {
      const { attempts } = await this.prisma.emailVerificationCode.update({
        where: { id: live.id },
        data: { attempts: { increment: 1 } },
      });
      if (attempts >= EMAIL_CODE_MAX_ATTEMPTS) {
        await this.prisma.emailVerificationCode.update({
          where: { id: live.id },
          data: { consumedAt: new Date() },
        });
      }
      throw new BadRequestException('Invalid or expired code');
    }

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { emailVerifiedAt: new Date() },
      }),
      this.prisma.emailVerificationCode.update({
        where: { id: live.id },
        data: { consumedAt: new Date() },
      }),
    ]);
  }

  // one live code per user: issuing consumes whatever was still pending, so
  // only the code in the latest email works
  private async issueVerificationCode(
    userId: string,
    email: string,
  ): Promise<void> {
    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    await this.prisma.$transaction([
      this.prisma.emailVerificationCode.updateMany({
        where: { userId, consumedAt: null },
        data: { consumedAt: new Date() },
      }),
      this.prisma.emailVerificationCode.create({
        data: {
          userId,
          codeHash: sha256(code),
          expiresAt: new Date(Date.now() + EMAIL_CODE_TTL_MS),
        },
      }),
    ]);
    void this.emailService.sendVerificationCodeEmail(email, code);
  }
}

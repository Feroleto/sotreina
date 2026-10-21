import {
  BadRequestException,
  ConflictException,
  Injectable,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient, type Area } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { randomBytes, createHash } from 'node:crypto';
import { hashPassword, verifyPassword } from './password';
import type { LoginInput, RegisterInput, SetPasswordInput } from './dto';
import { EmailService } from '../email/email.service';

const PASSWORD_RESET_TTL_MS = 30 * 60 * 1000;

export interface MeResponse {
  id: string;
  email: string | null;
  firstName: string | null;
  profileImgUrl: string | null;
  maxHr: number | null;
  hasStravaAccount: boolean;
  hasPassword: boolean;
  /** empty = not chosen yet (new account) → the client shows the area picker */
  enabledAreas: Area[];
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
        tokenVersion: true,
        passwordHash: true,
        stravaAccount: { select: { id: true } },
      },
    });
    if (!user || user.tokenVersion !== session.tokenVersion) return null;

    const {
      tokenVersion: _tokenVersion,
      passwordHash,
      stravaAccount,
      ...rest
    } = user;
    return {
      ...rest,
      hasStravaAccount: !!stravaAccount,
      hasPassword: !!passwordHash,
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
    // fire-and-forget — EmailService never throws, and a Resend outage must
    // not block/fail account creation
    void this.emailService.sendWelcomeEmail(user.email!, user.firstName);
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
    const tokenHash = createHash('sha256').update(token).digest('hex');
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
    const tokenHash = createHash('sha256').update(token).digest('hex');
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
    ]);
  }
}

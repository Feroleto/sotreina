import {
  Body,
  Controller,
  Get,
  HttpCode,
  Post,
  Req,
  Res,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';
import { AuthService } from './auth.service';
import type { MeResponse } from './auth.service';
import { SessionService } from './session.service';
import { AuthGuard } from './auth.guard';
import {
  parseLoginInput,
  parseRegisterInput,
  parseSetPasswordInput,
  parseForgotPasswordInput,
  parseResetPasswordInput,
  parseVerifyEmailInput,
} from './dto';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly session: SessionService,
  ) {}

  // No AuthGuard here on purpose: "who am I" from an anonymous visitor is a
  // valid question, not an auth failure — answering 401 makes the browser log
  // a console error on every logged-out page load (flagged by Lighthouse)
  @Get('me')
  async me(@Req() req: Request): Promise<MeResponse | null> {
    return this.authService.authenticate(this.session.extractSession(req));
  }

  // tighter than the 10/min used elsewhere in this controller — these two
  // are pre-auth and a more attractive brute-force target
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('register')
  @HttpCode(201)
  async register(
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<MeResponse> {
    const input = parseRegisterInput(body);
    const { userId, tokenVersion } = await this.authService.register(input);
    this.session.setCookie(res, userId, tokenVersion);
    return (await this.authService.authenticate({ userId, tokenVersion }))!;
  }

  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('login')
  @HttpCode(200)
  async login(
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<MeResponse> {
    const input = parseLoginInput(body);
    const result = await this.authService.login(input);
    if (!result) throw new UnauthorizedException('Invalid email or password');
    this.session.setCookie(res, result.userId, result.tokenVersion);
    return (await this.authService.authenticate(result))!;
  }

  // Native iOS app login: same credentials check as POST /login, but the JWT
  // comes back in the body (stored in the Keychain, sent as a Bearer header)
  // instead of a cookie. Kept separate so the web's login contract never
  // starts leaking the session token into JS-readable responses
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('token')
  @HttpCode(200)
  async token(
    @Body() body: unknown,
  ): Promise<{ token: string; user: MeResponse }> {
    const input = parseLoginInput(body);
    const result = await this.authService.login(input);
    if (!result) throw new UnauthorizedException('Invalid email or password');
    return {
      token: this.session.signToken(result.userId, result.tokenVersion),
      user: (await this.authService.authenticate(result))!,
    };
  }

  // Native iOS app sign-up: same as POST /register, but the JWT comes back in
  // the body like POST /token — one call (and one throttle bucket) instead of
  // register followed by token
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('register-token')
  @HttpCode(201)
  async registerToken(
    @Body() body: unknown,
  ): Promise<{ token: string; user: MeResponse }> {
    const input = parseRegisterInput(body);
    const result = await this.authService.register(input);
    return {
      token: this.session.signToken(result.userId, result.tokenVersion),
      user: (await this.authService.authenticate(result))!,
    };
  }

  // the real limits (1/60s, 5/hour) are per account, enforced in the service
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @UseGuards(AuthGuard)
  @Post('email/send-code')
  @HttpCode(200)
  async sendEmailCode(@Req() req: Request): Promise<{ ok: true }> {
    const session = this.session.extractSession(req)!;
    await this.authService.sendVerificationCode(session.userId);
    return { ok: true };
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @UseGuards(AuthGuard)
  @Post('email/verify')
  @HttpCode(200)
  async verifyEmail(
    @Req() req: Request,
    @Body() body: unknown,
  ): Promise<MeResponse> {
    const { code } = parseVerifyEmailInput(body);
    const session = this.session.extractSession(req)!;
    await this.authService.verifyEmail(session.userId, code);
    return (await this.authService.authenticate(session))!;
  }

  // guarded + pre-auth-style throttle: this touches the same email-uniqueness
  // and password-hashing cost as register(), just for an already-logged-in
  // user adding credentials to a Strava-only account
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @UseGuards(AuthGuard)
  @Post('set-password')
  @HttpCode(200)
  async setPassword(
    @Req() req: Request,
    @Body() body: unknown,
  ): Promise<MeResponse> {
    const input = parseSetPasswordInput(body);
    const session = this.session.extractSession(req)!;
    await this.authService.setPassword(session.userId, input);
    return (await this.authService.authenticate(session))!;
  }

  // tighter than the 10/min used elsewhere in this controller — same
  // pre-auth brute-force target reasoning as register/login
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('forgot-password')
  @HttpCode(200)
  async forgotPassword(@Body() body: unknown): Promise<{ ok: true }> {
    const { email } = parseForgotPasswordInput(body);
    await this.authService.requestPasswordReset(email);
    // always the same response, regardless of whether the email exists or
    // has a password — anti-enumeration
    return { ok: true };
  }

  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('reset-password')
  @HttpCode(200)
  async resetPassword(@Body() body: unknown): Promise<{ ok: true }> {
    const { token, newPassword } = parseResetPasswordInput(body);
    await this.authService.resetPassword(token, newPassword);
    return { ok: true };
  }

  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('logout')
  @HttpCode(204)
  async logout(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<void> {
    const session = this.session.extractSession(req);
    try {
      if (session) await this.authService.invalidateSessions(session.userId);
    } finally {
      this.session.clearCookie(res);
    }
  }
}

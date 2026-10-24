import { Controller, Delete, Get, Logger, Post, Req, Res, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';
import { StravaAuthService } from './strava-auth.service';
import { SessionService } from '../../auth/session.service';
import { AuthGuard } from '../../auth/auth.guard';
import { AccountThrottlerGuard } from '../../auth/account-throttler.guard';
import { CurrentUser } from '../../auth/current-user.decorator';
import type { AuthenticatedUser } from '../../auth/current-user.decorator';

// separate from StravaAuthController (which is @Controller('strava/auth'))
// so the route base is strava/connect, not nested under strava/auth
@Controller('strava/connect')
@UseGuards(AuthGuard)
export class StravaConnectController {
  private readonly logger = new Logger(StravaConnectController.name);

  constructor(
    private readonly stravaAuth: StravaAuthService,
    private readonly session: SessionService,
  ) {}

  // near-identical to StravaAuthController.authorize — the small duplication
  // is accepted deliberately rather than extracting a shared helper for two
  // call sites; the callback (shared by both) disambiguates via session
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Get()
  connect(@Res() res: Response): void {
    const state = this.session.setOauthState(res);
    const url = this.stravaAuth.buildAuthUrl(state);
    this.logger.log('Redirecting to Strava OAuth (connect flow)');
    res.redirect(url);
  }

  // the iOS app's connect (spec login-app-ios §5.2): no cookie to carry an
  // oauth_state, so the state is a signed JWT bound to this user and their
  // tokenVersion, and the app opens the URL in an ASWebAuthenticationSession.
  // The callback recognizes it and returns to sotreina:// instead of the web
  @UseGuards(AccountThrottlerGuard)
  @Post('start')
  start(@Req() req: Request): { url: string } {
    // AuthGuard already checked this session against the database
    const { userId, tokenVersion } = this.session.extractSession(req)!;
    const state = this.session.signConnectState(userId, tokenVersion);
    this.logger.log('Strava connect started from the app');
    return { url: this.stravaAuth.buildAuthUrl(state) };
  }

  // a Strava-only user is deleted outright (nothing left to log in with),
  // so their session cookie goes too; the client logs out on accountDeleted
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Delete()
  async disconnect(
    @CurrentUser() user: AuthenticatedUser,
    @Res({ passthrough: true }) res: Response,
  ): Promise<{ accountDeleted: boolean }> {
    const result = await this.stravaAuth.disconnectAccount(user.id);
    if (result.accountDeleted) this.session.clearCookie(res);
    return result;
  }
}

import { Controller, Delete, Get, Logger, Res, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Response } from 'express';
import { StravaAuthService } from './strava-auth.service';
import { SessionService } from '../../auth/session.service';
import { AuthGuard } from '../../auth/auth.guard';
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

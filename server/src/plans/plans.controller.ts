import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { PlansService } from './plans.service';
import {
  parseDate,
  parseDayChangeInput,
  parseDaysQuery,
  parseMoveInput,
  parseSavePatternInput,
} from './dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/current-user.decorator';
import { CurrentTimeZone } from '../common/current-time-zone.decorator';

// Plano da semana. Database only, no Strava calls, so the global per-IP
// throttle is enough (no AccountThrottlerGuard)
@Controller('plan')
@UseGuards(AuthGuard)
export class PlansController {
  constructor(private readonly service: PlansService) {}

  @Get()
  async getPattern(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentTimeZone() timeZone: string,
  ) {
    return this.service.getPattern(user.id, timeZone);
  }

  @Put('pattern')
  async savePattern(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentTimeZone() timeZone: string,
    @Body() body: unknown,
  ) {
    return this.service.savePattern(
      user.id,
      parseSavePatternInput(body),
      timeZone,
    );
  }

  @Get('days')
  async getDays(
    @CurrentUser() user: AuthenticatedUser,
    @Query('from') from: unknown,
    @Query('to') to: unknown,
  ) {
    return this.service.getDays(user.id, parseDaysQuery(from, to));
  }

  @Put('days/:date')
  async updateDay(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentTimeZone() timeZone: string,
    @Param('date') date: string,
    @Body() body: unknown,
  ) {
    return this.service.updateDay(
      user.id,
      parseDate(date, 'date'),
      parseDayChangeInput(body),
      timeZone,
    );
  }

  @Post('moves')
  async move(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentTimeZone() timeZone: string,
    @Body() body: unknown,
  ) {
    return this.service.move(user.id, parseMoveInput(body), timeZone);
  }
}

import { BadRequestException, Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { UsersService, type UpdateMeInput } from './users.service';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/current-user.decorator';
import { parseFirstName } from '../auth/dto';
import { parseEnabledAreas } from './dto';

const MIN_MAX_HR = 100;
const MAX_MAX_HR = 230;
const MIN_KCAL_GOAL = 800;
const MAX_KCAL_GOAL = 6000;
const MIN_MACRO_GOAL = 0;
const MAX_MACRO_GOAL = 500;
const MIN_WEEKLY_RUN_KM_GOAL = 1;
const MAX_WEEKLY_RUN_KM_GOAL = 300;
const MIN_WEEKLY_WORKOUTS_GOAL = 1;
const MAX_WEEKLY_WORKOUTS_GOAL = 14;

function parseOptionalIntInRange(
  field: string,
  value: unknown,
  min: number,
  max: number,
): number | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== 'number' || !Number.isInteger(value) || value < min || value > max) {
    throw new BadRequestException(`${field} must be an integer between ${min} and ${max}`);
  }
  return value;
}

@Controller('users')
@UseGuards(AuthGuard)
export class UsersController {
  constructor(private readonly service: UsersService) {}

  @Get('me')
  async me(@CurrentUser() user: AuthenticatedUser) {
    return this.service.getMe(user.id);
  }

  @Patch('me')
  async update(@CurrentUser() user: AuthenticatedUser, @Body() body: Record<string, unknown>) {
    const input: UpdateMeInput = {
      maxHr: parseOptionalIntInRange('maxHr', body?.maxHr, MIN_MAX_HR, MAX_MAX_HR),
      dailyKcalGoal: parseOptionalIntInRange(
        'dailyKcalGoal',
        body?.dailyKcalGoal,
        MIN_KCAL_GOAL,
        MAX_KCAL_GOAL,
      ),
      dailyProteinGoal: parseOptionalIntInRange(
        'dailyProteinGoal',
        body?.dailyProteinGoal,
        MIN_MACRO_GOAL,
        MAX_MACRO_GOAL,
      ),
      dailyCarbsGoal: parseOptionalIntInRange(
        'dailyCarbsGoal',
        body?.dailyCarbsGoal,
        MIN_MACRO_GOAL,
        MAX_MACRO_GOAL,
      ),
      dailyFatGoal: parseOptionalIntInRange(
        'dailyFatGoal',
        body?.dailyFatGoal,
        MIN_MACRO_GOAL,
        MAX_MACRO_GOAL,
      ),
      weeklyRunKmGoal: parseOptionalIntInRange(
        'weeklyRunKmGoal',
        body?.weeklyRunKmGoal,
        MIN_WEEKLY_RUN_KM_GOAL,
        MAX_WEEKLY_RUN_KM_GOAL,
      ),
      weeklyWorkoutsGoal: parseOptionalIntInRange(
        'weeklyWorkoutsGoal',
        body?.weeklyWorkoutsGoal,
        MIN_WEEKLY_WORKOUTS_GOAL,
        MAX_WEEKLY_WORKOUTS_GOAL,
      ),
      enabledAreas: parseEnabledAreas(body?.enabledAreas),
      firstName: body?.firstName === undefined ? undefined : parseFirstName(body.firstName),
    };

    if (Object.values(input).every((v) => v === undefined)) {
      throw new BadRequestException('At least one field must be provided');
    }

    return this.service.updateMe(user.id, input);
  }
}

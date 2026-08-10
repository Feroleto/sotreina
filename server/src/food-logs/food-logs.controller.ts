import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { FoodLogsService } from './food-logs.service';
import {
  parseCreateFoodLogInput,
  parseDateQuery,
  parseDaysQuery,
  parseUpdateFoodLogInput,
} from './food-logs.dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/current-user.decorator';

@Controller('food-logs')
@UseGuards(AuthGuard)
export class FoodLogsController {
  constructor(private readonly service: FoodLogsService) {}

  @Post()
  async create(@CurrentUser() user: AuthenticatedUser, @Body() body: unknown) {
    const input = parseCreateFoodLogInput(body);
    return this.service.create(user.id, input);
  }

  @Get('summary')
  async summary(@CurrentUser() user: AuthenticatedUser, @Query('date') date?: string) {
    const parsedDate = parseDateQuery(date);
    return this.service.getDailySummary(user.id, parsedDate);
  }

  @Get('history')
  async history(@CurrentUser() user: AuthenticatedUser, @Query('days') days?: string) {
    const parsedDays = parseDaysQuery(days);
    return this.service.getHistory(user.id, parsedDays);
  }

  @Get()
  async findByDate(@CurrentUser() user: AuthenticatedUser, @Query('date') date?: string) {
    const parsedDate = parseDateQuery(date);
    return this.service.findByDate(user.id, parsedDate);
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    const input = parseUpdateFoodLogInput(body);
    return this.service.update(user.id, id, input);
  }

  @Delete(':id')
  async remove(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    await this.service.remove(user.id, id);
    return { ok: true };
  }
}

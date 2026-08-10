import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { FoodsService } from './foods.service';
import { parseCreateCustomFoodInput, parseSearchQuery } from './foods.dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/current-user.decorator';

@Controller('foods')
@UseGuards(AuthGuard)
export class FoodsController {
  constructor(private readonly service: FoodsService) {}

  @Get('search')
  async search(@CurrentUser() user: AuthenticatedUser, @Query('q') q?: string) {
    const query = parseSearchQuery(q);
    return this.service.search(user.id, query);
  }

  @Post('custom')
  async createCustom(@CurrentUser() user: AuthenticatedUser, @Body() body: unknown) {
    const input = parseCreateCustomFoodInput(body);
    return this.service.createCustom(user.id, input);
  }

  @Get('barcode/:code')
  async findByBarcode(@CurrentUser() user: AuthenticatedUser, @Param('code') code: string) {
    return this.service.findByBarcode(user.id, code);
  }
}

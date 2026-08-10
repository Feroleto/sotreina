import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { SavedMealsService } from './saved-meals.service';
import {
  parseApplySavedMealInput,
  parseCreateSavedMealInput,
  parseUpdateSavedMealInput,
} from './dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/current-user.decorator';

@Controller('saved-meals')
@UseGuards(AuthGuard)
export class SavedMealsController {
  constructor(private readonly service: SavedMealsService) {}

  @Post()
  async create(@CurrentUser() user: AuthenticatedUser, @Body() body: unknown) {
    const input = parseCreateSavedMealInput(body);
    return this.service.create(user.id, input);
  }

  @Get()
  async list(@CurrentUser() user: AuthenticatedUser) {
    return this.service.list(user.id);
  }

  @Get(':id')
  async findById(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    const meal = await this.service.findById(user.id, id);
    if (!meal) {
      throw new NotFoundException(`Saved meal ${id} not found`);
    }
    return meal;
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    const input = parseUpdateSavedMealInput(body);
    return this.service.update(user.id, id, input);
  }

  @Delete(':id')
  async remove(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    await this.service.remove(user.id, id);
    return { ok: true };
  }

  @Post(':id/apply')
  async apply(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    const input = parseApplySavedMealInput(body);
    return this.service.applyToLog(user.id, id, input);
  }
}

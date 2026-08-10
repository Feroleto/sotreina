import { Body, Controller, Delete, Get, Param, Patch, Post, Put, UseGuards } from '@nestjs/common';
import { MealsService } from './meals.service';
import { parseCreateMealInput, parseReorderMealsInput, parseUpdateMealInput } from './dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/current-user.decorator';

// Every mutation returns the full refreshed list rather than the one row it
// touched — reordering renumbers several meals and deleting one changes
// nothing else's numbering, so the client would have to refetch anyway (same
// convention as WorkoutsService returning the whole WorkoutDetail)
@Controller('meals')
@UseGuards(AuthGuard)
export class MealsController {
  constructor(private readonly service: MealsService) {}

  @Get()
  async list(@CurrentUser() user: AuthenticatedUser) {
    return this.service.list(user.id);
  }

  @Post()
  async create(@CurrentUser() user: AuthenticatedUser, @Body() body: unknown) {
    const input = parseCreateMealInput(body);
    return this.service.create(user.id, input);
  }

  // declared before @Patch(':id')/@Delete(':id') would matter — different
  // verb, but keeping the literal path above the parameterized ones is the
  // habit that stops a future @Put(':id') from shadowing it
  @Put('order')
  async reorder(@CurrentUser() user: AuthenticatedUser, @Body() body: unknown) {
    const input = parseReorderMealsInput(body);
    return this.service.reorder(user.id, input);
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    const input = parseUpdateMealInput(body);
    return this.service.update(user.id, id, input);
  }

  @Delete(':id')
  async remove(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return this.service.remove(user.id, id);
  }
}

import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { WorkoutsService } from './workouts.service';
import {
  parseAddExerciseInput,
  parseFinishWorkoutInput,
  parseUpdateExerciseInput,
  parseAddSetInput,
  parseSetInput,
  parseStartWorkoutInput,
  parseWorkoutsPagination,
} from './dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/current-user.decorator';
import { CurrentLang } from '../common/current-lang.decorator';
import type { Lang } from '../common/lang';

@Controller('workouts')
@UseGuards(AuthGuard)
export class WorkoutsController {
  constructor(private readonly service: WorkoutsService) {}

  @Post()
  async start(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentLang() lang: Lang,
    @Body() body: unknown,
  ) {
    const input = parseStartWorkoutInput(body);
    return this.service.startOrResume(user.id, input, lang);
  }

  @Get('active')
  async active(@CurrentUser() user: AuthenticatedUser, @CurrentLang() lang: Lang) {
    return this.service.getActive(user.id, lang);
  }

  @Get('history-stats')
  async historyStats(@CurrentUser() user: AuthenticatedUser) {
    return this.service.historyStats(user.id);
  }

  @Get()
  async history(
    @CurrentUser() user: AuthenticatedUser,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const pagination = parseWorkoutsPagination(page, limit);
    return this.service.history(user.id, pagination.page, pagination.limit);
  }

  @Get(':id')
  async findById(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentLang() lang: Lang,
    @Param('id') id: string,
  ) {
    const workout = await this.service.findById(user.id, id, lang);
    if (!workout) {
      throw new NotFoundException(`Workout ${id} not found`);
    }
    return workout;
  }

  @Get(':id/template-drift')
  async templateDrift(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    return { diverged: await this.service.getTemplateDrift(user.id, id) };
  }

  @Patch(':id/finish')
  async finish(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentLang() lang: Lang,
    @Param('id') id: string,
    @Body() body: unknown,
  ) {
    const input = parseFinishWorkoutInput(body);
    return this.service.finish(user.id, id, input.syncTemplate ?? false, lang);
  }

  @Delete(':id')
  async discard(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) {
    await this.service.discard(user.id, id);
    return { ok: true };
  }

  @Post(':id/exercises')
  async addExercise(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentLang() lang: Lang,
    @Param('id') workoutId: string,
    @Body() body: unknown,
  ) {
    const input = parseAddExerciseInput(body);
    return this.service.addExercise(user.id, workoutId, input, lang);
  }

  @Patch(':id/exercises/:workoutExerciseId')
  async updateExercise(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentLang() lang: Lang,
    @Param('id') workoutId: string,
    @Param('workoutExerciseId') workoutExerciseId: string,
    @Body() body: unknown,
  ) {
    const input = parseUpdateExerciseInput(body);
    return this.service.updateExercise(user.id, workoutId, workoutExerciseId, input, lang);
  }

  @Delete(':id/exercises/:workoutExerciseId')
  async removeExercise(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentLang() lang: Lang,
    @Param('id') workoutId: string,
    @Param('workoutExerciseId') workoutExerciseId: string,
  ) {
    return this.service.removeExercise(user.id, workoutId, workoutExerciseId, lang);
  }

  @Post(':id/exercises/:workoutExerciseId/sets')
  async addSet(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentLang() lang: Lang,
    @Param('id') workoutId: string,
    @Param('workoutExerciseId') workoutExerciseId: string,
    @Body() body: unknown,
  ) {
    const input = parseAddSetInput(body);
    return this.service.addSet(user.id, workoutId, workoutExerciseId, input, lang);
  }

  @Patch(':id/exercises/:workoutExerciseId/sets/:setId')
  async updateSet(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentLang() lang: Lang,
    @Param('id') workoutId: string,
    @Param('workoutExerciseId') workoutExerciseId: string,
    @Param('setId') setId: string,
    @Body() body: unknown,
  ) {
    const input = parseSetInput(body);
    return this.service.updateSet(user.id, workoutId, workoutExerciseId, setId, input, lang);
  }

  @Delete(':id/exercises/:workoutExerciseId/sets/:setId')
  async deleteSet(
    @CurrentUser() user: AuthenticatedUser,
    @CurrentLang() lang: Lang,
    @Param('id') workoutId: string,
    @Param('workoutExerciseId') workoutExerciseId: string,
    @Param('setId') setId: string,
  ) {
    return this.service.deleteSet(user.id, workoutId, workoutExerciseId, setId, lang);
  }
}

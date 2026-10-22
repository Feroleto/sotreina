import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { ExercisesService } from '../exercises/exercises.service';
import type { CreateTemplateInput, UpdateTemplateInput } from './dto';
import { localizedName, type Lang } from '../common/lang';

export interface TemplateExerciseDetail {
  id: string;
  exerciseId: string;
  exerciseName: string;
  primaryMuscles: string[];
  order: number;
  targetSets: number | null;
  targetRepsMin: number | null;
  targetRepsMax: number | null;
  restSeconds: number | null;
  supersetGroupId: string | null;
}

export interface TemplateDetail {
  id: string;
  name: string;
  description: string | null;
  exercises: TemplateExerciseDetail[];
}

export interface TemplateSyncExercise {
  exerciseId: string;
  order: number;
  targetSets: number;
}

export interface TemplateSummary {
  id: string;
  name: string;
  description: string | null;
  exerciseCount: number;
  exercisePreview: string[];
  /** distinct primaryMuscles across every exercise in the template, first-seen order */
  muscleGroups: string[];
  /** finishedAt of the most recent finished Workout created from this template, if any */
  lastPerformedAt: string | null;
}

const TEMPLATE_DETAIL_SELECT = {
  id: true,
  name: true,
  description: true,
  exercises: {
    orderBy: { order: 'asc' as const },
    select: {
      id: true,
      order: true,
      targetSets: true,
      targetRepsMin: true,
      targetRepsMax: true,
      restSeconds: true,
      supersetGroupId: true,
      exerciseId: true,
      exercise: { select: { name: true, namePt: true, primaryMuscles: true } },
    },
  },
};

type TemplateWithExercises = {
  id: string;
  name: string;
  description: string | null;
  exercises: {
    id: string;
    order: number;
    targetSets: number | null;
    targetRepsMin: number | null;
    targetRepsMax: number | null;
    restSeconds: number | null;
    supersetGroupId: string | null;
    exerciseId: string;
    exercise: { name: string; namePt: string | null; primaryMuscles: string[] };
  }[];
};

function toDetail(template: TemplateWithExercises, lang: Lang): TemplateDetail {
  return {
    id: template.id,
    name: template.name,
    description: template.description,
    exercises: template.exercises.map((te) => ({
      id: te.id,
      exerciseId: te.exerciseId,
      exerciseName: localizedName(te.exercise.name, te.exercise.namePt, lang),
      primaryMuscles: te.exercise.primaryMuscles,
      order: te.order,
      targetSets: te.targetSets,
      targetRepsMin: te.targetRepsMin,
      targetRepsMax: te.targetRepsMax,
      restSeconds: te.restSeconds,
      supersetGroupId: te.supersetGroupId,
    })),
  };
}

@Injectable()
export class WorkoutTemplatesService {
  private readonly prisma: PrismaClient;

  constructor(
    private readonly config: ConfigService,
    private readonly exercisesService: ExercisesService,
  ) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  async create(
    userId: string,
    input: CreateTemplateInput,
    lang: Lang = 'en',
  ): Promise<TemplateDetail> {
    await this.assertExercisesVisible(userId, input.exercises.map((e) => e.exerciseId));

    const template = await this.prisma.workoutTemplate.create({
      data: {
        userId,
        name: input.name,
        description: input.description ?? null,
        exercises: {
          create: input.exercises.map((e, idx) => ({
            exerciseId: e.exerciseId,
            order: idx + 1,
            targetSets: e.targetSets,
            targetRepsMin: e.targetRepsMin,
            targetRepsMax: e.targetRepsMax,
            restSeconds: e.restSeconds,
          })),
        },
      },
      select: TEMPLATE_DETAIL_SELECT,
    });

    return toDetail(template, lang);
  }

  async list(userId: string, lang: Lang = 'en'): Promise<TemplateSummary[]> {
    const templates = await this.prisma.workoutTemplate.findMany({
      where: { userId },
      orderBy: { updatedAt: 'desc' },
      select: {
        id: true,
        name: true,
        description: true,
        exercises: {
          orderBy: { order: 'asc' },
          select: { exercise: { select: { name: true, namePt: true, primaryMuscles: true } } },
        },
      },
    });

    // one batched query for "last performed" instead of one findFirst per
    // template — groupBy gives the max finishedAt per templateId directly
    const templateIds = templates.map((t) => t.id);
    const lastPerformedRows = templateIds.length
      ? await this.prisma.workout.groupBy({
          by: ['templateId'],
          where: { userId, templateId: { in: templateIds }, finishedAt: { not: null } },
          _max: { finishedAt: true },
        })
      : [];
    const lastPerformedByTemplate = new Map(
      lastPerformedRows.map((row) => [row.templateId as string, row._max.finishedAt]),
    );

    return templates.map((t) => ({
      id: t.id,
      name: t.name,
      description: t.description,
      exerciseCount: t.exercises.length,
      exercisePreview: t.exercises
        .slice(0, 3)
        .map((e) => localizedName(e.exercise.name, e.exercise.namePt, lang)),
      muscleGroups: Array.from(new Set(t.exercises.flatMap((e) => e.exercise.primaryMuscles))),
      lastPerformedAt: lastPerformedByTemplate.get(t.id)?.toISOString() ?? null,
    }));
  }

  async findById(userId: string, id: string, lang: Lang = 'en'): Promise<TemplateDetail | null> {
    const template = await this.prisma.workoutTemplate.findFirst({
      where: { id, userId },
      select: TEMPLATE_DETAIL_SELECT,
    });
    return template ? toDetail(template, lang) : null;
  }

  // name/description update and exercises replace run in one transaction —
  // the editor always sends the full state it built in memory (see
  // RoutineEditPage/useRoutineEditor), so there's nothing to diff: `exercises`
  // present means "this is the whole list now", same delete+createMany shape
  // as syncFromWorkout/the lap editor's PUT .../laps. `order` comes from
  // array position (1-based), matching create(). supersetGroupId always ends
  // up null on replace — no UI sets it anywhere yet (schema reserved for a
  // future superset feature), so this isn't a regression
  async update(
    userId: string,
    id: string,
    input: UpdateTemplateInput,
    lang: Lang = 'en',
  ): Promise<TemplateDetail> {
    await this.assertOwnedTemplate(userId, id);
    if (input.exercises !== undefined) {
      await this.assertExercisesVisible(userId, input.exercises.map((e) => e.exerciseId));
    }

    const ops: Prisma.PrismaPromise<unknown>[] = [
      this.prisma.workoutTemplate.update({
        where: { id },
        data: {
          ...(input.name !== undefined && { name: input.name }),
          ...(input.description !== undefined && { description: input.description }),
        },
      }),
    ];
    if (input.exercises !== undefined) {
      const exercises = input.exercises;
      ops.push(
        this.prisma.workoutTemplateExercise.deleteMany({ where: { templateId: id } }),
        this.prisma.workoutTemplateExercise.createMany({
          data: exercises.map((e, idx) => ({
            templateId: id,
            exerciseId: e.exerciseId,
            order: idx + 1,
            targetSets: e.targetSets ?? null,
            targetRepsMin: e.targetRepsMin ?? null,
            targetRepsMax: e.targetRepsMax ?? null,
            restSeconds: e.restSeconds ?? null,
          })),
        }),
      );
    }
    await this.prisma.$transaction(ops);

    return (await this.findById(userId, id, lang))!;
  }

  async remove(userId: string, id: string): Promise<void> {
    await this.assertOwnedTemplate(userId, id);
    // cascades to WorkoutTemplateExercise; Workout.templateId is a nullable
    // relation without cascade, so past workouts survive with templateId set
    // to null (SetNull) — see workouts.service.ts findById/toDetail
    await this.prisma.workoutTemplate.delete({ where: { id } });
  }

  // Called by WorkoutsService.finish when the user opts to "also update the
  // routine" — replaces the template's exercise list wholesale to match what
  // was actually done in that session (exercises, order, sets performed),
  // same delete+createMany shape as the lap editor's PUT .../laps. The
  // exerciseIds here already passed visibility checks when they were added
  // to the workout (WorkoutsService.addExercise), so no need to re-check.
  // targetRepsMin/Max/restSeconds/supersetGroupId aren't tracked by a live workout
  // session, so they're preserved per exerciseId for rows that already
  // existed in the template, and left null for exercises the session added
  // that weren't part of the template before. No `lang` param: its return
  // value is discarded by its only caller (WorkoutsService.finish), never
  // surfaced through any controller.
  async syncFromWorkout(
    userId: string,
    templateId: string,
    exercises: TemplateSyncExercise[],
  ): Promise<TemplateDetail> {
    await this.assertOwnedTemplate(userId, templateId);

    const existing = await this.prisma.workoutTemplateExercise.findMany({
      where: { templateId },
      select: {
        exerciseId: true,
        targetRepsMin: true,
        targetRepsMax: true,
        restSeconds: true,
        supersetGroupId: true,
      },
    });
    const existingByExerciseId = new Map(existing.map((e) => [e.exerciseId, e]));

    await this.prisma.$transaction([
      this.prisma.workoutTemplateExercise.deleteMany({ where: { templateId } }),
      this.prisma.workoutTemplateExercise.createMany({
        data: exercises.map((ex) => {
          const prev = existingByExerciseId.get(ex.exerciseId);
          return {
            templateId,
            exerciseId: ex.exerciseId,
            order: ex.order,
            targetSets: ex.targetSets,
            targetRepsMin: prev?.targetRepsMin ?? null,
            targetRepsMax: prev?.targetRepsMax ?? null,
            restSeconds: prev?.restSeconds ?? null,
            supersetGroupId: prev?.supersetGroupId ?? null,
          };
        }),
      }),
    ]);

    return (await this.findById(userId, templateId))!;
  }

  private async assertExercisesVisible(userId: string, exerciseIds: string[]): Promise<void> {
    for (const exerciseId of exerciseIds) {
      // existence/visibility check only, translated name isn't surfaced here
      const exercise = await this.exercisesService.findById(userId, exerciseId, 'en');
      if (!exercise) {
        throw new NotFoundException(`Exercise ${exerciseId} not found`);
      }
    }
  }

  private async assertOwnedTemplate(userId: string, templateId: string): Promise<void> {
    const template = await this.prisma.workoutTemplate.findFirst({
      where: { id: templateId, userId },
      select: { id: true },
    });
    if (!template) {
      throw new NotFoundException(`Workout template ${templateId} not found`);
    }
  }

}

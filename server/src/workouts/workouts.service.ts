import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { ExercisesService } from '../exercises/exercises.service';
import { WorkoutTemplatesService } from '../workout-templates/workout-templates.service';
import type {
  AddExerciseInput,
  AddSetInput,
  SetInput,
  StartWorkoutInput,
  UpdateExerciseInput,
} from './dto';
import type { TemplateSyncExercise } from '../workout-templates/workout-templates.service';
import { localizedName, type Lang } from '../common/lang';
import {
  beatsRecord,
  bestSet,
  summarizeWorkout,
  type WorkoutFinishSummary,
  type WorkoutPersonalRecord,
} from './workout-summary';

export interface WorkoutSetItem {
  id: string;
  setNumber: number;
  weightKg: number | null;
  reps: number | null;
  rpe: number | null;
  setType: string;
  completedAt: Date;
}

export interface ExerciseTarget {
  sets: number | null;
  repsMin: number | null;
  repsMax: number | null;
  /** seconds; null = the user's global rest default */
  restSeconds: number | null;
}

// the workout's own planned sets win over the routine's (they start as a
// copy and are edited live); reps/rest only ever come from the routine. An
// exercise outside the routine gets a target of its sets alone. Null
// targetSets = a workout opened before the column existed
function resolveTarget(
  fromTemplate: ExerciseTarget | undefined,
  targetSets: number | null | undefined,
): ExerciseTarget | null {
  if (targetSets == null) return fromTemplate ?? null;
  return {
    sets: targetSets,
    repsMin: fromTemplate?.repsMin ?? null,
    repsMax: fromTemplate?.repsMax ?? null,
    restSeconds: fromTemplate?.restSeconds ?? null,
  };
}

export interface WorkoutExerciseDetail {
  id: string;
  exerciseId: string;
  exerciseName: string;
  order: number;
  supersetGroupId: string | null;
  // goal carried over from the originating template, matched by exerciseId —
  // null for free workouts or exercises added ad hoc after starting from one
  target: ExerciseTarget | null;
  sets: WorkoutSetItem[];
}

export interface WorkoutDetail {
  id: string;
  startedAt: Date;
  finishedAt: Date | null;
  notes: string | null;
  templateId: string | null;
  templateName: string | null;
  exercises: WorkoutExerciseDetail[];
}

/** finish's response: the usual detail plus the post-workout summary */
export interface FinishedWorkout extends WorkoutDetail {
  summary: WorkoutFinishSummary;
}

export interface WorkoutSummary {
  id: string;
  startedAt: Date;
  finishedAt: Date | null;
  notes: string | null;
  exerciseCount: number;
}

export interface WorkoutHistoryItem {
  id: string;
  startedAt: Date;
  finishedAt: Date;
  durationSec: number;
  exerciseCount: number;
  /** sum of weightKg × reps across every set in the workout */
  volumeKg: number;
  templateId: string | null;
  templateName: string | null;
}

// comfortably covers the 12-week window the "Histórico" screen aggregates
// client-side (mirroring dashboard/bins.ts's local-time Monday buckets) plus
// slack for the "6 most recent" list on an infrequent user, without the cost
// of returning the user's entire lifetime history
const HISTORY_LOOKBACK_DAYS = 180;

const WORKOUT_DETAIL_SELECT = {
  id: true,
  startedAt: true,
  finishedAt: true,
  notes: true,
  templateId: true,
  template: { select: { name: true } },
  exercises: {
    orderBy: { order: 'asc' as const },
    select: {
      id: true,
      order: true,
      supersetGroupId: true,
      targetSets: true,
      exerciseId: true,
      exercise: { select: { name: true, namePt: true } },
      sets: {
        orderBy: { setNumber: 'asc' as const },
        select: {
          id: true,
          setNumber: true,
          weightKg: true,
          reps: true,
          rpe: true,
          setType: true,
          completedAt: true,
        },
      },
    },
  },
};

type WorkoutWithExercises = {
  id: string;
  startedAt: Date;
  finishedAt: Date | null;
  notes: string | null;
  templateId: string | null;
  template: { name: string } | null;
  exercises: {
    id: string;
    order: number;
    supersetGroupId: string | null;
    targetSets?: number | null;
    exerciseId: string;
    exercise: { name: string; namePt: string | null };
    sets: {
      id: string;
      setNumber: number;
      weightKg: unknown;
      reps: number | null;
      rpe: unknown;
      setType: string;
      completedAt: Date;
    }[];
  }[];
};

@Injectable()
export class WorkoutsService {
  private readonly prisma: PrismaClient;

  constructor(
    private readonly config: ConfigService,
    private readonly exercisesService: ExercisesService,
    private readonly templatesService: WorkoutTemplatesService,
  ) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  // goals only exist when the workout came from a template — one extra
  // query per read, matched by exerciseId since WorkoutExercise doesn't
  // carry a direct pointer back to the WorkoutTemplateExercise it came from
  private async buildDetail(workout: WorkoutWithExercises, lang: Lang): Promise<WorkoutDetail> {
    let targetsByExerciseId = new Map<string, ExerciseTarget>();
    if (workout.templateId) {
      const templateExercises = await this.prisma.workoutTemplateExercise.findMany({
        where: { templateId: workout.templateId },
        select: {
          exerciseId: true,
          targetSets: true,
          targetRepsMin: true,
          targetRepsMax: true,
          restSeconds: true,
        },
      });
      targetsByExerciseId = new Map(
        templateExercises.map((te) => [
          te.exerciseId,
          {
            sets: te.targetSets,
            repsMin: te.targetRepsMin,
            repsMax: te.targetRepsMax,
            restSeconds: te.restSeconds,
          },
        ]),
      );
    }

    return {
      id: workout.id,
      startedAt: workout.startedAt,
      finishedAt: workout.finishedAt,
      notes: workout.notes,
      templateId: workout.templateId,
      // null after the source template is deleted (Workout.templateId is
      // SetNull on delete) — treated as a plain free workout, not an error
      templateName: workout.template?.name ?? null,
      exercises: workout.exercises.map((we) => ({
        id: we.id,
        exerciseId: we.exerciseId,
        exerciseName: localizedName(we.exercise.name, we.exercise.namePt, lang),
        order: we.order,
        supersetGroupId: we.supersetGroupId,
        target: resolveTarget(targetsByExerciseId.get(we.exerciseId), we.targetSets),
        sets: we.sets.map((s) => ({
          id: s.id,
          setNumber: s.setNumber,
          weightKg: s.weightKg != null ? Number(s.weightKg) : null,
          reps: s.reps,
          rpe: s.rpe != null ? Number(s.rpe) : null,
          setType: s.setType,
          completedAt: s.completedAt,
        })),
      })),
    };
  }

  // idempotent: reloading the page mid-workout must not spawn a second
  // in-progress workout, so an existing open one is returned as-is —
  // templateId is ignored in that case, same as any other start-time input
  async startOrResume(
    userId: string,
    input: StartWorkoutInput = {},
    lang: Lang = 'en',
  ): Promise<WorkoutDetail> {
    const existing = await this.prisma.workout.findFirst({
      where: { userId, finishedAt: null },
      select: WORKOUT_DETAIL_SELECT,
    });
    if (existing) return this.buildDetail(existing, lang);

    let seedExercises: {
      exerciseId: string;
      order: number;
      supersetGroupId: string | null;
      targetSets: number | null;
    }[] = [];
    if (input.templateId) {
      const template = await this.templatesService.findById(userId, input.templateId);
      if (!template) {
        throw new NotFoundException(`Workout template ${input.templateId} not found`);
      }
      // structure only — no WorkoutSet is created here, series are still
      // logged live one at a time exactly like a free workout. The planned
      // sets are copied, so editing the routine mid-workout never moves them
      seedExercises = template.exercises.map((te) => ({
        exerciseId: te.exerciseId,
        order: te.order,
        supersetGroupId: te.supersetGroupId,
        targetSets: te.targetSets,
      }));
    }

    const created = await this.prisma.workout.create({
      data: {
        userId,
        templateId: input.templateId,
        ...(seedExercises.length > 0 && { exercises: { create: seedExercises } }),
      },
      select: WORKOUT_DETAIL_SELECT,
    });
    return this.buildDetail(created, lang);
  }

  async getActive(userId: string, lang: Lang = 'en'): Promise<WorkoutDetail | null> {
    const workout = await this.prisma.workout.findFirst({
      where: { userId, finishedAt: null },
      select: WORKOUT_DETAIL_SELECT,
    });
    return workout ? this.buildDetail(workout, lang) : null;
  }

  async history(
    userId: string,
    page: number,
    limit: number,
  ): Promise<{ items: WorkoutSummary[]; total: number; page: number; limit: number }> {
    const where = { userId };
    const skip = (page - 1) * limit;

    const [rows, total] = await Promise.all([
      this.prisma.workout.findMany({
        where,
        orderBy: { startedAt: 'desc' },
        skip,
        take: limit,
        select: {
          id: true,
          startedAt: true,
          finishedAt: true,
          notes: true,
          _count: { select: { exercises: true } },
        },
      }),
      this.prisma.workout.count({ where }),
    ]);

    return {
      items: rows.map((w) => ({
        id: w.id,
        startedAt: w.startedAt,
        finishedAt: w.finishedAt,
        notes: w.notes,
        exerciseCount: w._count.exercises,
      })),
      total,
      page,
      limit,
    };
  }

  // powers the "Histórico" tab: KPI carousel + weekly bars (client-aggregated,
  // same convention as the Run "Atividades" tab) + the 6 most recent sessions.
  // Only finished workouts count — an in-progress one has no volume/duration yet
  async historyStats(userId: string): Promise<WorkoutHistoryItem[]> {
    const since = new Date(Date.now() - HISTORY_LOOKBACK_DAYS * 86_400_000);

    const workouts = await this.prisma.workout.findMany({
      where: { userId, finishedAt: { not: null }, startedAt: { gte: since } },
      orderBy: { startedAt: 'desc' },
      select: {
        id: true,
        startedAt: true,
        finishedAt: true,
        templateId: true,
        template: { select: { name: true } },
        exercises: {
          select: {
            sets: { select: { weightKg: true, reps: true } },
          },
        },
      },
    });

    return workouts.map((w) => {
      let volumeKg = 0;
      for (const ex of w.exercises) {
        for (const s of ex.sets) {
          volumeKg += Number(s.weightKg ?? 0) * (s.reps ?? 0);
        }
      }
      const finishedAt = w.finishedAt!;
      return {
        id: w.id,
        startedAt: w.startedAt,
        finishedAt,
        durationSec: Math.max(
          0,
          Math.round((finishedAt.getTime() - w.startedAt.getTime()) / 1000),
        ),
        exerciseCount: w.exercises.length,
        volumeKg,
        templateId: w.templateId,
        templateName: w.template?.name ?? null,
      };
    });
  }

  async findById(userId: string, id: string, lang: Lang = 'en'): Promise<WorkoutDetail | null> {
    const workout = await this.prisma.workout.findFirst({
      where: { id, userId },
      select: WORKOUT_DETAIL_SELECT,
    });
    return workout ? this.buildDetail(workout, lang) : null;
  }

  // compares the in-progress workout against the template it started from —
  // exercise membership, order, and sets actually logged per exercise vs
  // that exercise's targetSets — to decide whether finishing should offer
  // "update the routine too?" (WorkoutSession.tsx calls this before
  // finishing; syncFromWorkout below does the actual write if the user says
  // yes). Free workouts (no templateId) never diverge, there's nothing to
  // compare against.
  async getTemplateDrift(userId: string, workoutId: string): Promise<boolean> {
    const workout = await this.findById(userId, workoutId);
    if (!workout || !workout.templateId) return false;

    const template = await this.templatesService.findById(userId, workout.templateId);
    if (!template) return false;

    const workoutExercises = [...workout.exercises].sort((a, b) => a.order - b.order);
    const templateExercises = template.exercises;

    const structureChanged =
      workoutExercises.length !== templateExercises.length ||
      workoutExercises.some((we, idx) => we.exerciseId !== templateExercises[idx]?.exerciseId);

    const templateSetsByExerciseId = new Map(
      templateExercises.map((te) => [te.exerciseId, te.targetSets]),
    );
    const setsChanged = workoutExercises.some(
      (we) => (templateSetsByExerciseId.get(we.exerciseId) ?? null) !== we.sets.length,
    );

    return structureChanged || setsChanged;
  }

  // per exercise in this workout: its best set vs the best set of every
  // *other finished* workout (ExercisesService.personalRecord only counts
  // finished ones, and this workout isn't yet — so this must run before
  // finishedAt is set). No previous record = first time doing the exercise,
  // which isn't celebrated as a PR
  private async detectPersonalRecords(
    userId: string,
    workout: WorkoutDetail,
  ): Promise<WorkoutPersonalRecord[]> {
    const candidates = workout.exercises
      .map((we) => ({ we, best: bestSet(we.sets) }))
      .filter((c) => c.best !== null);

    const results = await Promise.all(
      candidates.map(async ({ we, best }) => {
        const previous = await this.exercisesService.personalRecord(userId, we.exerciseId);
        if (!previous || !beatsRecord(best!, previous)) return null;
        return {
          exerciseId: we.exerciseId,
          exerciseName: we.exerciseName,
          weightKg: best!.weightKg,
          reps: best!.reps,
          previousWeightKg: previous.weightKg,
          previousReps: previous.reps,
        };
      }),
    );
    return results.filter((r): r is WorkoutPersonalRecord => r !== null);
  }

  async finish(
    userId: string,
    id: string,
    syncTemplate = false,
    lang: Lang = 'en',
  ): Promise<FinishedWorkout> {
    await this.assertOwnedWorkout(userId, id);

    // one read, shared by the template sync and the PR check
    const current = await this.findById(userId, id, lang);
    const personalRecords = current ? await this.detectPersonalRecords(userId, current) : [];

    if (syncTemplate && current?.templateId) {
      const syncExercises: TemplateSyncExercise[] = current.exercises.map((we) => ({
        exerciseId: we.exerciseId,
        order: we.order,
        targetSets: we.sets.length,
      }));
      await this.templatesService.syncFromWorkout(userId, current.templateId, syncExercises);
    }

    const finishedAt = new Date();
    const workout = await this.prisma.workout.update({
      where: { id },
      data: { finishedAt },
      select: WORKOUT_DETAIL_SELECT,
    });
    const detail = await this.buildDetail(workout, lang);
    return { ...detail, summary: summarizeWorkout(detail, finishedAt, personalRecords) };
  }

  // discards an in-progress workout entirely (not just marking it finished)
  // — WorkoutExercise/WorkoutSet are onDelete: Cascade in the schema, so this
  // is a single delete, no manual cleanup of children needed
  async discard(userId: string, id: string): Promise<void> {
    await this.assertOwnedWorkout(userId, id);
    await this.prisma.workout.delete({ where: { id } });
  }

  async addExercise(
    userId: string,
    workoutId: string,
    input: AddExerciseInput,
    lang: Lang = 'en',
  ): Promise<WorkoutDetail> {
    await this.assertOwnedWorkout(userId, workoutId);

    const exercise = await this.exercisesService.findById(userId, input.exerciseId, lang);
    if (!exercise) {
      throw new NotFoundException(`Exercise ${input.exerciseId} not found`);
    }

    const last = await this.prisma.workoutExercise.aggregate({
      where: { workoutId },
      _max: { order: true },
    });

    await this.prisma.workoutExercise.create({
      data: {
        workoutId,
        exerciseId: input.exerciseId,
        order: (last._max.order ?? 0) + 1,
        // starts with one planned set; the lifter adds more as they go
        targetSets: 1,
      },
    });

    return (await this.findById(userId, workoutId, lang))!;
  }

  // removes an exercise from an in-progress workout, including whatever sets
  // were already logged for it — WorkoutSet is onDelete: Cascade off
  // WorkoutExercise in the schema, same reasoning as discard()'s cascade off
  // Workout, so this is a single delete
  async removeExercise(
    userId: string,
    workoutId: string,
    workoutExerciseId: string,
    lang: Lang = 'en',
  ): Promise<WorkoutDetail> {
    await this.assertOwnedWorkoutExercise(userId, workoutId, workoutExerciseId);
    await this.prisma.workoutExercise.delete({ where: { id: workoutExerciseId } });
    return (await this.findById(userId, workoutId, lang))!;
  }

  // reorder is one PATCH per affected exercise (no bulk endpoint), same
  // "manter simples" contract already used by WorkoutTemplatesService —
  // WorkoutSession's drag handle diffs against a pre-drag snapshot client-side
  // and calls this once per row whose position actually changed. The same
  // PATCH edits the planned sets (the iOS session's "+ Série" / remove),
  // never below the sets already logged
  async updateExercise(
    userId: string,
    workoutId: string,
    workoutExerciseId: string,
    input: UpdateExerciseInput,
    lang: Lang = 'en',
  ): Promise<WorkoutDetail> {
    await this.assertOwnedWorkoutExercise(userId, workoutId, workoutExerciseId);
    if (input.targetSets !== undefined) {
      const logged = await this.prisma.workoutSet.count({ where: { workoutExerciseId } });
      if (input.targetSets < logged) {
        throw new BadRequestException(
          `targetSets (${input.targetSets}) is below the ${logged} sets already logged`,
        );
      }
    }
    await this.prisma.workoutExercise.update({
      where: { id: workoutExerciseId },
      data: {
        ...(input.order !== undefined && { order: input.order }),
        ...(input.targetSets !== undefined && { targetSets: input.targetSets }),
      },
    });
    return (await this.findById(userId, workoutId, lang))!;
  }

  async addSet(
    userId: string,
    workoutId: string,
    workoutExerciseId: string,
    input: AddSetInput,
    lang: Lang = 'en',
  ): Promise<WorkoutDetail> {
    await this.assertOwnedWorkoutExercise(userId, workoutId, workoutExerciseId);

    // a resend of a set the server already has (response lost on the way
    // back) answers with the current detail instead of a duplicate
    if (input.clientId) {
      const existing = await this.prisma.workoutSet.findFirst({
        where: { workoutExerciseId, clientId: input.clientId },
        select: { id: true },
      });
      if (existing) return (await this.findById(userId, workoutId, lang))!;
    }

    const last = await this.prisma.workoutSet.aggregate({
      where: { workoutExerciseId },
      _max: { setNumber: true },
    });

    try {
      await this.prisma.workoutSet.create({
        data: {
          workoutExerciseId,
          setNumber: (last._max.setNumber ?? 0) + 1,
          weightKg: input.weightKg,
          reps: input.reps,
          rpe: input.rpe,
          setType: input.setType ?? 'WORKING',
          clientId: input.clientId,
        },
      });
    } catch (e) {
      // two resends racing past the findFirst above: the unique
      // [workoutExerciseId, clientId] lets exactly one through. Duck-typed
      // rather than instanceof PrismaClientKnownRequestError — tests mock
      // @prisma/client wholesale
      if (!(input.clientId && (e as { code?: unknown }).code === 'P2002')) throw e;
    }

    return (await this.findById(userId, workoutId, lang))!;
  }

  async updateSet(
    userId: string,
    workoutId: string,
    workoutExerciseId: string,
    setId: string,
    input: SetInput,
    lang: Lang = 'en',
  ): Promise<WorkoutDetail> {
    await this.assertOwnedSet(userId, workoutId, workoutExerciseId, setId);

    await this.prisma.workoutSet.update({
      where: { id: setId },
      data: {
        ...(input.weightKg !== undefined && { weightKg: input.weightKg }),
        ...(input.reps !== undefined && { reps: input.reps }),
        ...(input.rpe !== undefined && { rpe: input.rpe }),
        ...(input.setType !== undefined && { setType: input.setType }),
      },
    });

    return (await this.findById(userId, workoutId, lang))!;
  }

  async deleteSet(
    userId: string,
    workoutId: string,
    workoutExerciseId: string,
    setId: string,
    lang: Lang = 'en',
  ): Promise<WorkoutDetail> {
    await this.assertOwnedSet(userId, workoutId, workoutExerciseId, setId);

    await this.prisma.workoutSet.delete({ where: { id: setId } });

    return (await this.findById(userId, workoutId, lang))!;
  }

  private async assertOwnedWorkout(userId: string, workoutId: string): Promise<void> {
    const workout = await this.prisma.workout.findFirst({
      where: { id: workoutId, userId },
      select: { id: true },
    });
    if (!workout) {
      throw new NotFoundException(`Workout ${workoutId} not found`);
    }
  }

  private async assertOwnedWorkoutExercise(
    userId: string,
    workoutId: string,
    workoutExerciseId: string,
  ): Promise<void> {
    const workoutExercise = await this.prisma.workoutExercise.findFirst({
      where: { id: workoutExerciseId, workoutId, workout: { userId } },
      select: { id: true },
    });
    if (!workoutExercise) {
      throw new NotFoundException(`Workout exercise ${workoutExerciseId} not found`);
    }
  }

  private async assertOwnedSet(
    userId: string,
    workoutId: string,
    workoutExerciseId: string,
    setId: string,
  ): Promise<void> {
    const set = await this.prisma.workoutSet.findFirst({
      where: {
        id: setId,
        workoutExerciseId,
        workoutExercise: { workoutId, workout: { userId } },
      },
      select: { id: true },
    });
    if (!set) {
      throw new NotFoundException(`Set ${setId} not found`);
    }
  }
}

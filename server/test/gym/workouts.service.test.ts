import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { WorkoutsService } from 'src/workouts/workouts.service';
import { ExercisesService } from 'src/exercises/exercises.service';
import { WorkoutTemplatesService } from 'src/workout-templates/workout-templates.service';

const { mockPrisma } = vi.hoisted(() => {
  return {
    mockPrisma: {
      workout: {
        findFirst: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
        findMany: vi.fn(),
        count: vi.fn(),
      },
      workoutExercise: {
        findFirst: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
        aggregate: vi.fn(),
      },
      workoutSet: {
        findFirst: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
        aggregate: vi.fn(),
      },
      workoutTemplateExercise: {
        findMany: vi.fn().mockResolvedValue([]),
      },
    },
  };
});

vi.mock('@prisma/client', () => {
  return {
    PrismaClient: vi.fn().mockImplementation(function (this: any) {
      return mockPrisma;
    }),
  };
});

vi.mock('@prisma/adapter-pg', () => {
  return {
    PrismaPg: class {},
  };
});

const USER_ID = 'user_test_123';

const DETAIL_STUB = {
  id: 'w1',
  startedAt: new Date('2026-07-20T10:00:00Z'),
  finishedAt: null,
  notes: null,
  templateId: null,
  template: null,
  exercises: [],
};

const WORKOUT_WITH_TEMPLATE = {
  id: 'w1',
  startedAt: new Date('2026-07-20T10:00:00Z'),
  finishedAt: null,
  notes: null,
  templateId: 'tmpl1',
  template: { name: 'Push Day' },
  exercises: [
    {
      id: 'we1',
      order: 1,
      supersetGroupId: null,
      exerciseId: 'ex1',
      exercise: { name: 'Bench' },
      sets: [
        {
          id: 's1',
          setNumber: 1,
          weightKg: 60,
          reps: 8,
          rpe: null,
          setType: 'WORKING',
          completedAt: new Date(),
        },
      ],
    },
    {
      id: 'we2',
      order: 2,
      supersetGroupId: null,
      exerciseId: 'ex2',
      exercise: { name: 'OHP' },
      sets: [],
    },
  ],
};

function templateStub(
  exercises: {
    exerciseId: string;
    exerciseName: string;
    order: number;
    targetSets: number | null;
  }[],
) {
  return {
    id: 'tmpl1',
    name: 'Push Day',
    description: null,
    exercises: exercises.map((e, idx) => ({
      id: `te${idx + 1}`,
      exerciseId: e.exerciseId,
      exerciseName: e.exerciseName,
      primaryMuscles: [],
      order: e.order,
      targetSets: e.targetSets,
      targetRepsMin: null,
      targetRepsMax: null,
      supersetGroupId: null,
    })),
  };
}

describe('WorkoutsService', () => {
  let service: WorkoutsService;
  let exercisesService: {
    findById: ReturnType<typeof vi.fn>;
    personalRecord: ReturnType<typeof vi.fn>;
  };
  let templatesService: {
    findById: ReturnType<typeof vi.fn>;
    syncFromWorkout: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    vi.clearAllMocks();
    mockPrisma.workoutTemplateExercise.findMany.mockResolvedValue([]);
    exercisesService = { findById: vi.fn(), personalRecord: vi.fn() };
    templatesService = { findById: vi.fn(), syncFromWorkout: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WorkoutsService,
        {
          provide: ConfigService,
          useValue: { get: vi.fn(() => 'postgresql://test') },
        },
        { provide: ExercisesService, useValue: exercisesService },
        { provide: WorkoutTemplatesService, useValue: templatesService },
      ],
    }).compile();

    service = module.get(WorkoutsService);
  });

  describe('startOrResume', () => {
    it('returns the existing open workout instead of creating a duplicate', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB);

      const result = await service.startOrResume(USER_ID);

      expect(result.id).toBe('w1');
      expect(mockPrisma.workout.create).not.toHaveBeenCalled();
    });

    it('creates a new workout when there is no open one', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(null);
      mockPrisma.workout.create.mockResolvedValueOnce(DETAIL_STUB);

      const result = await service.startOrResume(USER_ID);

      expect(result.id).toBe('w1');
      expect(mockPrisma.workout.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: { userId: USER_ID } }),
      );
    });

    it('copies template exercises (order + supersetGroupId) with no sets when starting from a template', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(null); // no open workout
      templatesService.findById.mockResolvedValueOnce({
        id: 'tmpl1',
        name: 'Push Day',
        description: null,
        exercises: [
          { id: 'te1', exerciseId: 'ex1', exerciseName: 'Bench', primaryMuscles: [], order: 1, targetSets: 4, targetRepsMin: 8, targetRepsMax: 12, supersetGroupId: null },
          { id: 'te2', exerciseId: 'ex2', exerciseName: 'OHP', primaryMuscles: [], order: 2, targetSets: 3, targetRepsMin: 6, targetRepsMax: 10, supersetGroupId: 'sg1' },
        ],
      });
      mockPrisma.workout.create.mockResolvedValueOnce(DETAIL_STUB);

      await service.startOrResume(USER_ID, { templateId: 'tmpl1' });

      const data = mockPrisma.workout.create.mock.calls[0][0].data;
      expect(data.templateId).toBe('tmpl1');
      expect(data.exercises.create).toEqual([
        { exerciseId: 'ex1', order: 1, supersetGroupId: null },
        { exerciseId: 'ex2', order: 2, supersetGroupId: 'sg1' },
      ]);
      // no WorkoutSet is ever created from a template — series are still
      // logged live, one at a time, exactly like a free workout
      expect(mockPrisma.workoutSet.create).not.toHaveBeenCalled();
    });

    it('404s when starting from a template the caller does not own', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(null);
      templatesService.findById.mockResolvedValueOnce(null);

      await expect(
        service.startOrResume(USER_ID, { templateId: 'someone_elses_template' }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mockPrisma.workout.create).not.toHaveBeenCalled();
    });

    it('ignores templateId and returns the existing open workout if one is already in progress', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB);

      const result = await service.startOrResume(USER_ID, { templateId: 'tmpl1' });

      expect(result.id).toBe('w1');
      expect(templatesService.findById).not.toHaveBeenCalled();
      expect(mockPrisma.workout.create).not.toHaveBeenCalled();
    });
  });

  describe('addExercise', () => {
    it('computes order as max(current order) + 1', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' }); // ownership check
      exercisesService.findById.mockResolvedValueOnce({ id: 'ex1' });
      mockPrisma.workoutExercise.aggregate.mockResolvedValueOnce({ _max: { order: 3 } });
      mockPrisma.workoutExercise.create.mockResolvedValueOnce({});
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB); // findById refetch

      await service.addExercise(USER_ID, 'w1', { exerciseId: 'ex1' });

      expect(mockPrisma.workoutExercise.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ order: 4 }) }),
      );
    });

    it('starts order at 1 for the first exercise in a workout', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' });
      exercisesService.findById.mockResolvedValueOnce({ id: 'ex1' });
      mockPrisma.workoutExercise.aggregate.mockResolvedValueOnce({ _max: { order: null } });
      mockPrisma.workoutExercise.create.mockResolvedValueOnce({});
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB);

      await service.addExercise(USER_ID, 'w1', { exerciseId: 'ex1' });

      expect(mockPrisma.workoutExercise.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ order: 1 }) }),
      );
    });

    it('rejects a workout the caller does not own (404, not 403)', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(null);

      await expect(
        service.addExercise(USER_ID, 'someone_elses_workout', { exerciseId: 'ex1' }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mockPrisma.workoutExercise.create).not.toHaveBeenCalled();
    });

    it('rejects an exercise the caller cannot see', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' });
      exercisesService.findById.mockResolvedValueOnce(null);

      await expect(
        service.addExercise(USER_ID, 'w1', { exerciseId: 'not-visible' }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mockPrisma.workoutExercise.create).not.toHaveBeenCalled();
    });
  });

  describe('removeExercise', () => {
    it('deletes the workout exercise when owned — WorkoutSet cascades in the schema', async () => {
      mockPrisma.workoutExercise.findFirst.mockResolvedValueOnce({ id: 'we1' }); // ownership
      mockPrisma.workoutExercise.delete.mockResolvedValueOnce({});
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB); // findById refetch

      await service.removeExercise(USER_ID, 'w1', 'we1');

      expect(mockPrisma.workoutExercise.delete).toHaveBeenCalledWith({ where: { id: 'we1' } });
    });

    it('rejects a workoutExercise belonging to another user (404, not 403)', async () => {
      mockPrisma.workoutExercise.findFirst.mockResolvedValueOnce(null);

      await expect(service.removeExercise(USER_ID, 'w1', 'not-mine')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(mockPrisma.workoutExercise.delete).not.toHaveBeenCalled();
    });
  });

  describe('reorderExercise', () => {
    it('updates the order of an owned workout exercise', async () => {
      mockPrisma.workoutExercise.findFirst.mockResolvedValueOnce({ id: 'we1' }); // ownership
      mockPrisma.workoutExercise.update.mockResolvedValueOnce({});
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB); // findById refetch

      await service.reorderExercise(USER_ID, 'w1', 'we1', 2);

      expect(mockPrisma.workoutExercise.update).toHaveBeenCalledWith({
        where: { id: 'we1' },
        data: { order: 2 },
      });
    });

    it('rejects a workoutExercise belonging to another user (404, not 403)', async () => {
      mockPrisma.workoutExercise.findFirst.mockResolvedValueOnce(null);

      await expect(service.reorderExercise(USER_ID, 'w1', 'not-mine', 1)).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(mockPrisma.workoutExercise.update).not.toHaveBeenCalled();
    });
  });

  describe('addSet', () => {
    it('computes setNumber as max(current setNumber) + 1', async () => {
      mockPrisma.workoutExercise.findFirst.mockResolvedValueOnce({ id: 'we1' }); // ownership
      mockPrisma.workoutSet.aggregate.mockResolvedValueOnce({ _max: { setNumber: 2 } });
      mockPrisma.workoutSet.create.mockResolvedValueOnce({});
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB);

      await service.addSet(USER_ID, 'w1', 'we1', { weightKg: 80, reps: 5 });

      expect(mockPrisma.workoutSet.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ setNumber: 3 }) }),
      );
    });

    it('defaults setType to WORKING when not provided', async () => {
      mockPrisma.workoutExercise.findFirst.mockResolvedValueOnce({ id: 'we1' });
      mockPrisma.workoutSet.aggregate.mockResolvedValueOnce({ _max: { setNumber: null } });
      mockPrisma.workoutSet.create.mockResolvedValueOnce({});
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB);

      await service.addSet(USER_ID, 'w1', 'we1', { reps: 10 });

      expect(mockPrisma.workoutSet.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ setNumber: 1, setType: 'WORKING' }),
        }),
      );
    });

    it('rejects a workoutExercise belonging to another user (404, not 403)', async () => {
      mockPrisma.workoutExercise.findFirst.mockResolvedValueOnce(null);

      await expect(
        service.addSet(USER_ID, 'w1', 'someone_elses_we', { reps: 10 }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mockPrisma.workoutSet.create).not.toHaveBeenCalled();
    });
  });

  describe('updateSet / deleteSet ownership', () => {
    it('updateSet 404s when the set is not reachable through this user/workout/exercise chain', async () => {
      mockPrisma.workoutSet.findFirst.mockResolvedValueOnce(null);

      await expect(
        service.updateSet(USER_ID, 'w1', 'we1', 'not-mine', { reps: 5 }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mockPrisma.workoutSet.update).not.toHaveBeenCalled();
    });

    it('deleteSet 404s under the same ownership check', async () => {
      mockPrisma.workoutSet.findFirst.mockResolvedValueOnce(null);

      await expect(
        service.deleteSet(USER_ID, 'w1', 'we1', 'not-mine'),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mockPrisma.workoutSet.delete).not.toHaveBeenCalled();
    });

    it('updateSet checks ownership through the full chain (set → workoutExercise → workout → user)', async () => {
      mockPrisma.workoutSet.findFirst.mockResolvedValueOnce({ id: 's1' });
      mockPrisma.workoutSet.update.mockResolvedValueOnce({});
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB);

      await service.updateSet(USER_ID, 'w1', 'we1', 's1', { reps: 12 });

      const where = mockPrisma.workoutSet.findFirst.mock.calls[0][0].where;
      expect(where).toEqual({
        id: 's1',
        workoutExerciseId: 'we1',
        workoutExercise: { workoutId: 'w1', workout: { userId: USER_ID } },
      });
    });
  });

  describe('findById — template targets', () => {
    it('decorates each exercise with its template target, matched by exerciseId', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({
        ...DETAIL_STUB,
        templateId: 'tmpl1',
        template: { name: 'Push Day' },
        exercises: [
          {
            id: 'we1',
            order: 1,
            supersetGroupId: null,
            exerciseId: 'ex1',
            exercise: { name: 'Bench' },
            sets: [],
          },
        ],
      });
      mockPrisma.workoutTemplateExercise.findMany.mockResolvedValueOnce([
        { exerciseId: 'ex1', targetSets: 4, targetRepsMin: 8, targetRepsMax: 12 },
      ]);

      const result = await service.findById(USER_ID, 'w1');

      expect(result?.templateName).toBe('Push Day');
      expect(result?.exercises[0]?.target).toEqual({ sets: 4, repsMin: 8, repsMax: 12 });
    });

    it('leaves target null for an exercise added ad hoc, not present in the template', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({
        ...DETAIL_STUB,
        templateId: 'tmpl1',
        template: { name: 'Push Day' },
        exercises: [
          {
            id: 'we1',
            order: 1,
            supersetGroupId: null,
            exerciseId: 'ex-not-in-template',
            exercise: { name: 'Extra Curl' },
            sets: [],
          },
        ],
      });
      mockPrisma.workoutTemplateExercise.findMany.mockResolvedValueOnce([
        { exerciseId: 'ex1', targetSets: 4, targetRepsMin: 8, targetRepsMax: 12 },
      ]);

      const result = await service.findById(USER_ID, 'w1');

      expect(result?.exercises[0]?.target).toBeNull();
    });

    it('is null for a free workout (no template) — never queries workoutTemplateExercise', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB);

      const result = await service.findById(USER_ID, 'w1');

      expect(result?.templateId).toBeNull();
      expect(result?.templateName).toBeNull();
      expect(mockPrisma.workoutTemplateExercise.findMany).not.toHaveBeenCalled();
    });

    it('gracefully shows a plain free workout once the source template has been deleted (Workout.templateId is SetNull on delete)', async () => {
      // after the template is gone, templateId/template come back null from
      // the DB — nothing special to handle, it just reads as a free workout
      mockPrisma.workout.findFirst.mockResolvedValueOnce({
        ...DETAIL_STUB,
        templateId: null,
        template: null,
      });

      const result = await service.findById(USER_ID, 'w1');

      expect(result?.templateId).toBeNull();
      expect(result?.templateName).toBeNull();
    });
  });

  describe('historyStats', () => {
    it('computes volume as sum(weightKg × reps) across every set, and duration from finishedAt - startedAt', async () => {
      mockPrisma.workout.findMany.mockResolvedValueOnce([
        {
          id: 'w1',
          startedAt: new Date('2026-07-20T10:00:00.000Z'),
          finishedAt: new Date('2026-07-20T11:00:00.000Z'),
          templateId: 'tmpl1',
          template: { name: 'Push Day' },
          exercises: [
            {
              sets: [
                { weightKg: 80, reps: 5 },
                { weightKg: 80, reps: 5 },
              ],
            },
            { sets: [{ weightKg: 20, reps: 10 }] },
          ],
        },
      ]);

      const result = await service.historyStats(USER_ID);

      expect(result).toEqual([
        {
          id: 'w1',
          startedAt: new Date('2026-07-20T10:00:00.000Z'),
          finishedAt: new Date('2026-07-20T11:00:00.000Z'),
          durationSec: 3600,
          exerciseCount: 2,
          volumeKg: 1000, // 80*5 + 80*5 + 20*10
          templateId: 'tmpl1',
          templateName: 'Push Day',
        },
      ]);
    });

    it('treats a set with no weight recorded (bodyweight) as zero volume, not NaN', async () => {
      mockPrisma.workout.findMany.mockResolvedValueOnce([
        {
          id: 'w1',
          startedAt: new Date('2026-07-20T10:00:00.000Z'),
          finishedAt: new Date('2026-07-20T10:30:00.000Z'),
          templateId: null,
          template: null,
          exercises: [{ sets: [{ weightKg: null, reps: 12 }] }],
        },
      ]);

      const result = await service.historyStats(USER_ID);

      expect(result[0].volumeKg).toBe(0);
      expect(result[0].templateName).toBeNull();
    });

    it('only queries finished workouts within the lookback window', async () => {
      mockPrisma.workout.findMany.mockResolvedValueOnce([]);

      await service.historyStats(USER_ID);

      const where = mockPrisma.workout.findMany.mock.calls[0][0].where;
      expect(where).toMatchObject({ userId: USER_ID, finishedAt: { not: null } });
      expect(where.startedAt.gte).toBeInstanceOf(Date);
    });
  });

  describe('finish', () => {
    it('404s when finishing a workout the caller does not own', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(null);

      await expect(service.finish(USER_ID, 'not-mine')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(mockPrisma.workout.update).not.toHaveBeenCalled();
    });

    it('sets finishedAt when owned', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' });
      mockPrisma.workout.update.mockResolvedValueOnce({ ...DETAIL_STUB, finishedAt: new Date() });

      const result = await service.finish(USER_ID, 'w1');

      expect(result.finishedAt).not.toBeNull();
      expect(mockPrisma.workout.update).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: 'w1' } }),
      );
    });

    it('does not touch the template by default (syncTemplate omitted)', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' }); // ownership
      mockPrisma.workout.update.mockResolvedValueOnce({ ...DETAIL_STUB, finishedAt: new Date() });

      await service.finish(USER_ID, 'w1');

      expect(templatesService.syncFromWorkout).not.toHaveBeenCalled();
    });

    it('syncs the template exercises (order + sets logged) before finishing, when syncTemplate is true', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' }); // ownership
      mockPrisma.workout.findFirst.mockResolvedValueOnce(WORKOUT_WITH_TEMPLATE); // findById refetch
      mockPrisma.workout.update.mockResolvedValueOnce({ ...DETAIL_STUB, finishedAt: new Date() });

      await service.finish(USER_ID, 'w1', true);

      expect(templatesService.syncFromWorkout).toHaveBeenCalledWith(USER_ID, 'tmpl1', [
        { exerciseId: 'ex1', order: 1, targetSets: 1 },
        { exerciseId: 'ex2', order: 2, targetSets: 0 },
      ]);
    });

    it('does not sync a free workout (no templateId) even when syncTemplate is true', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' }); // ownership
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB); // findById refetch, templateId: null
      mockPrisma.workout.update.mockResolvedValueOnce({ ...DETAIL_STUB, finishedAt: new Date() });

      await service.finish(USER_ID, 'w1', true);

      expect(templatesService.syncFromWorkout).not.toHaveBeenCalled();
    });
  });

  describe('finish summary', () => {
    const set = (id: string, weightKg: number | null, reps: number | null) => ({
      id,
      setNumber: 1,
      weightKg,
      reps,
      rpe: null,
      setType: 'NORMAL',
      completedAt: new Date('2026-07-20T10:10:00Z'),
    });
    const WORKOUT_WITH_SETS = {
      ...DETAIL_STUB,
      exercises: [
        {
          id: 'we1',
          order: 1,
          supersetGroupId: null,
          exerciseId: 'bench',
          exercise: { name: 'Bench Press', namePt: 'Supino' },
          sets: [set('s1', 80, 8), set('s2', 85, 5)],
        },
        {
          id: 'we2',
          order: 2,
          supersetGroupId: null,
          exerciseId: 'squat',
          exercise: { name: 'Squat', namePt: null },
          sets: [set('s3', 100, 5)],
        },
        {
          id: 'we3',
          order: 3,
          supersetGroupId: null,
          exerciseId: 'pullup',
          exercise: { name: 'Pull-up', namePt: null },
          sets: [set('s4', null, 10)], // bodyweight: no load, never a PR
        },
      ],
    };

    it('reports volume, sets, exercises and duration', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' }); // ownership
      mockPrisma.workout.findFirst.mockResolvedValueOnce(WORKOUT_WITH_SETS); // pre-finish read
      exercisesService.personalRecord.mockResolvedValue(null);
      mockPrisma.workout.update.mockResolvedValueOnce({ ...WORKOUT_WITH_SETS, finishedAt: new Date() });

      const { summary } = await service.finish(USER_ID, 'w1');

      expect(summary.volumeKg).toBe(80 * 8 + 85 * 5 + 100 * 5);
      expect(summary.setCount).toBe(4);
      expect(summary.exerciseCount).toBe(3);
      expect(summary.durationSec).toBeGreaterThan(0);
    });

    it('flags an exercise whose best set beats the previous finished record', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' });
      mockPrisma.workout.findFirst.mockResolvedValueOnce(WORKOUT_WITH_SETS);
      exercisesService.personalRecord.mockImplementation(async (_u: string, exerciseId: string) =>
        exerciseId === 'bench'
          ? { weightKg: 82.5, reps: 6, workoutId: 'old', startedAt: new Date(), templateName: null }
          : { weightKg: 120, reps: 3, workoutId: 'old', startedAt: new Date(), templateName: null },
      );
      mockPrisma.workout.update.mockResolvedValueOnce({ ...WORKOUT_WITH_SETS, finishedAt: new Date() });

      const { summary } = await service.finish(USER_ID, 'w1', false, 'pt');

      // bench: 85 > 82.5 → PR (localized name); squat: 100 < 120 → not
      expect(summary.personalRecords).toEqual([
        {
          exerciseId: 'bench',
          exerciseName: 'Supino',
          weightKg: 85,
          reps: 5,
          previousWeightKg: 82.5,
          previousReps: 6,
        },
      ]);
      // weightless exercises are never even looked up
      expect(exercisesService.personalRecord).not.toHaveBeenCalledWith(USER_ID, 'pullup');
    });

    it('does not celebrate the first time an exercise is ever done', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' });
      mockPrisma.workout.findFirst.mockResolvedValueOnce(WORKOUT_WITH_SETS);
      exercisesService.personalRecord.mockResolvedValue(null); // no finished history
      mockPrisma.workout.update.mockResolvedValueOnce({ ...WORKOUT_WITH_SETS, finishedAt: new Date() });

      const { summary } = await service.finish(USER_ID, 'w1');

      expect(summary.personalRecords).toEqual([]);
    });

    it('checks records before marking the workout finished (so it never compares against itself)', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' });
      mockPrisma.workout.findFirst.mockResolvedValueOnce(WORKOUT_WITH_SETS);
      exercisesService.personalRecord.mockResolvedValue(null);
      mockPrisma.workout.update.mockResolvedValueOnce({ ...WORKOUT_WITH_SETS, finishedAt: new Date() });

      await service.finish(USER_ID, 'w1');

      const recordCall = exercisesService.personalRecord.mock.invocationCallOrder[0];
      const updateCall = mockPrisma.workout.update.mock.invocationCallOrder[0];
      expect(recordCall).toBeLessThan(updateCall);
    });
  });

  describe('getTemplateDrift', () => {
    it('returns false for a free workout (no templateId)', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(DETAIL_STUB); // findById

      const result = await service.getTemplateDrift(USER_ID, 'w1');

      expect(result).toBe(false);
      expect(templatesService.findById).not.toHaveBeenCalled();
    });

    it('returns false when the workout matches the template exactly', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(WORKOUT_WITH_TEMPLATE);
      templatesService.findById.mockResolvedValueOnce(
        templateStub([
          { exerciseId: 'ex1', exerciseName: 'Bench', order: 1, targetSets: 1 },
          { exerciseId: 'ex2', exerciseName: 'OHP', order: 2, targetSets: 0 },
        ]),
      );

      const result = await service.getTemplateDrift(USER_ID, 'w1');

      expect(result).toBe(false);
    });

    it('returns true when an exercise was added to the workout (membership differs)', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(WORKOUT_WITH_TEMPLATE);
      templatesService.findById.mockResolvedValueOnce(
        templateStub([{ exerciseId: 'ex1', exerciseName: 'Bench', order: 1, targetSets: 1 }]),
      );

      const result = await service.getTemplateDrift(USER_ID, 'w1');

      expect(result).toBe(true);
    });

    it('returns true when the number of sets logged differs from targetSets', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(WORKOUT_WITH_TEMPLATE);
      templatesService.findById.mockResolvedValueOnce(
        templateStub([
          { exerciseId: 'ex1', exerciseName: 'Bench', order: 1, targetSets: 3 },
          { exerciseId: 'ex2', exerciseName: 'OHP', order: 2, targetSets: 0 },
        ]),
      );

      const result = await service.getTemplateDrift(USER_ID, 'w1');

      expect(result).toBe(true);
    });

    it('returns true when the exercise order differs', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(WORKOUT_WITH_TEMPLATE);
      templatesService.findById.mockResolvedValueOnce(
        templateStub([
          { exerciseId: 'ex2', exerciseName: 'OHP', order: 1, targetSets: 0 },
          { exerciseId: 'ex1', exerciseName: 'Bench', order: 2, targetSets: 1 },
        ]),
      );

      const result = await service.getTemplateDrift(USER_ID, 'w1');

      expect(result).toBe(true);
    });
  });

  describe('discard', () => {
    it('404s when discarding a workout the caller does not own', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce(null);

      await expect(service.discard(USER_ID, 'not-mine')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(mockPrisma.workout.delete).not.toHaveBeenCalled();
    });

    it('deletes the workout outright when owned — WorkoutExercise/WorkoutSet cascade in the schema', async () => {
      mockPrisma.workout.findFirst.mockResolvedValueOnce({ id: 'w1' });

      await service.discard(USER_ID, 'w1');

      expect(mockPrisma.workout.delete).toHaveBeenCalledWith({ where: { id: 'w1' } });
    });
  });
});

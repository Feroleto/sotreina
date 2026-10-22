import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { WorkoutTemplatesService } from 'src/workout-templates/workout-templates.service';
import { ExercisesService } from 'src/exercises/exercises.service';

const { mockPrisma } = vi.hoisted(() => {
  return {
    mockPrisma: {
      workoutTemplate: {
        create: vi.fn(),
        findMany: vi.fn(),
        findFirst: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
      workoutTemplateExercise: {
        aggregate: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
        deleteMany: vi.fn(),
        createMany: vi.fn(),
        findFirst: vi.fn(),
        findMany: vi.fn(),
      },
      workout: {
        groupBy: vi.fn(),
      },
      // array-form $transaction, matching how syncFromWorkout calls it —
      // real Prisma runs the given queries atomically and returns their
      // results; for these tests just running them in order is enough
      $transaction: vi.fn((ops: unknown[]) => Promise.all(ops)),
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
  id: 't1',
  name: 'Push Day',
  description: null,
  exercises: [],
};

describe('WorkoutTemplatesService', () => {
  let service: WorkoutTemplatesService;
  let exercisesService: { findById: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    vi.clearAllMocks();
    mockPrisma.workoutTemplateExercise.findMany.mockResolvedValue([]);
    exercisesService = { findById: vi.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WorkoutTemplatesService,
        {
          provide: ConfigService,
          useValue: { get: vi.fn(() => 'postgresql://test') },
        },
        { provide: ExercisesService, useValue: exercisesService },
      ],
    }).compile();

    service = module.get(WorkoutTemplatesService);
  });

  describe('create', () => {
    it('validates every exercise is visible to the caller before creating', async () => {
      exercisesService.findById.mockResolvedValueOnce({ id: 'ex1' }); // first exercise visible
      exercisesService.findById.mockResolvedValueOnce(null); // second exercise not visible

      await expect(
        service.create(USER_ID, {
          name: 'Push Day',
          exercises: [{ exerciseId: 'ex1' }, { exerciseId: 'ex2' }],
        }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mockPrisma.workoutTemplate.create).not.toHaveBeenCalled();
    });

    it('assigns order from array position (1-based)', async () => {
      exercisesService.findById.mockResolvedValue({ id: 'ex' });
      mockPrisma.workoutTemplate.create.mockResolvedValueOnce(DETAIL_STUB);

      await service.create(USER_ID, {
        name: 'Push Day',
        exercises: [{ exerciseId: 'ex1' }, { exerciseId: 'ex2' }, { exerciseId: 'ex3' }],
      });

      const data = mockPrisma.workoutTemplate.create.mock.calls[0][0].data;
      expect(data.exercises.create.map((e: any) => e.order)).toEqual([1, 2, 3]);
    });

    it('creates an empty template when no exercises are given', async () => {
      mockPrisma.workoutTemplate.create.mockResolvedValueOnce(DETAIL_STUB);

      await service.create(USER_ID, { name: 'Empty', exercises: [] });

      expect(mockPrisma.workoutTemplate.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ userId: USER_ID, name: 'Empty' }),
        }),
      );
    });
  });

  describe('ownership', () => {
    it('update 404s for a template belonging to another user', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce(null);

      await expect(
        service.update(USER_ID, 'someone_elses_template', { name: 'Hijack' }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mockPrisma.workoutTemplate.update).not.toHaveBeenCalled();
    });

    it('remove 404s for a template belonging to another user', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce(null);

      await expect(service.remove(USER_ID, 'someone_elses_template')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(mockPrisma.workoutTemplate.delete).not.toHaveBeenCalled();
    });

    it('remove only deletes the template row — never touches workouts directly (the DB FK, ON DELETE SET NULL, is what preserves history; see migration.sql)', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce({ id: 't1' });
      mockPrisma.workoutTemplate.delete.mockResolvedValueOnce({});

      await service.remove(USER_ID, 't1');

      expect(mockPrisma.workoutTemplate.delete).toHaveBeenCalledWith({ where: { id: 't1' } });
    });

    it('update 404s before checking exercise visibility when exercises is provided for a template belonging to another user', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce(null);

      await expect(
        service.update(USER_ID, 'someone_elses_template', {
          exercises: [{ exerciseId: 'ex1' }],
        }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(exercisesService.findById).not.toHaveBeenCalled();
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });
  });

  describe('list', () => {
    it('dedupes muscle groups across exercises and attaches the last-performed date per template', async () => {
      mockPrisma.workoutTemplate.findMany.mockResolvedValueOnce([
        {
          id: 't1',
          name: 'Push Day',
          description: null,
          exercises: [
            { exercise: { name: 'Bench Press', primaryMuscles: ['CHEST', 'TRICEPS'] } },
            { exercise: { name: 'Overhead Press', primaryMuscles: ['SHOULDERS', 'TRICEPS'] } },
          ],
        },
        {
          id: 't2',
          name: 'Leg Day',
          description: null,
          exercises: [],
        },
      ]);
      mockPrisma.workout.groupBy.mockResolvedValueOnce([
        { templateId: 't1', _max: { finishedAt: new Date('2026-07-01T00:00:00.000Z') } },
      ]);

      const result = await service.list(USER_ID);

      expect(result[0]).toMatchObject({
        id: 't1',
        exerciseCount: 2,
        muscleGroups: ['CHEST', 'TRICEPS', 'SHOULDERS'],
        lastPerformedAt: '2026-07-01T00:00:00.000Z',
      });
      expect(result[1]).toMatchObject({
        id: 't2',
        exerciseCount: 0,
        muscleGroups: [],
        lastPerformedAt: null,
      });
      expect(mockPrisma.workout.groupBy).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            userId: USER_ID,
            templateId: { in: ['t1', 't2'] },
            finishedAt: { not: null },
          }),
        }),
      );
    });

    it('skips the groupBy call entirely when there are no templates', async () => {
      mockPrisma.workoutTemplate.findMany.mockResolvedValueOnce([]);

      const result = await service.list(USER_ID);

      expect(result).toEqual([]);
      expect(mockPrisma.workout.groupBy).not.toHaveBeenCalled();
    });
  });

  describe('syncFromWorkout', () => {
    it('404s for a template belonging to another user', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce(null);

      await expect(
        service.syncFromWorkout(USER_ID, 'someone_elses_template', [
          { exerciseId: 'ex1', order: 1, targetSets: 3 },
        ]),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('replaces the exercise list wholesale — deletes all then recreates from the given order/targetSets', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce({ id: 't1' }); // ownership
      mockPrisma.workoutTemplateExercise.findMany.mockResolvedValueOnce([]); // no prior exercises
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce(DETAIL_STUB); // findById refetch

      await service.syncFromWorkout(USER_ID, 't1', [
        { exerciseId: 'ex1', order: 1, targetSets: 3 },
        { exerciseId: 'ex2', order: 2, targetSets: 0 },
      ]);

      expect(mockPrisma.workoutTemplateExercise.deleteMany).toHaveBeenCalledWith({
        where: { templateId: 't1' },
      });
      expect(mockPrisma.workoutTemplateExercise.createMany).toHaveBeenCalledWith({
        data: [
          {
            templateId: 't1',
            exerciseId: 'ex1',
            order: 1,
            targetSets: 3,
            targetRepsMin: null,
            targetRepsMax: null,
            restSeconds: null,
            supersetGroupId: null,
          },
          {
            templateId: 't1',
            exerciseId: 'ex2',
            order: 2,
            targetSets: 0,
            targetRepsMin: null,
            targetRepsMax: null,
            restSeconds: null,
            supersetGroupId: null,
          },
        ],
      });
    });

    it('preserves targetRepsMin/Max/restSeconds/supersetGroupId for exercises that already existed in the template', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce({ id: 't1' }); // ownership
      mockPrisma.workoutTemplateExercise.findMany.mockResolvedValueOnce([
        {
          exerciseId: 'ex1',
          targetRepsMin: 8,
          targetRepsMax: 12,
          restSeconds: 120,
          supersetGroupId: 'sg1',
        },
      ]);
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce(DETAIL_STUB); // findById refetch

      // ex1 already existed (keeps its reps range); ex2 is new (added mid-session)
      await service.syncFromWorkout(USER_ID, 't1', [
        { exerciseId: 'ex1', order: 1, targetSets: 4 },
        { exerciseId: 'ex2', order: 2, targetSets: 2 },
      ]);

      expect(mockPrisma.workoutTemplateExercise.createMany).toHaveBeenCalledWith({
        data: [
          {
            templateId: 't1',
            exerciseId: 'ex1',
            order: 1,
            targetSets: 4,
            targetRepsMin: 8,
            targetRepsMax: 12,
            restSeconds: 120,
            supersetGroupId: 'sg1',
          },
          {
            templateId: 't1',
            exerciseId: 'ex2',
            order: 2,
            targetSets: 2,
            targetRepsMin: null,
            targetRepsMax: null,
            restSeconds: null,
            supersetGroupId: null,
          },
        ],
      });
    });
  });

  describe('update — exercises replace', () => {
    it('replaces the exercise list wholesale when exercises is provided — deletes all then recreates with order from array position', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce({ id: 't1' }); // ownership
      exercisesService.findById.mockResolvedValue({ id: 'ex' }); // every exercise visible
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce(DETAIL_STUB); // findById refetch

      await service.update(USER_ID, 't1', {
        exercises: [
          { exerciseId: 'ex1', targetSets: 3, restSeconds: 150 },
          { exerciseId: 'ex2', targetRepsMin: 8, targetRepsMax: 12 },
        ],
      });

      expect(mockPrisma.workoutTemplateExercise.deleteMany).toHaveBeenCalledWith({
        where: { templateId: 't1' },
      });
      expect(mockPrisma.workoutTemplateExercise.createMany).toHaveBeenCalledWith({
        data: [
          {
            templateId: 't1',
            exerciseId: 'ex1',
            order: 1,
            targetSets: 3,
            targetRepsMin: null,
            targetRepsMax: null,
            restSeconds: 150,
          },
          {
            templateId: 't1',
            exerciseId: 'ex2',
            order: 2,
            targetSets: null,
            targetRepsMin: 8,
            targetRepsMax: 12,
            restSeconds: null,
          },
        ],
      });
    });

    it('leaves the exercise list untouched when exercises is omitted', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce({ id: 't1' }); // ownership
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce(DETAIL_STUB); // findById refetch

      await service.update(USER_ID, 't1', { name: 'New name' });

      expect(mockPrisma.workoutTemplateExercise.deleteMany).not.toHaveBeenCalled();
      expect(mockPrisma.workoutTemplateExercise.createMany).not.toHaveBeenCalled();
    });

    it('validates every exercise is visible to the caller before replacing', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce({ id: 't1' }); // ownership
      exercisesService.findById.mockResolvedValueOnce({ id: 'ex1' }); // first visible
      exercisesService.findById.mockResolvedValueOnce(null); // second not visible

      await expect(
        service.update(USER_ID, 't1', {
          exercises: [{ exerciseId: 'ex1' }, { exerciseId: 'ex2' }],
        }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(mockPrisma.workoutTemplateExercise.deleteMany).not.toHaveBeenCalled();
    });

    it('accepts an empty array to clear the routine', async () => {
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce({ id: 't1' }); // ownership
      mockPrisma.workoutTemplate.findFirst.mockResolvedValueOnce(DETAIL_STUB); // findById refetch

      await service.update(USER_ID, 't1', { exercises: [] });

      expect(mockPrisma.workoutTemplateExercise.deleteMany).toHaveBeenCalledWith({
        where: { templateId: 't1' },
      });
      expect(mockPrisma.workoutTemplateExercise.createMany).toHaveBeenCalledWith({ data: [] });
    });
  });
});

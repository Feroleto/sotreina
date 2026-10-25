import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { ConfigService } from '@nestjs/config';
import { PlansService } from 'src/plans/plans.service';
import type { WorkoutTemplatesService } from 'src/workout-templates/workout-templates.service';
import type { PlanDay } from 'src/plans/plan-resolver';

// The whole Plano da semana flow against a real Postgres, on a throwaway user
// deleted at the end. Opt-in, since it writes to the database in DATABASE_URL:
// `DB_INTEGRATION=1 npx vitest run test/plans/plans.integration.test.ts`.
// Only Date is faked (vi.useFakeTimers would also fake the timers Prisma needs).
// The tests are one story, in order: each builds on the state the previous left
const TZ = 'America/Sao_Paulo';

describe.skipIf(process.env.DB_INTEGRATION !== '1')(
  'plans (integration)',
  () => {
    let prisma: PrismaClient;
    let service: PlansService;
    let userId: string;
    let otherUserId: string;
    let chest: string;
    let back: string;
    let foreign: string;

    // 15:00 local on `date`
    function setToday(date: string) {
      vi.setSystemTime(new Date(`${date}T18:00:00.000Z`));
    }

    function day(days: PlanDay[], date: string) {
      const found = days.find((d) => d.date === date);
      if (!found) throw new Error(`${date} not in window`);
      return Object.fromEntries(found.entries.map((e) => [e.area, e]));
    }

    beforeAll(async () => {
      process.loadEnvFile(join(__dirname, '../../.env'));
      const url = process.env.DATABASE_URL!;
      prisma = new PrismaClient({
        adapter: new PrismaPg({ connectionString: url }),
      });
      const tag = randomUUID();
      userId = (
        await prisma.user.create({
          data: { email: `claude-test-plan-${tag}@example.invalid` },
        })
      ).id;
      otherUserId = (
        await prisma.user.create({
          data: { email: `claude-test-plan-other-${tag}@example.invalid` },
        })
      ).id;
      chest = (
        await prisma.workoutTemplate.create({ data: { userId, name: 'Peito' } })
      ).id;
      back = (
        await prisma.workoutTemplate.create({
          data: { userId, name: 'Costas' },
        })
      ).id;
      foreign = (
        await prisma.workoutTemplate.create({
          data: { userId: otherUserId, name: 'Alheia' },
        })
      ).id;

      // the real ownership rule, on the same database, without booting the module
      const templates = {
        assertOwnedTemplate: async (owner: string, id: string) => {
          const t = await prisma.workoutTemplate.findFirst({
            where: { id, userId: owner },
          });
          if (!t) throw new NotFoundException();
        },
      } as unknown as WorkoutTemplatesService;
      service = new PlansService(
        { get: () => url } as unknown as ConfigService,
        templates,
      );
      vi.useFakeTimers({ toFake: ['Date'] });
    });

    afterAll(async () => {
      vi.useRealTimers();
      await prisma.user.deleteMany({
        where: { id: { in: [userId, otherUserId] } },
      });
      await prisma.$disconnect();
    });

    it('starts with no plan', async () => {
      setToday('2026-10-01');
      expect(await service.getPattern(userId, TZ)).toEqual({
        effectiveFrom: null,
        slots: [],
      });
      expect(
        (await service.getWindow(userId, TZ)).every((d) => !d.active),
      ).toBe(true);
    });

    it('saving the Padrão starts today and sets the Meta semanal of Treinos', async () => {
      const pattern = await service.savePattern(
        userId,
        {
          slots: [
            { weekday: 1, area: 'GYM', templateId: chest },
            { weekday: 3, area: 'GYM', templateId: null },
            { weekday: 5, area: 'GYM', templateId: back },
            { weekday: 2, area: 'RUN', templateId: null },
          ],
        },
        TZ,
      );
      expect(pattern.effectiveFrom).toBe('2026-10-01');
      expect(pattern.slots).toContainEqual({
        weekday: 1,
        area: 'GYM',
        templateId: chest,
        templateName: 'Peito',
      });
      const user = await prisma.user.findUniqueOrThrow({
        where: { id: userId },
      });
      expect(user.weeklyWorkoutsGoal).toBe(3);
    });

    it('refuses a routine of another user', async () => {
      await expect(
        service.savePattern(
          userId,
          { slots: [{ weekday: 1, area: 'GYM', templateId: foreign }] },
          TZ,
        ),
      ).rejects.toThrow(NotFoundException);
    });

    it('editing the Padrão mid-week leaves the past days of the week as they were', async () => {
      setToday('2026-10-28'); // Wednesday
      await service.savePattern(
        userId,
        { slots: [{ weekday: 4, area: 'GYM', templateId: null }] },
        TZ,
      );

      const days = await service.getWindow(userId, TZ);
      expect(day(days, '2026-10-26').GYM).toMatchObject({
        templateName: 'Peito',
        source: 'PATTERN',
      });
      expect(day(days, '2026-10-27').RUN).toBeDefined();
      expect(day(days, '2026-10-28')).toEqual({});
      expect(day(days, '2026-10-29').GYM).toBeDefined();
      // a second save on the same day replaces that day's version, never adds another
      await service.savePattern(
        userId,
        {
          slots: [
            { weekday: 1, area: 'GYM', templateId: chest },
            { weekday: 3, area: 'GYM', templateId: null },
            { weekday: 2, area: 'RUN', templateId: null },
          ],
        },
        TZ,
      );
      expect(await prisma.weekPlanVersion.count({ where: { userId } })).toBe(2);
      expect(
        day(await service.getWindow(userId, TZ), '2026-10-28').GYM,
      ).toBeDefined();
    });

    it('a Folga on a past day of this week, and undoing it', async () => {
      let days = await service.updateDay(
        userId,
        '2026-10-26',
        { GYM: { state: 'SKIPPED', templateId: null } },
        TZ,
      );
      expect(day(days, '2026-10-26').GYM).toMatchObject({
        state: 'SKIPPED',
        source: 'ADJUSTMENT',
      });

      await expect(
        service.updateDay(
          userId,
          '2026-10-27',
          { GYM: { state: 'PLANNED', templateId: null } },
          TZ,
        ),
      ).rejects.toThrow(BadRequestException);

      days = await service.updateDay(userId, '2026-10-26', { GYM: null }, TZ);
      expect(day(days, '2026-10-26').GYM).toMatchObject({
        state: 'PLANNED',
        source: 'PATTERN',
      });
    });

    it('adds a run and changes a routine in one call, from today on', async () => {
      const days = await service.updateDay(
        userId,
        '2026-10-28',
        {
          RUN: { state: 'PLANNED', templateId: null },
          GYM: { state: 'PLANNED', templateId: back },
        },
        TZ,
      );
      expect(day(days, '2026-10-28').RUN).toMatchObject({
        state: 'PLANNED',
        source: 'ADJUSTMENT',
      });
      expect(day(days, '2026-10-28').GYM).toMatchObject({
        templateName: 'Costas',
      });
    });

    it('a refused area leaves the other one of the same call untouched', async () => {
      await expect(
        service.updateDay(
          userId,
          '2026-10-30',
          {
            RUN: { state: 'PLANNED', templateId: null },
            GYM: { state: 'SKIPPED', templateId: null },
          },
          TZ,
        ),
      ).rejects.toThrow(BadRequestException);
      expect(
        day(await service.getWindow(userId, TZ), '2026-10-30').RUN,
      ).toBeUndefined();
    });

    // undoing a move goes back to the Padrão: the routine change the move
    // replaced on the source day is not restored
    it('moves a Treino across the Sunday, carrying its routine, and undoes both halves', async () => {
      let days = await service.move(
        userId,
        { area: 'GYM', from: '2026-10-28', to: '2026-11-03' },
        TZ,
      );
      expect(day(days, '2026-10-28').GYM).toMatchObject({
        state: 'SKIPPED',
        movedTo: '2026-11-03',
      });
      expect(day(days, '2026-11-03').GYM).toMatchObject({
        state: 'PLANNED',
        templateName: 'Costas',
        movedFrom: '2026-10-28',
      });

      days = await service.updateDay(userId, '2026-11-03', { GYM: null }, TZ);
      expect(day(days, '2026-10-28').GYM).toMatchObject({
        state: 'PLANNED',
        source: 'PATTERN',
        templateId: null,
      });
      expect(day(days, '2026-11-03').GYM).toBeUndefined();
    });

    it('a deleted routine becomes "any routine", in the past too', async () => {
      await prisma.workoutTemplate.delete({ where: { id: chest } });
      const days = await service.getWindow(userId, TZ);
      for (const date of ['2026-10-26', '2026-11-02']) {
        expect(day(days, date).GYM).toMatchObject({
          state: 'PLANNED',
          templateId: null,
          templateName: null,
        });
      }
    });

    it('an empty grid turns the plan off from today, keeping the past and the Meta', async () => {
      await service.savePattern(userId, { slots: [] }, TZ);
      const days = await service.getWindow(userId, TZ);
      expect(days.find((d) => d.date === '2026-10-26')!.active).toBe(true);
      expect(days.find((d) => d.date === '2026-10-28')!.active).toBe(false);
      const user = await prisma.user.findUniqueOrThrow({
        where: { id: userId },
      });
      expect(user.weeklyWorkoutsGoal).toBe(2);
    });
  },
);

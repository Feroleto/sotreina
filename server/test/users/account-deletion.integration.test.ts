import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { ConfigService } from '@nestjs/config';
import { AccountDeletionService } from 'src/users/account-deletion.service';
import type { StravaAuthService } from 'src/strava/auth/strava-auth.service';
import { hashPassword } from 'src/auth/password';

// Against a real Postgres: builds an account touching every user-owned table
// (Strava, run, gym, diet, auth codes), deletes it, and requires every table to
// be back at its row count from before. Opt-in, since it writes to the database
// in DATABASE_URL: `DB_INTEGRATION=1 npx vitest run test/users/account-deletion.integration.test.ts`.
// Counting every table (not only the ones with a user_id) also catches child
// rows (laps, sets, items…) and any table added later that doesn't cascade.
describe.skipIf(process.env.DB_INTEGRATION !== '1')(
  'account deletion (integration)',
  () => {
    let prisma: PrismaClient;
    let service: AccountDeletionService;
    const revoked: string[] = [];

    beforeAll(() => {
      process.loadEnvFile(join(__dirname, '../../.env'));
      const url = process.env.DATABASE_URL!;
      prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });
      const config = { get: () => url } as unknown as ConfigService;
      const stravaAuth = {
        revokeToken: async (token: string) => {
          revoked.push(token);
        },
      } as unknown as StravaAuthService;
      service = new AccountDeletionService(config, stravaAuth);
    });

    afterAll(async () => {
      await prisma.$disconnect();
    });

    async function tableCounts(): Promise<Record<string, number>> {
      const tables = await prisma.$queryRaw<{ table_name: string }[]>`
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
          AND table_name <> '_prisma_migrations'`;
      const counts: Record<string, number> = {};
      for (const { table_name } of tables) {
        const [{ n }] = await prisma.$queryRawUnsafe<{ n: number }[]>(
          `SELECT count(*)::int AS n FROM "${table_name}"`,
        );
        counts[table_name] = n;
      }
      return counts;
    }

    it('leaves no row behind in any table', async () => {
      const before = await tableCounts();
      const tag = randomUUID();

      const user = await prisma.user.create({
        data: {
          email: `claude-test-delete-${tag}@example.invalid`,
          passwordHash: await hashPassword('senha12345'),
          firstName: 'Teste',
        },
      });
      const userId = user.id;

      await prisma.stravaAccount.create({
        data: {
          userId,
          stravaAthleteId: BigInt(-Date.now()),
          accessToken: 'a',
          refreshToken: 'refresh_test',
          expiresAt: new Date(),
        },
      });
      await prisma.passwordResetToken.create({
        data: { userId, tokenHash: `t-${tag}`, expiresAt: new Date() },
      });
      await prisma.emailVerificationCode.create({
        data: { userId, codeHash: 'h', expiresAt: new Date() },
      });
      await prisma.athleteHrZones.create({
        data: { userId, customZones: false, zones: [], syncedAt: new Date() },
      });
      const gear = await prisma.gear.create({
        data: { id: `g-${tag}`, userId, name: 'Tênis', distance: 0 },
      });
      const activity = await prisma.activity.create({
        data: {
          userId,
          stravaId: BigInt(-Date.now()),
          name: 'Corrida',
          type: 'Run',
          workoutType: 'EASY_OR_LONG',
          startDate: new Date(),
          movingTimeSec: 60,
          gearId: gear.id,
        },
      });
      await prisma.activityLap.create({
        data: {
          activityId: activity.id,
          lapIndex: 0,
          lapType: 'STEADY',
          startSec: 0,
          endSec: 60,
          totalDurationSec: 60,
          movingDurationSec: 60,
          distanceM: 200,
          avgPaceSecKm: 300,
          avgHr: 0,
          elevGainM: 0,
        },
      });
      await prisma.activitySecond.create({
        data: { activityId: activity.id, secondIndex: 0, distanceTotalM: 0, distanceDeltaM: 0 },
      });
      await prisma.activityBestEffort.create({
        data: {
          id: `be-${tag}`,
          activityId: activity.id,
          name: '400m',
          distance: 400,
          movingTime: 90,
          elapsedTime: 90,
          startDate: new Date(),
        },
      });
      await prisma.activityHrZoneTime.create({
        data: { activityId: activity.id, zoneIndex: 0, min: 0, max: 120, timeSec: 10 },
      });

      const exercise = await prisma.exercise.create({
        data: { name: 'Meu exercício', slug: `custom-${tag}`, source: 'USER', createdByUserId: userId },
      });
      const template = await prisma.workoutTemplate.create({
        data: {
          userId,
          name: 'Rotina',
          exercises: { create: { exerciseId: exercise.id, order: 1 } },
        },
      });
      await prisma.workout.create({
        data: {
          userId,
          templateId: template.id,
          exercises: {
            create: {
              exerciseId: exercise.id,
              order: 1,
              sets: { create: { setNumber: 1, reps: 10 } },
            },
          },
        },
      });

      const food = await prisma.food.create({
        data: {
          name: 'Minha comida',
          source: 'CUSTOM',
          kcal: 100,
          protein: 1,
          carbs: 1,
          fat: 1,
          createdByUserId: userId,
        },
      });
      const meal = await prisma.meal.create({ data: { userId, type: 'LUNCH', order: 1 } });
      await prisma.foodLog.create({
        data: { userId, foodId: food.id, mealId: meal.id, quantity: 100, loggedAt: new Date() },
      });
      await prisma.savedMeal.create({
        data: {
          userId,
          name: 'Prato',
          items: { create: { foodId: food.id, quantity: 100, order: 1 } },
        },
      });

      // sanity: the fixture really did add rows everywhere it meant to
      const during = await tableCounts();
      const untouched = Object.keys(before).filter((t) => during[t] === before[t]);
      expect(untouched).toEqual([]);

      await service.deleteAccount(userId, 'senha12345');

      expect(revoked).toEqual(['refresh_test']);
      expect(await tableCounts()).toEqual(before);
    });
  },
);

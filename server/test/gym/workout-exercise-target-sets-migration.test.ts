import { describe, it, expect } from 'vitest';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const dir = join(__dirname, '../../prisma/migrations');
const name = readdirSync(dir).find((d) => d.endsWith('_add_workout_exercise_target_sets'))!;
const sql = readFileSync(join(dir, name, 'migration.sql'), 'utf-8');

// Pure DDL: a nullable column with no default and no backfill, so the old
// backend keeps working against it and open workouts fall back to the routine
describe('workout exercise target sets migration', () => {
  it('adds target_sets as a nullable integer with no backfill', () => {
    expect(sql).toMatch(/ALTER TABLE "workout_exercises" ADD COLUMN\s+"target_sets" INTEGER;/);
    expect(sql).not.toMatch(/NOT NULL|DEFAULT|UPDATE/i);
  });
});

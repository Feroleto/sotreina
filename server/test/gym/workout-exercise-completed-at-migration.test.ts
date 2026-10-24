import { describe, it, expect } from 'vitest';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const dir = join(__dirname, '../../prisma/migrations');
const name = readdirSync(dir).find((d) => d.endsWith('_add_workout_exercise_completed_at'))!;
const sql = readFileSync(join(dir, name, 'migration.sql'), 'utf-8');

// Pure DDL: every exercise of a workout from before the column starts open,
// and the old backend keeps working against it
describe('workout exercise completed_at migration', () => {
  it('adds completed_at as a nullable timestamp with no backfill', () => {
    expect(sql).toMatch(/ALTER TABLE "workout_exercises" ADD COLUMN\s+"completed_at" TIMESTAMP\(3\);/);
    expect(sql).not.toMatch(/NOT NULL|DEFAULT|UPDATE/i);
  });
});

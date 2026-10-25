import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const sql = readFileSync(
  join(
    __dirname,
    '../../prisma/migrations/20261025155624_add_week_plan/migration.sql',
  ),
  'utf-8',
);

describe('week plan migration', () => {
  // pure DDL: three new tables, nothing existing is altered, so it's safe to
  // apply on Neon before the backend that reads them is deployed
  it('only creates, never alters existing tables or drops anything', () => {
    expect(sql).not.toMatch(/DROP /);
    expect(sql).not.toMatch(
      /ALTER TABLE "(?!week_plan_versions|week_plan_slots|plan_adjustments)/,
    );
  });

  // a deleted Rotina turns a planned day into "any routine"; it must never
  // take the slot or the Ajuste with it (same choice as Workout.templateId)
  it('template FKs are ON DELETE SET NULL', () => {
    for (const table of ['week_plan_slots', 'plan_adjustments']) {
      expect(sql).toMatch(
        new RegExp(
          `ALTER TABLE "${table}" ADD CONSTRAINT "${table}_template_id_fkey"[^;]*ON DELETE SET NULL`,
        ),
      );
    }
  });

  it('everything goes away with the user (account deletion)', () => {
    for (const table of ['week_plan_versions', 'plan_adjustments']) {
      expect(sql).toMatch(
        new RegExp(
          `ALTER TABLE "${table}" ADD CONSTRAINT "${table}_user_id_fkey"[^;]*ON DELETE CASCADE`,
        ),
      );
    }
    expect(sql).toMatch(
      /"week_plan_slots_version_id_fkey"[^;]*ON DELETE CASCADE/,
    );
  });
});

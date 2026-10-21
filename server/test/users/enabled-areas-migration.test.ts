import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const sql = readFileSync(
  join(__dirname, '../../prisma/migrations/20261021231515_add_enabled_areas/migration.sql'),
  'utf-8',
);

describe('enabled areas migration', () => {
  // The column defaults to [] ("not chosen yet" → area picker). Without the
  // backfill every existing user would be sent through onboarding again.
  it('backfills all three areas for existing users after adding the column', () => {
    const addColumn = sql.indexOf('ADD COLUMN');
    const backfill = sql.search(
      /UPDATE "users" SET "enabled_areas" = ARRAY\['RUN', 'GYM', 'DIET'\]/,
    );
    expect(addColumn).toBeGreaterThan(-1);
    expect(backfill).toBeGreaterThan(addColumn);
  });
});

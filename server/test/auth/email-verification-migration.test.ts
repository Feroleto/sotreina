import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const sql = readFileSync(
  join(
    __dirname,
    '../../prisma/migrations/20261023233418_add_email_verification/migration.sql',
  ),
  'utf-8',
);

// Pins two decisions behind email verification: deleting a user wipes their
// codes (same FK rule as password_reset_tokens), and every account that
// predates the feature starts unverified — no backfill sneaks in a date
describe('email verification migration', () => {
  it('email_verification_codes.user_id FK is ON DELETE CASCADE', () => {
    expect(sql).toMatch(
      /ALTER TABLE "email_verification_codes" ADD CONSTRAINT "email_verification_codes_user_id_fkey"[^;]*ON DELETE CASCADE/,
    );
  });

  it('adds email_verified_at as nullable, with no default and no backfill', () => {
    expect(sql).toMatch(
      /ALTER TABLE "users" ADD COLUMN\s+"email_verified_at" TIMESTAMP\(3\);/,
    );
    expect(sql).not.toMatch(/UPDATE\s+"users"/i);
  });
});

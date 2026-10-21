-- CreateEnum
CREATE TYPE "Area" AS ENUM ('RUN', 'GYM', 'DIET');

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "enabled_areas" "Area"[] DEFAULT ARRAY[]::"Area"[];

-- Backfill: every user that already exists keeps all three areas, so only
-- accounts created from now on (empty array, the column default) see the
-- area picker. Must stay in this migration — without it every existing user
-- would be sent through onboarding on their next visit.
UPDATE "users" SET "enabled_areas" = ARRAY['RUN', 'GYM', 'DIET']::"Area"[];

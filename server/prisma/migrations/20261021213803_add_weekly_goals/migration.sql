-- AlterTable
ALTER TABLE "users" ADD COLUMN     "weekly_run_km_goal" INTEGER NOT NULL DEFAULT 20,
ADD COLUMN     "weekly_workouts_goal" INTEGER NOT NULL DEFAULT 3;

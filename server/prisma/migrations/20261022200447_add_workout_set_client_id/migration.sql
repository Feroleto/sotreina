-- AlterTable
ALTER TABLE "workout_sets" ADD COLUMN     "client_id" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "workout_sets_workout_exercise_id_client_id_key" ON "workout_sets"("workout_exercise_id", "client_id");


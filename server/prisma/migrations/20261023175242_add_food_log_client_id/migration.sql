-- AlterTable
ALTER TABLE "food_logs" ADD COLUMN     "client_id" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "food_logs_user_id_client_id_key" ON "food_logs"("user_id", "client_id");

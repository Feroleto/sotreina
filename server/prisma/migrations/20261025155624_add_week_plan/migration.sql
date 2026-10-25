-- CreateEnum
CREATE TYPE "PlanEntryState" AS ENUM ('PLANNED', 'SKIPPED');

-- CreateTable
CREATE TABLE "week_plan_versions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "effective_from" DATE NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "week_plan_versions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "week_plan_slots" (
    "id" TEXT NOT NULL,
    "version_id" TEXT NOT NULL,
    "weekday" INTEGER NOT NULL,
    "area" "Area" NOT NULL,
    "template_id" TEXT,

    CONSTRAINT "week_plan_slots_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "plan_adjustments" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "area" "Area" NOT NULL,
    "state" "PlanEntryState" NOT NULL,
    "template_id" TEXT,
    "moved_from_date" DATE,
    "moved_to_date" DATE,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "plan_adjustments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "week_plan_versions_user_id_effective_from_key" ON "week_plan_versions"("user_id", "effective_from");

-- CreateIndex
CREATE UNIQUE INDEX "week_plan_slots_version_id_weekday_area_key" ON "week_plan_slots"("version_id", "weekday", "area");

-- CreateIndex
CREATE UNIQUE INDEX "plan_adjustments_user_id_date_area_key" ON "plan_adjustments"("user_id", "date", "area");

-- AddForeignKey
ALTER TABLE "week_plan_versions" ADD CONSTRAINT "week_plan_versions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "week_plan_slots" ADD CONSTRAINT "week_plan_slots_version_id_fkey" FOREIGN KEY ("version_id") REFERENCES "week_plan_versions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "week_plan_slots" ADD CONSTRAINT "week_plan_slots_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "workout_templates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plan_adjustments" ADD CONSTRAINT "plan_adjustments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "plan_adjustments" ADD CONSTRAINT "plan_adjustments_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "workout_templates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

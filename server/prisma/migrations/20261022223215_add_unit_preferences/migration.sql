-- CreateEnum
CREATE TYPE "DistanceUnit" AS ENUM ('KM', 'MI');

-- CreateEnum
CREATE TYPE "WeightUnit" AS ENUM ('KG', 'LB');

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "distance_unit" "DistanceUnit" NOT NULL DEFAULT 'KM',
ADD COLUMN     "weight_unit" "WeightUnit" NOT NULL DEFAULT 'KG';

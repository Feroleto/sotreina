import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient, WorkoutType } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

export interface ActivityListItem {
  id: string;
  name: string;
  type: string;
  workoutType: string;
  startDate: Date;
  distanceKm: number | null;
  movingTimeSec: number;
  paceRawSecKm: number | null;
  elevationGainM: number | null;
  averageBpm: number | null;
  maxBpm: number | null;
  averageCadence: number | null;
}

export interface ActivityLapItem {
  id: string;
  lapIndex: number;
  lapType: string;
  startSec: number;
  endSec: number;
  totalDurationSec: number;
  movingDurationSec: number;
  distanceM: number;
  avgPaceSecKm: number;
  avgHr: number;
  maxHr: number | null;
  elevGainM: number;
  avgGradePercent: number | null;
  vam: number | null;
  avgCadence: number | null;
}

export interface LapForAnalysis {
  activityId: string;
  activityStartDate: Date;
  lapIndex: number;
  workoutType: string;
  distanceM: number;
  movingDurationSec: number;
  avgPaceSecKm: number;
  avgHr: number; // 0 sentinel = no HR monitor for this lap, never null
}

export interface ActivityHrZonePoint {
  activityId: string;
  activityStartDate: Date;
  zoneIndex: number;
  min: number;
  max: number;
  timeSec: number;
}

export interface WeeklyDistancePoint {
  weekStart: string;
  totalKm: number;
  totalTimeSec: number;
}

export interface ActivityDetail {
  id: string;
  // string, not BigInt — JSON can't carry BigInt; used for the
  // "View on Strava" link the brand guidelines ask for
  stravaId: string;
  name: string;
  type: string;
  sportType: string | null;
  workoutType: string;
  startDate: Date;
  distanceKm: number | null;
  movingTimeSec: number;
  paceRawSecKm: number | null;
  elevationGainM: number | null;
  averageBpm: number | null;
  maxBpm: number | null;
  averageCadence: number | null;
  summaryPolyline: string | null;
  laps: ActivityLapItem[];
}

@Injectable()
export class ActivitiesService {
  private readonly prisma: PrismaClient;

  constructor(private readonly config: ConfigService) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  private buildWhere(
    userId: string,
    workoutType?: WorkoutType,
    startDate?: Date,
    endDate?: Date,
    gearId?: string,
  ) {
    return {
      userId,
      ...(workoutType && { workoutType }),
      ...(gearId && { gearId }),
      ...((startDate || endDate) && {
        startDate: {
          ...(startDate && { gte: startDate }),
          ...(endDate && { lte: endDate }),
        },
      }),
    };
  }

  async list(
    userId: string,
    page = 1,
    limit = 20,
    workoutType?: WorkoutType,
    startDate?: Date,
    endDate?: Date,
    gearId?: string,
  ): Promise<{
    items: ActivityListItem[];
    total: number;
    page: number;
    limit: number;
  }> {
    const skip = (page - 1) * limit;
    const where = this.buildWhere(userId, workoutType, startDate, endDate, gearId);

    const [items, total] = await Promise.all([
      this.prisma.activity.findMany({
        where,
        orderBy: { startDate: 'desc' },
        skip,
        take: limit,
        select: {
          id: true,
          name: true,
          type: true,
          workoutType: true,
          startDate: true,
          distanceKm: true,
          movingTimeSec: true,
          paceRawSecKm: true,
          elevationGainM: true,
          averageBpm: true,
          maxBpm: true,
          averageCadence: true,
        },
      }),
      this.prisma.activity.count({ where }),
    ]);

    return { items, total, page, limit };
  }

  async weeklyDistance(
    userId: string,
    workoutType?: WorkoutType,
    startDate?: Date,
    endDate?: Date,
  ): Promise<{ weeks: WeeklyDistancePoint[] }> {
    const activities = await this.prisma.activity.findMany({
      where: this.buildWhere(userId, workoutType, startDate, endDate),
      select: { startDate: true, distanceKm: true, movingTimeSec: true },
    });

    if (activities.length === 0) return { weeks: [] };

    const totals = new Map<number, { totalKm: number; totalTimeSec: number }>();
    for (const activity of activities) {
      const week = this.weekStartUtc(activity.startDate).getTime();
      const entry = totals.get(week) ?? { totalKm: 0, totalTimeSec: 0 };
      entry.totalKm += activity.distanceKm ?? 0;
      entry.totalTimeSec += activity.movingTimeSec;
      totals.set(week, entry);
    }

    const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
    const weekKeys = [...totals.keys()];
    const firstWeek = Math.min(...weekKeys);
    const lastWeek = Math.max(...weekKeys);

    const weeks: WeeklyDistancePoint[] = [];
    for (let week = firstWeek; week <= lastWeek; week += WEEK_MS) {
      const entry = totals.get(week) ?? { totalKm: 0, totalTimeSec: 0 };
      weeks.push({
        weekStart: new Date(week).toISOString().slice(0, 10),
        totalKm: entry.totalKm,
        totalTimeSec: entry.totalTimeSec,
      });
    }

    return { weeks };
  }

  async listLapsForAnalysis(userId: string): Promise<{ items: LapForAnalysis[] }> {
    const laps = await this.prisma.activityLap.findMany({
      where: { activity: { userId } },
      orderBy: { activity: { startDate: 'asc' } },
      select: {
        activityId: true,
        lapIndex: true,
        distanceM: true,
        movingDurationSec: true,
        avgPaceSecKm: true,
        avgHr: true,
        activity: { select: { startDate: true, workoutType: true } },
      },
    });

    return {
      items: laps.map((l) => ({
        activityId: l.activityId,
        activityStartDate: l.activity.startDate,
        lapIndex: l.lapIndex,
        workoutType: l.activity.workoutType,
        distanceM: l.distanceM,
        movingDurationSec: l.movingDurationSec,
        avgPaceSecKm: l.avgPaceSecKm,
        avgHr: l.avgHr,
      })),
    };
  }

  // per-activity zone time (not per-lap: Strava's zone distribution is
  // whole-activity, no sub-activity granularity), same division of labor as
  // listLapsForAnalysis — frontend does the weekly bucketing itself
  async listHrZonesForAnalysis(
    userId: string,
  ): Promise<{ items: ActivityHrZonePoint[] }> {
    const rows = await this.prisma.activityHrZoneTime.findMany({
      where: { activity: { userId } },
      orderBy: { activity: { startDate: 'asc' } },
      select: {
        zoneIndex: true,
        min: true,
        max: true,
        timeSec: true,
        activity: { select: { id: true, startDate: true } },
      },
    });

    return {
      items: rows.map((r) => ({
        activityId: r.activity.id,
        activityStartDate: r.activity.startDate,
        zoneIndex: r.zoneIndex,
        min: r.min,
        max: r.max,
        timeSec: r.timeSec,
      })),
    };
  }

  private weekStartUtc(date: Date): Date {
    const day = new Date(
      Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
    );
    const offsetFromMonday = (day.getUTCDay() + 6) % 7;
    day.setUTCDate(day.getUTCDate() - offsetFromMonday);
    return day;
  }

  async findById(userId: string, id: string): Promise<ActivityDetail | null> {
    const activity = await this.prisma.activity.findFirst({
      where: { id, userId },
      select: {
        id: true,
        stravaId: true,
        name: true,
        type: true,
        sportType: true,
        workoutType: true,
        startDate: true,
        distanceKm: true,
        movingTimeSec: true,
        paceRawSecKm: true,
        elevationGainM: true,
        averageBpm: true,
        maxBpm: true,
        averageCadence: true,
        summaryPolyline: true,
        laps: {
          orderBy: { lapIndex: 'asc' },
          select: {
            id: true,
            lapIndex: true,
            lapType: true,
            startSec: true,
            endSec: true,
            totalDurationSec: true,
            movingDurationSec: true,
            distanceM: true,
            avgPaceSecKm: true,
            avgHr: true,
            maxHr: true,
            elevGainM: true,
            avgGradePercent: true,
            vam: true,
            avgCadence: true,
          },
        },
      },
    });
    return activity && { ...activity, stravaId: activity.stravaId.toString() };
  }
}

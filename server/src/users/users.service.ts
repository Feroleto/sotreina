import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

export interface MeSnapshot {
  maxHr: number | null;
  dailyKcalGoal: number;
  dailyProteinGoal: number;
  dailyCarbsGoal: number;
  dailyFatGoal: number;
  weeklyRunKmGoal: number;
  weeklyWorkoutsGoal: number;
}

const ME_SELECT = {
  maxHr: true,
  dailyKcalGoal: true,
  dailyProteinGoal: true,
  dailyCarbsGoal: true,
  dailyFatGoal: true,
  weeklyRunKmGoal: true,
  weeklyWorkoutsGoal: true,
};

export interface UpdateMeInput {
  maxHr?: number;
  dailyKcalGoal?: number;
  dailyProteinGoal?: number;
  dailyCarbsGoal?: number;
  dailyFatGoal?: number;
  weeklyRunKmGoal?: number;
  weeklyWorkoutsGoal?: number;
}

@Injectable()
export class UsersService {
  private readonly prisma: PrismaClient;

  constructor(private readonly config: ConfigService) {
    const adapter = new PrismaPg({
      connectionString: this.config.get<string>('DATABASE_URL'),
    });
    this.prisma = new PrismaClient({ adapter });
  }

  async getMe(userId: string): Promise<MeSnapshot> {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: ME_SELECT,
    });
  }

  async updateMe(userId: string, input: UpdateMeInput): Promise<MeSnapshot> {
    return this.prisma.user.update({
      where: { id: userId },
      data: input,
      select: ME_SELECT,
    });
  }
}

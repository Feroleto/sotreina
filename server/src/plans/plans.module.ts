import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from '../auth/auth.module';
import { WorkoutTemplatesModule } from '../workout-templates/workout-templates.module';
import { PlansController } from './plans.controller';
import { PlansService } from './plans.service';

@Module({
  imports: [ConfigModule, AuthModule, WorkoutTemplatesModule],
  controllers: [PlansController],
  providers: [PlansService],
})
export class PlansModule {}

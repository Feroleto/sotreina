import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { StravaModule } from './strava/strava.module';
import { ActivitiesModule } from './activities/activities.module';
import { GearModule } from './gear/gear.module';
import { PersonalBestsModule } from './personal-bests/personal-bests.module';
import { UsersModule } from './users/users.module';
import { ExercisesModule } from './exercises/exercises.module';
import { WorkoutsModule } from './workouts/workouts.module';
import { WorkoutTemplatesModule } from './workout-templates/workout-templates.module';
import { FoodsModule } from './foods/foods.module';
import { MealsModule } from './meals/meals.module';
import { FoodLogsModule } from './food-logs/food-logs.module';
import { SavedMealsModule } from './saved-meals/saved-meals.module';
import { PlansModule } from './plans/plans.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // in-memory storage (package default) — fine for a single Render
    // instance; revisit with a shared store (e.g. Redis) if the app ever
    // scales past one instance
    ThrottlerModule.forRoot([{ name: 'default', ttl: 60_000, limit: 100 }]),
    AuthModule,
    StravaModule,
    ActivitiesModule,
    GearModule,
    PersonalBestsModule,
    UsersModule,
    ExercisesModule,
    WorkoutsModule,
    WorkoutTemplatesModule,
    FoodsModule,
    MealsModule,
    FoodLogsModule,
    SavedMealsModule,
    PlansModule,
  ],
  controllers: [AppController],
  providers: [AppService, { provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}

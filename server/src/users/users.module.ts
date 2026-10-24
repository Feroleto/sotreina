import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from '../auth/auth.module';
import { StravaModule } from '../strava/strava.module';
import { AccountDeletionService } from './account-deletion.service';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [ConfigModule, AuthModule, StravaModule],
  controllers: [UsersController],
  providers: [UsersService, AccountDeletionService],
})
export class UsersModule {}

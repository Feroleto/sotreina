import { Controller, Get } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  // keep-alive target for the external ping that stops the Render free tier
  // from sleeping. Must never touch Prisma: a ping that reached Postgres
  // would keep Neon's compute awake 24h and burn its free-tier quota
  @Get('health')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  health(): { ok: true } {
    return { ok: true };
  }
}

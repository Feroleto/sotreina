import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { resolveTimeZone } from './timezone';

// X-Time-Zone → validated IANA zone (UTC fallback), same explicit-threading
// approach as @CurrentLang() — no request-scoped providers
export const CurrentTimeZone = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): string => {
    const req = ctx.switchToHttp().getRequest();
    return resolveTimeZone(req.headers['x-time-zone']);
  },
);

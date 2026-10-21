import type { PrismaClient } from '@prisma/client';

// API Policy 7.4: when an athlete revokes access (on strava.com or via our
// own "disconnect"), every piece of Strava Data and personal data derived
// from it has to go — not just the tokens. Shared by the deauthorization
// webhook and StravaAuthService.disconnectAccount. A plain helper taking the
// caller's PrismaClient (not an injectable service) so it doesn't open yet
// another connection pool.
//
// A Strava-only user (no passwordHash) loses the User row itself: without a
// password and without a StravaAccount there's no way left to log in, and a
// later Strava login would create a fresh User anyway (find-or-create keys
// on the StravaAccount), so the old row would just be unreachable data.
export async function purgeStravaData(
  prisma: PrismaClient,
  userId: string,
): Promise<{ accountDeleted: boolean }> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { passwordHash: true },
  });
  if (!user) return { accountDeleted: false };

  if (user.passwordHash === null) {
    // cascades to everything (activities, gear, zones, workouts, diet…)
    await prisma.user.delete({ where: { id: userId } });
    return { accountDeleted: true };
  }

  // Activity cascades to laps, seconds, best efforts and zone times
  await prisma.$transaction([
    prisma.activity.deleteMany({ where: { userId } }),
    prisma.gear.deleteMany({ where: { userId } }),
    prisma.athleteHrZones.deleteMany({ where: { userId } }),
    prisma.stravaAccount.deleteMany({ where: { userId } }),
    // the avatar URL points at Strava's CDN — Strava-derived personal data
    prisma.user.update({ where: { id: userId }, data: { profileImgUrl: null } }),
  ]);
  return { accountDeleted: false };
}

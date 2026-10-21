import { describe, it, expect, beforeEach, vi } from 'vitest';
import { purgeStravaData } from 'src/strava/strava-data-purge';

const USER_ID = 'user_1';

function makePrisma() {
  return {
    user: { findUnique: vi.fn(), delete: vi.fn(), update: vi.fn((args) => ({ op: 'user.update', args })) },
    activity: { deleteMany: vi.fn((args) => ({ op: 'activity.deleteMany', args })) },
    gear: { deleteMany: vi.fn((args) => ({ op: 'gear.deleteMany', args })) },
    athleteHrZones: { deleteMany: vi.fn((args) => ({ op: 'athleteHrZones.deleteMany', args })) },
    stravaAccount: { deleteMany: vi.fn((args) => ({ op: 'stravaAccount.deleteMany', args })) },
    $transaction: vi.fn(async (ops: unknown[]) => ops),
  };
}

describe('purgeStravaData', () => {
  let prisma: ReturnType<typeof makePrisma>;

  beforeEach(() => {
    prisma = makePrisma();
  });

  it('deletes all Strava data but keeps a user who can still log in with a password', async () => {
    prisma.user.findUnique.mockResolvedValueOnce({ passwordHash: 'hash' });

    const result = await purgeStravaData(prisma as any, USER_ID);

    expect(result).toEqual({ accountDeleted: false });
    expect(prisma.user.delete).not.toHaveBeenCalled();
    const ops = (prisma.$transaction.mock.calls[0][0] as { op: string; args: unknown }[]).map((o) => o.op);
    expect(ops).toEqual([
      'activity.deleteMany',
      'gear.deleteMany',
      'athleteHrZones.deleteMany',
      'stravaAccount.deleteMany',
      'user.update',
    ]);
    for (const model of [prisma.activity, prisma.gear, prisma.athleteHrZones, prisma.stravaAccount]) {
      expect(model.deleteMany).toHaveBeenCalledWith({ where: { userId: USER_ID } });
    }
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: USER_ID },
      data: { profileImgUrl: null },
    });
  });

  it('deletes a Strava-only user entirely (no way left to log in)', async () => {
    prisma.user.findUnique.mockResolvedValueOnce({ passwordHash: null });

    const result = await purgeStravaData(prisma as any, USER_ID);

    expect(result).toEqual({ accountDeleted: true });
    expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: USER_ID } });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('is a no-op for an unknown user', async () => {
    prisma.user.findUnique.mockResolvedValueOnce(null);

    await expect(purgeStravaData(prisma as any, USER_ID)).resolves.toEqual({ accountDeleted: false });
    expect(prisma.user.delete).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});

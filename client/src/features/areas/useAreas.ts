import { useState } from 'react';
import { useAuth } from '@/features/auth/AuthContext';
import { patchMe } from '@/lib/userMe';
import type { Area } from '@/lib/types';

/**
 * the user's enabled areas, read off the /auth/me user (no fetch of its own)
 * + an optimistic save: the toggle flips at once, the nav/Hoje follow, and a
 * failed PATCH puts the previous selection back
 */
export function useAreas() {
  const { user, setUser } = useAuth();
  const areas = user?.enabledAreas ?? [];
  const [error, setError] = useState(false);

  async function save(next: Area[]): Promise<void> {
    if (!user || next.length === 0) return;
    setError(false);
    setUser({ ...user, enabledAreas: next });
    try {
      const snap = await patchMe({ enabledAreas: next });
      setUser({ ...user, enabledAreas: snap.enabledAreas });
    } catch {
      setUser(user);
      setError(true);
    }
  }

  return { areas, has: (a: Area) => areas.includes(a), save, error };
}

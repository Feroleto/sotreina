import { useState } from 'react';
import { useAuth } from '@/features/auth/AuthContext';
import { patchMe } from '@/lib/userMe';
import { DEFAULT_UNITS, type UnitPrefs } from '@/lib/units';

/**
 * the user's display units, read off the /auth/me user (no fetch of its
 * own) + an optimistic save — same shape as useAreas: the switch flips at
 * once (AuthProvider pushes it into lib/units), a failed PATCH reverts it
 */
export function useUnits() {
  const { user, setUser } = useAuth();
  const units: UnitPrefs = {
    distanceUnit: user?.distanceUnit ?? DEFAULT_UNITS.distanceUnit,
    weightUnit: user?.weightUnit ?? DEFAULT_UNITS.weightUnit,
  };
  const [error, setError] = useState(false);

  async function save(next: Partial<UnitPrefs>): Promise<void> {
    if (!user) return;
    setError(false);
    setUser({ ...user, ...next });
    try {
      const snap = await patchMe(next);
      setUser({
        ...user,
        distanceUnit: snap.distanceUnit,
        weightUnit: snap.weightUnit,
      });
    } catch {
      setUser(user);
      setError(true);
    }
  }

  return { ...units, save, error };
}

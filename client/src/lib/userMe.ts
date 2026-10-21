import { apiFetch } from '@/lib/api';
import type { Area, NutritionGoal, WeeklyGoals } from '@/lib/types';

/** full snapshot returned by GET/PATCH /users/me */
export type MeSnapshot = NutritionGoal &
  WeeklyGoals & {
    maxHr: number | null;
    firstName: string | null;
    enabledAreas: Area[];
  };

/** PATCH /users/me with any subset of its fields; resolves to the snapshot */
export async function patchMe(
  body: Partial<Omit<MeSnapshot, 'firstName'>> & { firstName?: string },
): Promise<MeSnapshot> {
  const res = await apiFetch('/users/me', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

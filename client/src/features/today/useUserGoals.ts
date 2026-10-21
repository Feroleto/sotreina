import { useEffect, useState } from 'react';
import { apiFetch } from '@/lib/api';
import type { NutritionGoal, WeeklyGoals } from '@/lib/types';

// the "Hoje" page reads both the daily kcal goal and the weekly targets off
// the same GET /users/me snapshot, so one hook covers both instead of
// stacking useNutritionGoal on top (two fetches of the same row). Save sends
// only the weekly fields — the kcal goal is edited from Dieta's GoalPage
export type UserGoals = NutritionGoal & WeeklyGoals;

export function useUserGoals() {
  const [goals, setGoals] = useState<UserGoals | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiFetch('/users/me')
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data: UserGoals) => {
        setGoals(data);
        setError(null);
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  async function saveWeekly(next: WeeklyGoals): Promise<void> {
    const res = await apiFetch('/users/me', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(next),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data: UserGoals = await res.json();
    setGoals(data);
  }

  return { goals, loading, error, saveWeekly };
}

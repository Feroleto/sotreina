import type { PersonalBestRecord } from '@/lib/types';

/** distance key (lowercased record name) → identity of its current top-1 effort */
export type PrSnapshot = Record<string, string>;

/** the top-1 effort per distance, identified by activity + time */
export function topRecordIdentities(records: PersonalBestRecord[]): PrSnapshot {
  const snapshot: PrSnapshot = {};
  for (const r of records) {
    if (r.rank !== 1) continue;
    snapshot[r.name.toLowerCase()] = `${r.activityId}:${r.movingTime}`;
  }
  return snapshot;
}

/**
 * Distances whose top-1 changed since the last snapshot. No previous
 * snapshot (first visit, new device) means nothing to compare against —
 * celebrating every existing record there would be noise, so it's empty.
 */
export function newRecordKeys(
  previous: PrSnapshot | null,
  next: PrSnapshot,
): string[] {
  if (previous == null) return [];
  return Object.keys(next).filter((k) => next[k] !== previous[k]);
}

const storageKey = (userId: string) => `pr-snapshot:${userId}`;

export function readPrSnapshot(userId: string): PrSnapshot | null {
  try {
    const raw = localStorage.getItem(storageKey(userId));
    return raw ? (JSON.parse(raw) as PrSnapshot) : null;
  } catch {
    return null;
  }
}

export function writePrSnapshot(userId: string, snapshot: PrSnapshot): void {
  try {
    localStorage.setItem(storageKey(userId), JSON.stringify(snapshot));
  } catch {
    // storage blocked: the next visit just won't know what's new
  }
}

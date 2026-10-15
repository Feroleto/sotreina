import { useState } from 'react';

// module-scoped on purpose: lives as long as the tab, so a reload animates
// again but navigating back to an already-seen page doesn't
const seen = new Set<string>();

/** true only on the first mount of `key` in this tab session (pure, testable) */
export function claimFirstVisit(key: string): boolean {
  if (seen.has(key)) return false;
  seen.add(key);
  return true;
}

/** test-only: forget every claimed key */
export function resetFirstVisits(): void {
  seen.clear();
}

/**
 * Whether this mount is the first one for `key` in the session. Captured once
 * at mount (later re-renders keep the same answer), so an entrance animation
 * can safely read it as its `initial` state.
 */
export function useFirstVisit(key: string): boolean {
  const [first] = useState(() => claimFirstVisit(key));
  return first;
}

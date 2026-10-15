import { useEffect, useState } from 'react';

/**
 * `flag`, but only once it has stayed true for `delayMs`. A fetch that
 * answers faster than that never flashes a skeleton.
 */
export function useDelayedFlag(flag: boolean, delayMs = 150): boolean {
  const [delayed, setDelayed] = useState(false);
  const [prevFlag, setPrevFlag] = useState(flag);
  // reset during render (not in the effect) when the flag drops, so the
  // next true starts a fresh grace period
  if (flag !== prevFlag) {
    setPrevFlag(flag);
    if (!flag) setDelayed(false);
  }

  useEffect(() => {
    if (!flag) return;
    const id = window.setTimeout(() => setDelayed(true), delayMs);
    return () => window.clearTimeout(id);
  }, [flag, delayMs]);

  return flag && delayed;
}

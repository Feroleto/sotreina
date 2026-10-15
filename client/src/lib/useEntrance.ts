import { useEffect, useState } from 'react';
import { useFirstVisit } from './useFirstVisit';

/**
 * Value for a container's `data-enter` attribute; the entrance classes in
 * index.css (.chart-line, .chart-bar, .enter-rise…) only animate under it.
 * - `pending`: will animate, waiting for data or for the viewport
 * - `run`: animating right now (a short window, then back to idle)
 * - `idle`: no entrance — already seen this session, or reduced motion
 */
export type EntranceState = 'idle' | 'pending' | 'run';

// longer than the slowest entrance (chart line draw + area fade); after it
// the container drops to idle, so later data changes (period switch, new
// month) render instantly instead of re-animating
const ENTRANCE_WINDOW_MS = 1400;

function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  );
}

/**
 * First-visit-per-session entrance for a data block. `ready` holds the
 * entrance until the data is on screen; `inView` additionally holds it until
 * the container (`attach` it as its ref) scrolls into view — for cards below the fold.
 */
export function useEntrance<T extends Element = HTMLDivElement>(
  key: string,
  { ready = true, inView = false }: { ready?: boolean; inView?: boolean } = {},
) {
  const first = useFirstVisit(key);
  const [phase, setPhase] = useState<'armed' | 'done'>(() =>
    first && !prefersReducedMotion() ? 'armed' : 'done',
  );
  const [seen, setSeen] = useState(!inView);
  // the container, captured by a callback ref kept in state (not useRef):
  // it often mounts only after loading, and the observer has to attach
  // whenever it appears. Pass `attach` as the container's ref
  const [el, attach] = useState<T | null>(null);
  const running = phase === 'armed' && ready && seen;

  useEffect(() => {
    if (phase !== 'armed' || seen || !el) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setSeen(true);
          io.disconnect();
        }
      },
      { threshold: 0.25 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [phase, seen, el]);

  useEffect(() => {
    if (!running) return;
    const id = window.setTimeout(() => setPhase('done'), ENTRANCE_WINDOW_MS);
    return () => window.clearTimeout(id);
  }, [running]);

  const state: EntranceState = running ? 'run' : phase === 'armed' ? 'pending' : 'idle';
  return { attach, state };
}

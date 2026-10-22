import { useCallback, useEffect, useRef, useState } from 'react';
import { playBeep } from './restAudio';

const LAST_DURATION_KEY = 'restTimer:lastDuration';
const ACTIVE_KEY = 'restTimer:active';
const MUTED_KEY = 'restTimer:muted';
export const DEFAULT_DURATION_SEC = 90;
const TICK_MS = 250;

interface PersistedActive {
  endsAt: number;
  duration: number;
  // a routine's per-exercise rest (see startOverride) — absent in values
  // persisted before it existed, which reads as false
  overridden?: boolean;
}

export interface RestTimerSnapshot {
  isActive: boolean;
  remainingMs: number;
  duration: number;
}

function readLastDuration(): number {
  const raw = localStorage.getItem(LAST_DURATION_KEY);
  const parsed = raw ? Number(raw) : NaN;
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_DURATION_SEC;
}

function readPersistedActive(): PersistedActive | null {
  const raw = localStorage.getItem(ACTIVE_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as Partial<PersistedActive>;
    if (typeof parsed.endsAt !== 'number' || typeof parsed.duration !== 'number') return null;
    return { endsAt: parsed.endsAt, duration: parsed.duration, overridden: parsed.overridden === true };
  } catch {
    return null;
  }
}

// Plain, framework-free state machine — testable directly with
// vi.useFakeTimers() and no DOM (client/vitest.config.ts has no jsdom
// environment, same reason useTrainingMetrics.ts keeps its pure
// computeWeekMetrics() separate from the useMemo wrapper). The useRestTimer
// hook below only adds React state + setInterval + browser side effects
// (vibration/beep) on top of this.
export class RestTimerEngine {
  private endsAt: number | null = null;
  private duration: number;
  private overridden = false;

  constructor(now: number = Date.now()) {
    this.duration = readLastDuration();
    const persisted = readPersistedActive();
    if (persisted && persisted.endsAt > now) {
      // survives an accidental mid-rest page reload
      this.endsAt = persisted.endsAt;
      this.duration = persisted.duration;
      this.overridden = persisted.overridden === true;
    } else if (persisted) {
      // stale (already elapsed while the page was closed) — discard silently
      localStorage.removeItem(ACTIVE_KEY);
    }
  }

  getSnapshot(now: number = Date.now()): RestTimerSnapshot {
    if (this.endsAt === null) {
      return { isActive: false, remainingMs: 0, duration: this.duration };
    }
    return { isActive: true, remainingMs: Math.max(0, this.endsAt - now), duration: this.duration };
  }

  start(durationSeconds?: number, now: number = Date.now()): void {
    const dur = durationSeconds ?? readLastDuration();
    this.duration = dur;
    this.endsAt = now + dur * 1000;
    this.overridden = false;
    localStorage.setItem(LAST_DURATION_KEY, String(dur));
    localStorage.setItem(ACTIVE_KEY, JSON.stringify({ endsAt: this.endsAt, duration: dur }));
  }

  // a routine's per-exercise rest (WorkoutTemplateExercise.restSeconds):
  // runs for that long without becoming the remembered default, so the next
  // exercise without its own rest still gets the user's usual length — and
  // ±15s on it doesn't touch that default either
  startOverride(durationSeconds: number, now: number = Date.now()): void {
    this.duration = durationSeconds;
    this.endsAt = now + durationSeconds * 1000;
    this.overridden = true;
    localStorage.setItem(
      ACTIVE_KEY,
      JSON.stringify({ endsAt: this.endsAt, duration: durationSeconds, overridden: true }),
    );
  }

  // delta may be negative (the -15s button) — remaining time is floored at 0,
  // never negative; also updates the remembered "last duration" so the next
  // set already suggests the adjusted value
  addSeconds(deltaSeconds: number, now: number = Date.now()): void {
    if (this.endsAt === null) return;
    const nextEndsAt = Math.max(now, this.endsAt + deltaSeconds * 1000);
    const nextDuration = Math.max(0, Math.round((nextEndsAt - now) / 1000));
    this.endsAt = nextEndsAt;
    this.duration = nextDuration;
    if (!this.overridden) localStorage.setItem(LAST_DURATION_KEY, String(nextDuration));
    localStorage.setItem(
      ACTIVE_KEY,
      JSON.stringify({ endsAt: nextEndsAt, duration: nextDuration, overridden: this.overridden }),
    );
  }

  skip(): void {
    this.stop();
  }

  // same state transition as skip() — kept as a separate method so the hook
  // can layer vibration/sound on top only for a natural completion, not a
  // manual skip, without the engine itself knowing about browser APIs
  finish(): void {
    this.stop();
  }

  private stop(): void {
    this.endsAt = null;
    // an override's length was never the default: idle shows the default again
    if (this.overridden) this.duration = readLastDuration();
    this.overridden = false;
    localStorage.removeItem(ACTIVE_KEY);
  }
}

function readMuted(): boolean {
  return typeof localStorage !== 'undefined' && localStorage.getItem(MUTED_KEY) === 'true';
}

// single timer per hook instance — callers must mount exactly one
// useRestTimer() per workout session (WorkoutSession.tsx), never per exercise,
// so there is only ever one rest countdown running at a time
export function useRestTimer() {
  const engineRef = useRef<RestTimerEngine | null>(null);
  if (!engineRef.current) engineRef.current = new RestTimerEngine();

  const [snapshot, setSnapshot] = useState<RestTimerSnapshot>(() => engineRef.current!.getSnapshot());
  const [muted, setMuted] = useState<boolean>(() => readMuted());
  const mutedRef = useRef(muted);

  useEffect(() => {
    mutedRef.current = muted;
  }, [muted]);

  useEffect(() => {
    const engine = engineRef.current!;
    const id = setInterval(() => {
      const next = engine.getSnapshot();
      if (next.isActive && next.remainingMs <= 0) {
        engine.finish();
        setSnapshot(engine.getSnapshot());
        if (navigator.vibrate) navigator.vibrate([200, 100, 200]);
        if (!mutedRef.current) playBeep();
      } else {
        setSnapshot(next);
      }
    }, TICK_MS);
    return () => clearInterval(id);
  }, []);

  const start = useCallback((durationSeconds?: number) => {
    const engine = engineRef.current!;
    engine.start(durationSeconds);
    setSnapshot(engine.getSnapshot());
  }, []);

  const startOverride = useCallback((durationSeconds: number) => {
    const engine = engineRef.current!;
    engine.startOverride(durationSeconds);
    setSnapshot(engine.getSnapshot());
  }, []);

  const addSeconds = useCallback((delta: number) => {
    const engine = engineRef.current!;
    engine.addSeconds(delta);
    setSnapshot(engine.getSnapshot());
  }, []);

  const skip = useCallback(() => {
    const engine = engineRef.current!;
    engine.skip();
    setSnapshot(engine.getSnapshot());
  }, []);

  const toggleMuted = useCallback(() => {
    setMuted((m) => {
      const next = !m;
      localStorage.setItem(MUTED_KEY, String(next));
      return next;
    });
  }, []);

  return { ...snapshot, muted, start, startOverride, addSeconds, skip, toggleMuted };
}

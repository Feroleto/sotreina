import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { RestTimerEngine, DEFAULT_DURATION_SEC } from './useRestTimer';

// client/vitest.config.ts has no jsdom environment (see useTrainingMetrics.ts/
// lapBoundaryMath.ts for the same pattern) — RestTimerEngine is a plain
// class with no React/DOM dependency, so it's tested directly here instead
// of rendering the useRestTimer hook. localStorage is stubbed with a bare
// in-memory Storage since Node doesn't provide one.
function createMemoryStorage(): Storage {
  const store = new Map<string, string>();
  return {
    getItem: (key: string) => (store.has(key) ? (store.get(key) as string) : null),
    setItem: (key: string, value: string) => {
      store.set(key, value);
    },
    removeItem: (key: string) => {
      store.delete(key);
    },
    clear: () => store.clear(),
    key: (index: number) => Array.from(store.keys())[index] ?? null,
    get length() {
      return store.size;
    },
  } as Storage;
}

describe('RestTimerEngine', () => {
  beforeEach(() => {
    vi.stubGlobal('localStorage', createMemoryStorage());
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-07-20T12:00:00Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('start() sets endsAt and remainingMs decreases as fake time advances', () => {
    const engine = new RestTimerEngine();
    engine.start(90);

    expect(engine.getSnapshot().isActive).toBe(true);
    expect(engine.getSnapshot().remainingMs).toBe(90_000);

    vi.advanceTimersByTime(30_000);
    expect(engine.getSnapshot().remainingMs).toBe(60_000);

    vi.advanceTimersByTime(60_000);
    expect(engine.getSnapshot().remainingMs).toBe(0);
  });

  it('defaults to DEFAULT_DURATION_SEC the first time, before anything is persisted', () => {
    const engine = new RestTimerEngine();
    engine.start();
    expect(engine.getSnapshot().duration).toBe(DEFAULT_DURATION_SEC);
  });

  it('remembers the last duration used across instances (localStorage)', () => {
    const engine1 = new RestTimerEngine();
    engine1.start(120);
    vi.advanceTimersByTime(200_000); // elapse fully so the next instance starts fresh

    const engine2 = new RestTimerEngine();
    engine2.start(); // no explicit duration -> falls back to the remembered value
    expect(engine2.getSnapshot().duration).toBe(120);
  });

  it('addSeconds(-15) floors remainingMs at 0, never negative', () => {
    const engine = new RestTimerEngine();
    engine.start(10);
    engine.addSeconds(-15);

    expect(engine.getSnapshot().remainingMs).toBe(0);
    expect(engine.getSnapshot().duration).toBe(0);
  });

  it('addSeconds(+15) extends remaining time and updates the remembered duration', () => {
    const engine = new RestTimerEngine();
    engine.start(90);
    engine.addSeconds(15);
    expect(engine.getSnapshot().remainingMs).toBe(105_000);

    vi.advanceTimersByTime(200_000); // elapse fully, isolate the "remembered" check

    const engine2 = new RestTimerEngine();
    engine2.start();
    expect(engine2.getSnapshot().duration).toBe(105);
  });

  it('resumes from a persisted restTimer:active when endsAt is still in the future', () => {
    const engine1 = new RestTimerEngine();
    engine1.start(90);
    vi.advanceTimersByTime(30_000); // 60s left

    const engine2 = new RestTimerEngine(); // simulates a page reload
    const snap = engine2.getSnapshot();
    expect(snap.isActive).toBe(true);
    expect(snap.remainingMs).toBe(60_000);
  });

  it('discards a persisted restTimer:active silently when endsAt is already in the past', () => {
    const engine1 = new RestTimerEngine();
    engine1.start(10);
    vi.advanceTimersByTime(20_000); // already elapsed

    const engine2 = new RestTimerEngine();
    expect(engine2.getSnapshot().isActive).toBe(false);
    expect(localStorage.getItem('restTimer:active')).toBeNull();
  });

  it('skip() clears the active state and the persisted restTimer:active key', () => {
    const engine = new RestTimerEngine();
    engine.start(90);
    expect(localStorage.getItem('restTimer:active')).not.toBeNull();

    engine.skip();

    expect(engine.getSnapshot().isActive).toBe(false);
    expect(engine.getSnapshot().remainingMs).toBe(0);
    expect(localStorage.getItem('restTimer:active')).toBeNull();
  });

  describe('startOverride (a routine\'s per-exercise rest)', () => {
    it('runs for the given length without changing the remembered default', () => {
      const engine = new RestTimerEngine();
      engine.start(90);
      engine.skip();

      engine.startOverride(180);
      expect(engine.getSnapshot()).toMatchObject({ isActive: true, remainingMs: 180_000, duration: 180 });

      engine.finish();
      // idle shows the default again, and a plain start uses it
      expect(engine.getSnapshot().duration).toBe(90);
      engine.start();
      expect(engine.getSnapshot().remainingMs).toBe(90_000);
    });

    it('±15s on an override does not leak into the default', () => {
      const engine = new RestTimerEngine();
      engine.start(60);
      engine.skip();

      engine.startOverride(120);
      engine.addSeconds(15);
      expect(engine.getSnapshot().remainingMs).toBe(135_000);
      engine.skip();
      expect(new RestTimerEngine().getSnapshot().duration).toBe(60);
    });

    it('survives a reload still marked as an override', () => {
      const engine = new RestTimerEngine();
      engine.start(60);
      engine.skip();
      engine.startOverride(150);

      const reloaded = new RestTimerEngine();
      expect(reloaded.getSnapshot()).toMatchObject({ isActive: true, duration: 150 });
      reloaded.addSeconds(15);
      reloaded.skip();
      expect(reloaded.getSnapshot().duration).toBe(60);
    });
  });
});

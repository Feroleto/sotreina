import { beforeEach, describe, expect, it } from 'vitest';
import { claimFirstVisit, resetFirstVisits } from './useFirstVisit';

describe('claimFirstVisit', () => {
  beforeEach(() => resetFirstVisits());

  it('is true only the first time a key is claimed', () => {
    expect(claimFirstVisit('run/overview')).toBe(true);
    expect(claimFirstVisit('run/overview')).toBe(false);
    expect(claimFirstVisit('run/overview')).toBe(false);
  });

  it('tracks keys independently', () => {
    expect(claimFirstVisit('a')).toBe(true);
    expect(claimFirstVisit('b')).toBe(true);
    expect(claimFirstVisit('a')).toBe(false);
  });
});

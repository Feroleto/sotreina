import { describe, it, expect } from 'vitest';
import {
  addDays,
  localDateString,
  localDayBoundaries,
  resolveTimeZone,
  zonedMidnight,
} from 'src/common/timezone';

describe('resolveTimeZone', () => {
  it('accepts a valid IANA zone', () => {
    expect(resolveTimeZone('America/Sao_Paulo')).toBe('America/Sao_Paulo');
  });

  it('falls back to UTC for a missing, unknown or oversized value', () => {
    expect(resolveTimeZone(undefined)).toBe('UTC');
    expect(resolveTimeZone('Mars/Olympus_Mons')).toBe('UTC');
    expect(resolveTimeZone("UTC'; DROP TABLE users;--")).toBe('UTC');
    expect(resolveTimeZone('x'.repeat(100))).toBe('UTC');
  });

  it('takes the first value of a repeated header', () => {
    expect(resolveTimeZone(['Europe/Lisbon', 'UTC'])).toBe('Europe/Lisbon');
  });
});

describe('localDateString', () => {
  it('returns the calendar day in the zone, not in UTC', () => {
    // 23:30 BRT on the 20th is already the 21st in UTC
    const at = new Date('2026-10-21T02:30:00.000Z');
    expect(localDateString(at, 'America/Sao_Paulo')).toBe('2026-10-20');
    expect(localDateString(at, 'UTC')).toBe('2026-10-21');
  });
});

describe('addDays', () => {
  it('crosses month and year ends', () => {
    expect(addDays('2026-10-31', 1)).toBe('2026-11-01');
    expect(addDays('2027-01-01', -1)).toBe('2026-12-31');
    expect(addDays('2026-10-21', -6)).toBe('2026-10-15');
  });
});

describe('zonedMidnight / localDayBoundaries', () => {
  it('converts local midnight to the UTC instant', () => {
    expect(zonedMidnight('2026-10-21', 'America/Sao_Paulo').toISOString()).toBe(
      '2026-10-21T03:00:00.000Z',
    );
    expect(zonedMidnight('2026-10-21', 'Asia/Tokyo').toISOString()).toBe(
      '2026-10-20T15:00:00.000Z',
    );
    expect(zonedMidnight('2026-10-21', 'UTC').toISOString()).toBe('2026-10-21T00:00:00.000Z');
  });

  it('produces a 23h day across a DST spring-forward', () => {
    // Europe/Lisbon moves 01:00 → 02:00 on 2026-03-29
    const { start, end } = localDayBoundaries('2026-03-29', 'Europe/Lisbon');
    expect(start.toISOString()).toBe('2026-03-29T00:00:00.000Z');
    expect(end.toISOString()).toBe('2026-03-29T23:00:00.000Z');
  });
});

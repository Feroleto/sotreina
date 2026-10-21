// Day boundaries in the caller's own time zone. The client sends its IANA
// zone in X-Time-Zone (see client/src/lib/api.ts); anything missing or
// unknown falls back to UTC — the old behavior, and what a client that never
// sends the header (the iOS app) still gets. Plain Intl, no tz library: the
// only operation needed is "what UTC instant is local midnight of date D"

export const DEFAULT_TIME_ZONE = 'UTC';

const DATE_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

export function resolveTimeZone(header?: string | string[]): string {
  const value = Array.isArray(header) ? header[0] : header;
  if (!value || value.length > 64) return DEFAULT_TIME_ZONE;
  try {
    // throws RangeError on an unknown zone
    return new Intl.DateTimeFormat('en-US', { timeZone: value }).resolvedOptions().timeZone;
  } catch {
    return DEFAULT_TIME_ZONE;
  }
}

/** local calendar date ("YYYY-MM-DD") of an instant in `timeZone` */
export function localDateString(at: Date, timeZone: string): string {
  // en-CA formats dates as YYYY-MM-DD
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(at);
}

/** "YYYY-MM-DD" shifted by `days` calendar days */
export function addDays(date: string, days: number): string {
  const [, y, m, d] = DATE_RE.exec(date)!;
  return new Date(Date.UTC(Number(y), Number(m) - 1, Number(d) + days)).toISOString().slice(0, 10);
}

// offset of `timeZone` from UTC at instant `at`, in ms (−3h for São Paulo)
function offsetMs(timeZone: string, at: Date): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
  }).formatToParts(at);
  const get = (type: string) => Number(parts.find((p) => p.type === type)!.value);
  const asUtc = Date.UTC(
    get('year'),
    get('month') - 1,
    get('day'),
    get('hour'),
    get('minute'),
    get('second'),
  );
  return asUtc - Math.floor(at.getTime() / 1000) * 1000;
}

/** the UTC instant of local midnight of `date` in `timeZone` */
export function zonedMidnight(date: string, timeZone: string): Date {
  const [, y, m, d] = DATE_RE.exec(date)!;
  const wallClock = Date.UTC(Number(y), Number(m) - 1, Number(d));
  let instant = wallClock - offsetMs(timeZone, new Date(wallClock));
  // second pass: the offset at the guess can differ across a DST change
  const corrected = offsetMs(timeZone, new Date(instant));
  if (wallClock - corrected !== instant) instant = wallClock - corrected;
  return new Date(instant);
}

/** [local midnight of `date`, local midnight of the next day) as UTC instants */
export function localDayBoundaries(date: string, timeZone: string): { start: Date; end: Date } {
  return { start: zonedMidnight(date, timeZone), end: zonedMidnight(addDays(date, 1), timeZone) };
}

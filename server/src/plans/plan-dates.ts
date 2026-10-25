import { addDays } from '../common/timezone';

// Plan dates are local calendar days as "YYYY-MM-DD" strings: they compare
// lexicographically and never carry a time or a zone. "Today" comes from the
// caller's X-Time-Zone (localDateString), never from the server clock's zone

function utcNoonOf(date: string): Date {
  return new Date(`${date}T12:00:00.000Z`);
}

/** ISO weekday: 1 = Monday … 7 = Sunday */
export function isoWeekday(date: string): number {
  const day = utcNoonOf(date).getUTCDay();
  return day === 0 ? 7 : day;
}

export function mondayOf(date: string): string {
  return addDays(date, 1 - isoWeekday(date));
}

/** the editable window: Monday of the current week through Sunday of the next */
export function planWindow(today: string): { from: string; to: string } {
  const from = mondayOf(today);
  return { from, to: addDays(from, 13) };
}

/** every day from `from` to `to`, both inclusive */
export function daysInRange(from: string, to: string): string[] {
  const days: string[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) days.push(d);
  return days;
}

/** a "YYYY-MM-DD" as the Date Prisma stores in a @db.Date column */
export function toDbDate(date: string): Date {
  return new Date(`${date}T00:00:00.000Z`);
}

export function fromDbDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

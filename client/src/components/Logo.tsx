import { cn } from '@/lib/utils';

// "Pulso" mark (Claude Design turn 20a): one heartbeat stroke ending in the
// accent dot of "right now". The stroke follows currentColor so the same
// mark works on light, dark and the always-dark login hero; the dot is
// always the accent. Path/dot geometry lives in a 48-unit box, shared with
// the favicon and the PWA icons in public/
export const LOGO_PATH = 'M3 27h10l4-14 7.5 24 4.5-10h4';

export function LogoMark({ className }: { className?: string }) {
  // heavier stroke + bigger dot than the 104px hero version: at UI sizes
  // the design's small-size weights keep the line from going hairline
  return (
    <svg viewBox="0 0 48 48" aria-hidden className={cn('flex-none', className)}>
      <path
        d={LOGO_PATH}
        fill="none"
        stroke="currentColor"
        strokeWidth={5}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx={41} cy={27} r={4.4} fill="var(--acc)" />
    </svg>
  );
}

// 30px slot, same footprint as the old "ST" tile, so lockups and the
// collapsed sidebar keep their alignment
export function Logo({ className }: { className?: string }) {
  return (
    <span
      className={cn(
        'flex size-[30px] flex-none items-center justify-center',
        className,
      )}
    >
      <LogoMark className="size-[26px]" />
    </span>
  );
}

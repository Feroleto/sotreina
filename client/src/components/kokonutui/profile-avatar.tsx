import { cn } from '@/lib/utils';
import { avatarMediumUrl } from '@/lib/avatarUrl';

// the dropdown's closed trigger, split out of profile-dropdown.tsx so the
// header can render it before (and without) the Motion-using chunk: the
// lazy fallback and the loaded trigger share this exact markup, so the swap
// on first tap doesn't move a pixel

/** 44×44 touch target, the 34px avatar aligned to its right edge */
export const TRIGGER_CLASS =
  'flex h-11 w-11 flex-none cursor-pointer items-center justify-end rounded-full outline-none focus-visible:ring-2 focus-visible:ring-ring';

export function ProfileAvatar({
  url,
  initials,
  size,
  className,
}: {
  url?: string | null;
  initials: string;
  /** px — set inline (not a class) since the dropdown's FLIP measures it */
  size: number;
  className?: string;
}) {
  const style = { width: size, height: size };
  if (url) {
    return (
      <img
        src={avatarMediumUrl(url)}
        alt=""
        width={size}
        height={size}
        style={style}
        draggable={false}
        className={cn(
          'block flex-none select-none rounded-full object-cover outline outline-1 -outline-offset-1 outline-black/10 dark:outline-white/10',
          className,
        )}
      />
    );
  }
  return (
    <span
      aria-hidden="true"
      style={style}
      className={cn(
        'flex flex-none select-none items-center justify-center rounded-full bg-chip font-semibold text-foreground',
        className,
      )}
    >
      {initials}
    </span>
  );
}

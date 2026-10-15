import { useState } from 'react';
import type { ReactNode } from 'react';
import {
  AnimatePresence,
  LazyMotion,
  MotionConfig,
  m,
  useReducedMotion,
} from 'motion/react';
import type { TargetAndTransition } from 'motion/react';
import { useIsMobile } from '@/lib/useIsMobile';
import { DUR, EASE_DRAWER, EASE_OUT } from '@/lib/motion';
import { cn } from '@/lib/utils';

// Motion is only ever used inside lazy page chunks, so its provider lives
// here rather than in main.tsx — there it would drag Motion's core into the
// entry chunk the logged-out LoginPage visitor downloads. The animation
// features load async on top (lib/motionFeatures.ts)
const loadMotionFeatures = () =>
  import('@/lib/motionFeatures').then((mod) => mod.default);

type Mode = 'push' | 'fade' | 'reduce';
type Custom = { dir: 1 | -1; mode: Mode };

// entering screen: where it comes from
function enterFrom({ dir, mode }: Custom): TargetAndTransition {
  // the entering screen paints above the leaving one (which popLayout has
  // made absolute) only while both exist — see `enter`'s transitionEnd
  if (mode === 'reduce') return { opacity: 0, zIndex: 1 };
  if (mode === 'fade')
    return { opacity: 0, transform: 'translateY(8px)', zIndex: 1 };
  // push: a deeper screen slides in from the right; going back, the screen
  // underneath returns from its slightly-receded spot
  return dir === 1
    ? { transform: 'translateX(100%)', zIndex: 1 }
    : { transform: 'translateX(-20%)', opacity: 0.7, zIndex: 1 };
}

// leaving screen: where it goes — mirrors enterFrom, so back retraces push
function exitTo({ dir, mode }: Custom): TargetAndTransition {
  if (mode !== 'push') {
    // desktop: no crossfade between two transparent panels (text ghosting),
    // the old one just goes and the new one rises in
    return { opacity: 0, transition: { duration: 0 } };
  }
  return dir === 1
    ? {
        transform: 'translateX(-20%)',
        opacity: 0.7,
        transition: { duration: DUR.push, ease: EASE_DRAWER },
      }
    : {
        // going back, the detail sliding away stays on top of the list
        zIndex: 2,
        transform: 'translateX(100%)',
        transition: {
          duration: DUR.page,
          ease: EASE_DRAWER,
          zIndex: { duration: 0 },
        },
      };
}

const variants = {
  initial: enterFrom,
  // Motion lands a 'none' target as an identity translate, which still makes
  // the wrapper the containing block of every fixed overlay inside the
  // screen (sheets, lap editor, scanner) — so transitionEnd really clears it.
  // Same for z-index: a lasting one is a stacking context that would trap
  // those overlays under the app bar
  enter: ({ dir, mode }: Custom): TargetAndTransition => ({
    transform: 'none',
    opacity: 1,
    transitionEnd: { transform: 'none', zIndex: 'auto' },
    transition:
      mode === 'push'
        ? { duration: dir === 1 ? DUR.push : DUR.page, ease: EASE_DRAWER }
        : { duration: DUR.base, ease: EASE_OUT },
  }),
  exit: exitTo,
};

/**
 * List → detail drill-down. Swap `children` and bump `depth` (0 = list,
 * 1 = detail, 2 = detail of the detail…); `viewKey` identifies the screen.
 * Mobile pushes sideways like iOS (back exits to the right); desktop fades
 * up; reduced motion only fades.
 */
export default function DrillStack({
  depth,
  viewKey,
  children,
  className,
  screenClassName,
}: {
  depth: number;
  viewKey: string;
  children: ReactNode;
  /** on the clipping container — e.g. a negative margin to bleed past the
      parent's padding so a push isn't cut short of the screen edge */
  className?: string;
  /** on each screen — e.g. the padding the bleed took away */
  screenClassName?: string;
}) {
  const isMobile = useIsMobile();
  const reduce = useReducedMotion();
  const [track, setTrack] = useState<{ depth: number; dir: 1 | -1 }>({
    depth,
    dir: 1,
  });
  if (depth !== track.depth) {
    setTrack({ depth, dir: depth > track.depth ? 1 : -1 });
  }
  const custom: Custom = {
    dir: depth === track.depth ? track.dir : depth > track.depth ? 1 : -1,
    mode: reduce ? 'reduce' : isMobile ? 'push' : 'fade',
  };

  return (
    // clip, not hidden: no scroll container, so sticky headers inside keep
    // working while the off-screen half of a push stays invisible
    <LazyMotion features={loadMotionFeatures} strict>
      <MotionConfig reducedMotion="user">
        <div className={cn('relative overflow-x-clip', className)}>
          <AnimatePresence initial={false} mode="popLayout" custom={custom}>
            <m.div
              key={viewKey}
              custom={custom}
              variants={variants}
              initial="initial"
              animate="enter"
              exit="exit"
              // opaque on mobile so the receding screen doesn't show through
              className={cn('relative max-md:bg-page-bg', screenClassName)}
            >
              {children}
            </m.div>
          </AnimatePresence>
        </div>
      </MotionConfig>
    </LazyMotion>
  );
}

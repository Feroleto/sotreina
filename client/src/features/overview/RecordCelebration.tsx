import type { ReactNode } from 'react';
import { m, useReducedMotion } from 'motion/react';
import MotionProvider from '@/components/MotionProvider';
import { SPRING_CELEBRATE } from '@/lib/motion';

// lazy-loaded by PersonalRecordsCard only when a new record exists, so the
// Overview doesn't pull Motion on every visit just for a rare moment.
// Starts after the card's own entrance (rows rise in first)
const DELAY = 0.5;

function Celebration({ children }: { children: ReactNode }) {
  const reduce = useReducedMotion();
  return (
    <m.div
      className="relative flex-none"
      initial={reduce ? false : { scale: 0.6, opacity: 0 }}
      animate={{ scale: 1, opacity: 1 }}
      transition={{ ...SPRING_CELEBRATE, delay: DELAY }}
    >
      {children}
      {/* short accent glow, opacity-only on its own layer */}
      {!reduce && (
        <m.div
          aria-hidden
          className="pointer-events-none absolute -inset-[3px] rounded-[12px]"
          style={{
            boxShadow:
              '0 0 0 1.5px var(--acc), 0 0 18px color-mix(in oklab, var(--acc) 45%, transparent)',
          }}
          initial={{ opacity: 0 }}
          animate={{ opacity: [0, 1, 0] }}
          transition={{
            duration: 1.1,
            times: [0, 0.25, 1],
            ease: 'easeOut',
            delay: DELAY,
          }}
        />
      )}
    </m.div>
  );
}

/** wraps a record's distance chip: pops in with a brief glow, once */
export default function RecordCelebration({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <MotionProvider>
      <Celebration>{children}</Celebration>
    </MotionProvider>
  );
}

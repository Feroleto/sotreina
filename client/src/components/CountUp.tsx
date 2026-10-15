import { useEffect, useRef } from 'react';
import { animate, m, useMotionValue, useTransform } from 'motion/react';
import { EASE_OUT, SPRING_CELEBRATE } from '@/lib/motion';

/**
 * Counts 0 → `value` once — for rare summary/celebration screens only, never
 * everyday KPIs. With `celebrate` false (already seen, reduced motion) it
 * renders the final value directly. `pop` adds a spring settle when the
 * count lands. Needs a MotionProvider ancestor.
 */
export default function CountUp({
  value,
  format,
  delay = 0,
  celebrate,
  pop = false,
  className,
}: {
  value: number;
  format: (v: number) => string;
  delay?: number;
  celebrate: boolean;
  pop?: boolean;
  className?: string;
}) {
  const mv = useMotionValue(celebrate ? 0 : value);
  // a MotionValue child updates the text node directly — no React render
  // per frame
  const text = useTransform(mv, format);
  const ref = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (!celebrate) {
      mv.set(value);
      return;
    }
    let settle: ReturnType<typeof animate> | undefined;
    const count = animate(mv, value, { duration: 0.8, ease: EASE_OUT, delay });
    if (pop) {
      void count.then(() => {
        if (ref.current) {
          settle = animate(ref.current, { scale: [1.12, 1] }, SPRING_CELEBRATE);
        }
      });
    }
    return () => {
      count.stop();
      settle?.stop();
    };
  }, [celebrate, delay, mv, pop, value]);

  return (
    <m.span ref={ref} className={pop ? `inline-block ${className ?? ''}` : className}>
      {text}
    </m.span>
  );
}

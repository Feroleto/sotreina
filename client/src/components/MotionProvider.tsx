import type { ReactNode } from 'react';
import { LazyMotion, MotionConfig } from 'motion/react';

// Motion is only ever used inside lazy page chunks, so its provider wraps
// each Motion-using subtree instead of living in main.tsx — there it would
// drag Motion's core into the entry chunk the logged-out LoginPage visitor
// downloads. The animation features load async on top
// (lib/motionFeatures.ts); nesting providers is fine.
const loadMotionFeatures = () =>
  import('@/lib/motionFeatures').then((mod) => mod.default);

export default function MotionProvider({ children }: { children: ReactNode }) {
  return (
    // strict: a stray full `motion.*` component throws instead of silently
    // bundling every feature
    <LazyMotion features={loadMotionFeatures} strict>
      <MotionConfig reducedMotion="user">{children}</MotionConfig>
    </LazyMotion>
  );
}

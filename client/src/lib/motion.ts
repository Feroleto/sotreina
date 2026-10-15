// Motion tokens — JS mirror of the --motion-ease-* custom properties in
// index.css. Every Motion animation in the app picks its curve, duration and
// spring from here; don't inline new values in components.

/** strong ease-out: entering/exiting UI */
export const EASE_OUT = [0.23, 1, 0.32, 1] as const;
/** strong ease-in-out: something moving/morphing on screen */
export const EASE_IN_OUT = [0.77, 0, 0.175, 1] as const;
/** iOS-like drawer/push curve (Ionic) */
export const EASE_DRAWER = [0.32, 0.72, 0, 1] as const;

/** seconds, as Motion expects */
export const DUR = {
  /** exits, press feedback */
  fast: 0.15,
  /** default UI enter */
  base: 0.2,
  /** page-level crossfade */
  page: 0.25,
  /** mobile push (enter) */
  push: 0.3,
} as const;

/** rare celebration moments only (PR, workout summary) — never everyday UI */
export const SPRING_CELEBRATE = {
  type: 'spring',
  duration: 0.5,
  bounce: 0.2,
} as const;

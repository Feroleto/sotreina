import { createContext, useContext, useEffect } from 'react';

// mobile chrome (in-flow section header + floating tab bar) steps aside for
// full-screen sub-flows — an activity detail, a live workout, the routine
// editor — which bring their own back button and often a fixed bottom action
// bar the pill would cover. A counter, not a boolean: nested drill-downs
// (routine → exercise) each hold their own claim while mounted
/** App.tsx provides the counter's bump; claims register via useHideMobileChrome */
export const ChromeBumpContext = createContext<(delta: 1 | -1) => void>(
  () => {},
);

/** hides the mobile header + tab bar while `hidden` is true and the caller is mounted */
export function useHideMobileChrome(hidden: boolean) {
  const bump = useContext(ChromeBumpContext);
  useEffect(() => {
    if (!hidden) return;
    bump(1);
    return () => bump(-1);
  }, [hidden, bump]);
}

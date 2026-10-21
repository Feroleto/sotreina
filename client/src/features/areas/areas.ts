import type { Area } from '@/lib/types';

export interface AreaDef {
  id: Area;
  /** NAV_SECTIONS item id / MobileTabId of the area */
  navId: 'run' | 'gym' | 'diet';
  /** 'nav' namespace, short name ("Corrida", "Treino", "Dieta") */
  labelKey: string;
  /** 'onboarding' namespace, one-line description for the picker */
  descKey: string;
  /** 24×24 stroke path, same icons as the mobile tab bar */
  icon: string;
}

/** canonical order — the server stores enabledAreas in this order too */
export const AREAS: AreaDef[] = [
  {
    id: 'RUN',
    navId: 'run',
    labelKey: 'tabs.run',
    descKey: 'areas.runDesc',
    icon: 'M3 12h4l2-5 4 10 2-5h6',
  },
  {
    id: 'GYM',
    navId: 'gym',
    labelKey: 'tabs.gym',
    descKey: 'areas.gymDesc',
    icon: 'M6 8v8M3.5 10v4M18 8v8M20.5 10v4M6 12h12',
  },
  {
    id: 'DIET',
    navId: 'diet',
    labelKey: 'tabs.diet',
    descKey: 'areas.dietDesc',
    icon: 'M12 4.5a7.5 7.5 0 110 15 7.5 7.5 0 010-15zM12 8v4l2.5 2',
  },
];

/** area owning a nav item / mobile tab id, null for Hoje, Perfil, etc */
export function areaOfNavId(navId: string | null): Area | null {
  return AREAS.find((a) => a.navId === navId)?.id ?? null;
}

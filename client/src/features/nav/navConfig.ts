import {
  Activity,
  Bike,
  Dumbbell,
  LayoutGrid,
  Utensils,
  Waves,
  type LucideIcon,
} from 'lucide-react';

export type PageId =
  | 'overview'
  | 'run/overview'
  | 'run/activities'
  | 'run/analysis'
  | 'gym/overview'
  | 'gym/workouts'
  | 'gym/history'
  | 'diet/overview'
  | 'diet/history'
  | 'profile';

export const DEFAULT_PAGE: PageId = 'run/activities';

/** localStorage key holding the persisted active page */
export const ACTIVE_PAGE_KEY = 'active-page';

export interface NavSubItem {
  id: PageId;
  labelKey: string;
  disabled?: boolean;
}

export interface NavItem {
  id: string;
  labelKey: string;
  icon: LucideIcon;
  /** page navigated to when the item itself (not a sub-item) is clicked */
  page?: PageId;
  subs?: NavSubItem[];
  disabled?: boolean;
  badgeKey?: string;
}

export interface NavSection {
  titleKey?: string;
  items: NavItem[];
}

export const NAV_SECTIONS: NavSection[] = [
  {
    items: [
      {
        id: 'overview',
        labelKey: 'sections.overview',
        icon: LayoutGrid,
        page: 'overview',
      },
    ],
  },
  {
    titleKey: 'sections.sportsTitle',
    items: [
      {
        id: 'run',
        labelKey: 'sections.run',
        icon: Activity,
        page: 'run/overview',
        subs: [
          { id: 'run/overview', labelKey: 'sections.runOverview' },
          { id: 'run/activities', labelKey: 'sections.runActivities' },
          {
            id: 'run/analysis',
            labelKey: 'sections.runAnalysis',
            disabled: true,
          },
        ],
      },
      {
        id: 'gym',
        labelKey: 'sections.gym',
        icon: Dumbbell,
        page: 'gym/overview',
        subs: [
          { id: 'gym/overview', labelKey: 'sections.gymOverview' },
          { id: 'gym/workouts', labelKey: 'sections.gymWorkouts' },
          { id: 'gym/history', labelKey: 'sections.gymHistory' },
        ],
      },
      {
        id: 'diet',
        labelKey: 'sections.diet',
        icon: Utensils,
        page: 'diet/overview',
        subs: [
          { id: 'diet/overview', labelKey: 'sections.dietOverview' },
          { id: 'diet/history', labelKey: 'sections.dietHistory' },
        ],
      },
      {
        id: 'cycling',
        labelKey: 'sections.cycling',
        icon: Bike,
        disabled: true,
        badgeKey: 'badges.upcoming',
      },
      {
        id: 'swimming',
        labelKey: 'sections.swimming',
        icon: Waves,
        disabled: true,
        badgeKey: 'badges.upcoming',
      },
    ],
  },
];

/** app-bar title (mobile) per page — keys live in the 'nav' namespace */
export const MOBILE_TITLE_KEYS: Record<PageId, string> = {
  overview: 'sections.overview',
  'run/overview': 'sections.overview',
  'run/activities': 'sections.runActivities',
  'run/analysis': 'sections.runAnalysis',
  'gym/overview': 'sections.gymOverview',
  'gym/workouts': 'sections.gymWorkouts',
  'gym/history': 'sections.gymHistory',
  'diet/overview': 'sections.dietOverview',
  'diet/history': 'sections.dietHistory',
  profile: 'profile.title',
};

/** id of the section-parent whose subs should be revealed, given the active page */
export function activeParentId(page: PageId): string | null {
  for (const section of NAV_SECTIONS) {
    for (const item of section.items) {
      if (item.page === page) return item.id;
      if (item.subs?.some((s) => s.id === page)) return item.id;
    }
  }
  return null;
}

/** pages whose nav entry is temporarily disabled — code stays intact, just unreachable */
export const DISABLED_PAGES: ReadonlySet<PageId> = new Set(
  NAV_SECTIONS.flatMap((section) =>
    section.items.flatMap((item) => [
      ...(item.disabled && item.page ? [item.page] : []),
      ...(item.subs?.filter((s) => s.disabled).map((s) => s.id) ?? []),
    ]),
  ),
);

export function isPageDisabled(page: PageId): boolean {
  return DISABLED_PAGES.has(page);
}

export function isKnownPage(value: string | null): value is PageId {
  return (
    value === 'overview' ||
    value === 'run/overview' ||
    value === 'run/activities' ||
    value === 'run/analysis' ||
    value === 'gym/overview' ||
    value === 'gym/workouts' ||
    value === 'gym/history' ||
    value === 'diet/overview' ||
    value === 'diet/history' ||
    value === 'profile'
  );
}

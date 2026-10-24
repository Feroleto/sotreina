import { useTranslation } from 'react-i18next';
import { cn } from '@/lib/utils';
import type { ThemePref } from '@/lib/theme';
import { useAuth } from '@/features/auth/AuthContext';
import { ProfileMenu } from './ProfileMenu';
import {
  MOBILE_TABS,
  activeParentId,
  mobileSubPages,
  mobileTabsFor,
  type MobileTab,
  type MobileTabId,
  type PageId,
} from './navConfig';

interface MobileChromeProps {
  activePage: PageId;
  onNavigate: (page: PageId) => void;
}

function activeTab(page: PageId): MobileTabId | null {
  const parent = activeParentId(page);
  return MOBILE_TABS.some((tab) => tab.id === parent)
    ? (parent as MobileTabId)
    : null;
}

/** the pill tab to light up: an area page reached from a single-area Hoje
    has no tab of its own (see mobileTabsFor), so Hoje stays lit */
function litTab(page: PageId, tabs: MobileTab[]): MobileTabId | null {
  const id = activeTab(page);
  return tabs.some((tab) => tab.id === id) ? id : 'overview';
}

interface MobileHeaderProps extends MobileChromeProps {
  themePref: ThemePref;
  onThemePref: (pref: ThemePref) => void;
}

/**
 * mobile (< md) section header, in the page flow (it scrolls away with the
 * content): large area title + the account menu (avatar, top right), then
 * the area's sub-pages as text tabs. Redesign Corrida 17b "Monolito"
 */
export function MobileHeader({
  activePage,
  onNavigate,
  themePref,
  onThemePref,
}: MobileHeaderProps) {
  const { t } = useTranslation('nav');
  const tabId = activeTab(activePage);
  const tab = MOBILE_TABS.find((x) => x.id === tabId);
  const subs = tabId ? mobileSubPages(tabId) : [];

  return (
    <header className="px-[22px] pt-2 md:hidden">
      <div className="flex items-center justify-between gap-3">
        <h1 className="min-w-0 truncate text-[28px] font-semibold tracking-[-.02em] text-foreground">
          {t(tab ? tab.labelKey : 'profile.title')}
        </h1>
        <ProfileMenu
          themePref={themePref}
          onThemePref={onThemePref}
          onNavigate={onNavigate}
        />
      </div>

      {subs.length > 0 && (
        <nav
          aria-label={t('tabs.sections')}
          className="no-scrollbar mt-2 -mx-[22px] flex gap-[22px] overflow-x-auto border-b border-border px-[22px]"
        >
          {subs.map((sub) => {
            const active = sub.id === activePage;
            return (
              <button
                key={sub.id}
                onClick={() => onNavigate(sub.id)}
                disabled={sub.disabled}
                aria-current={active ? 'page' : undefined}
                className={cn(
                  // the 2px underline is the static cue for the active tab;
                  // switching is instant (high-frequency, no motion)
                  'flex min-h-[44px] flex-none cursor-pointer items-center border-b-2 text-[14.5px] font-medium',
                  active
                    ? 'border-acc text-foreground'
                    : 'border-transparent text-muted-foreground',
                  sub.disabled && 'cursor-not-allowed opacity-40',
                )}
              >
                {t(sub.labelKey)}
              </button>
            );
          })}
        </nav>
      )}
    </header>
  );
}

/**
 * mobile (< md) floating pill tab bar (17b): screen background, hairline
 * border, the active tab grows a label and takes the accent on its icon. A
 * fade behind it keeps the list from looking cut off under the pill
 */
export function MobileTabBar({ activePage, onNavigate }: MobileChromeProps) {
  const { t } = useTranslation('nav');
  const { user } = useAuth();
  const tabs = mobileTabsFor(user?.enabledAreas ?? []);
  const current = litTab(activePage, tabs);
  if (tabs.length === 0) return null;

  return (
    <div className="md:hidden">
      <div
        aria-hidden="true"
        className="pointer-events-none fixed inset-x-0 bottom-0 z-30 h-[130px] bg-[linear-gradient(to_bottom,transparent,var(--page-bg)_62%)]"
      />
      <nav
        aria-label={t('tabs.label')}
        className="fixed bottom-[max(20px,calc(env(safe-area-inset-bottom)+8px))] left-1/2 z-40 flex -translate-x-1/2 gap-0.5 rounded-full border border-border bg-page-bg p-[5px]"
      >
        {tabs.map((tab) => {
          const active = tab.id === current;
          return (
            <button
              key={tab.id}
              onClick={() => onNavigate(tab.page)}
              aria-label={active ? undefined : t(tab.labelKey)}
              aria-current={active ? 'page' : undefined}
              className={cn(
                'flex h-[46px] min-w-[50px] cursor-pointer items-center justify-center gap-[7px] rounded-full',
                active
                  ? 'bg-chip pr-4 pl-3 text-acc-tx'
                  : 'text-muted-foreground',
              )}
            >
              <svg
                width="22"
                height="22"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth={active ? 1.9 : 1.7}
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <path d={tab.icon} />
              </svg>
              {active && (
                <span className="text-[13.5px] font-semibold text-foreground">
                  {t(tab.labelKey)}
                </span>
              )}
            </button>
          );
        })}
      </nav>
    </div>
  );
}

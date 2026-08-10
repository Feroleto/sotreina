import { type ReactNode } from 'react';
import { Menu } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { cn } from '@/lib/utils';
import { avatarMediumUrl } from '@/lib/avatarUrl';
import { useAuth } from '@/features/auth/AuthContext';
import {
  MOBILE_TITLE_KEYS,
  NAV_SECTIONS,
  type NavItem,
  type PageId,
} from './navConfig';

interface MobileChromeProps {
  activePage: PageId;
  onNavigate: (page: PageId) => void;
  // drawer open state lives in App.tsx (not here) so WorkoutSession's
  // hamburger button can open the very same drawer — see ActiveWorkoutBar
  drawerOpen: boolean;
  onOpenDrawer: () => void;
  onCloseDrawer: () => void;
}

function DrawerGroup({
  title,
  children,
}: {
  title?: string;
  children: ReactNode;
}) {
  return (
    <div>
      {title && (
        <div className="mb-1.5 px-3 text-[10.5px] font-semibold tracking-[.07em] text-muted-foreground uppercase">
          {title}
        </div>
      )}
      <div className="flex flex-col gap-1">{children}</div>
    </div>
  );
}

function DrawerItem({
  label,
  icon: Icon,
  active,
  disabled,
  badge,
  onPick,
}: {
  label: string;
  icon?: NavItem['icon'];
  active: boolean;
  disabled?: boolean;
  badge?: string;
  onPick: () => void;
}) {
  return (
    <button
      onClick={onPick}
      disabled={disabled}
      className={cn(
        'flex min-h-[44px] w-full items-center gap-2.5 rounded-[10px] p-[11px_12px] text-left text-[14px] font-medium',
        disabled
          ? 'cursor-not-allowed text-muted-foreground'
          : active
            ? 'cursor-pointer bg-acc-bg font-semibold text-acc-tx'
            : 'cursor-pointer text-foreground hover:bg-chip',
      )}
    >
      {Icon && <Icon className="h-4 w-4 flex-none" strokeWidth={1.7} />}
      <span className="flex-1">{label}</span>
      {badge && (
        <span className="rounded-[5px] bg-chip px-1.5 py-0.5 text-[9.5px] font-semibold tracking-[.02em] text-muted-foreground uppercase">
          {badge}
        </span>
      )}
    </button>
  );
}

/** mobile (< md) chrome: fixed top app bar + slide-in navigation drawer */
export default function MobileChrome({
  activePage,
  onNavigate,
  drawerOpen: open,
  onOpenDrawer: openDrawer,
  onCloseDrawer: closeDrawer,
}: MobileChromeProps) {
  const { t } = useTranslation('nav');
  const { user } = useAuth();
  const initials = user?.firstName
    ? user.firstName.slice(0, 2).toUpperCase()
    : '—';

  const pick = (page: PageId, disabled?: boolean) => {
    if (disabled) return;
    onNavigate(page);
    closeDrawer();
  };

  const avatar = user?.profileImgUrl ? (
    <img
      src={avatarMediumUrl(user.profileImgUrl)}
      alt=""
      width={30}
      height={30}
      className="h-[30px] w-[30px] flex-none rounded-full object-cover"
    />
  ) : (
    <div className="flex h-[30px] w-[30px] flex-none items-center justify-center rounded-full bg-chip text-[11px] font-semibold text-foreground">
      {initials}
    </div>
  );

  return (
    <div className="md:hidden">
      {/* app bar */}
      <header className="fixed inset-x-0 top-0 z-40 border-b border-border bg-card px-[18px] pt-[max(12px,env(safe-area-inset-top))] pb-3">
        <div className="flex items-center gap-3">
          <button
            onClick={openDrawer}
            aria-label={t('openMenu')}
            className="flex h-10 w-10 flex-none cursor-pointer items-center justify-center rounded-[10px] text-foreground hover:bg-chip active:bg-chip"
          >
            <Menu className="h-[22px] w-[22px]" strokeWidth={1.8} />
          </button>
          <div className="flex h-7 w-7 flex-none items-center justify-center rounded-[8px] bg-acc text-[11px] font-bold text-white">
            ST
          </div>
          <div className="min-w-0 truncate text-[15px] font-semibold text-foreground">
            {t(MOBILE_TITLE_KEYS[activePage])}
          </div>
          <button
            onClick={() => onNavigate('profile')}
            aria-label={t('profile.title')}
            className="ml-auto flex-none cursor-pointer"
          >
            {avatar}
          </button>
        </div>
      </header>

      {/* drawer */}
      {open && (
        <div className="fixed inset-0 z-50">
          <div
            className="absolute inset-0 bg-[rgba(8,12,20,.35)] dark:bg-[rgba(4,7,12,.55)]"
            onClick={closeDrawer}
          />
          <div className="drawer-panel absolute inset-y-0 left-0 flex w-[288px] flex-col border-r border-border bg-card px-3.5 pt-[calc(max(12px,env(safe-area-inset-top))_+_10px)] pb-[30px] shadow-[24px_0_60px_rgba(4,8,16,.3)]">
            <div className="flex items-center gap-[10px] px-3">
              <div className="flex h-[30px] w-[30px] flex-none items-center justify-center rounded-[9px] bg-acc text-[12px] font-bold text-white">
                ST
              </div>
              <span className="text-[14.5px] font-semibold text-foreground">
                SoTreina
              </span>
            </div>

            <nav className="mt-5 flex flex-col gap-5">
              {NAV_SECTIONS.flatMap((section, si) => {
                const groups = [];
                // an item with sub-pages becomes its own titled group
                for (const item of section.items) {
                  if (!item.subs) continue;
                  groups.push(
                    <DrawerGroup key={item.id} title={t(item.labelKey)}>
                      {item.subs.map((sub) => (
                        <DrawerItem
                          key={sub.id}
                          label={t(sub.labelKey)}
                          active={sub.id === activePage}
                          disabled={sub.disabled}
                          onPick={() => pick(sub.id, sub.disabled)}
                        />
                      ))}
                    </DrawerGroup>,
                  );
                }
                const rest = section.items.filter((i) => !i.subs);
                if (rest.length > 0) {
                  groups.push(
                    <DrawerGroup
                      key={`rest-${si}`}
                      title={section.titleKey ? t(section.titleKey) : undefined}
                    >
                      {rest.map((item) => (
                        <DrawerItem
                          key={item.id}
                          label={t(item.labelKey)}
                          icon={item.icon}
                          active={item.page === activePage}
                          disabled={item.disabled}
                          badge={item.badgeKey ? t(item.badgeKey) : undefined}
                          onPick={() => item.page && pick(item.page)}
                        />
                      ))}
                    </DrawerGroup>,
                  );
                }
                return groups;
              })}
            </nav>

            <button
              onClick={() => pick('profile')}
              className="mt-auto flex min-h-[44px] w-full cursor-pointer items-center gap-2.5 border-t border-border px-3 pt-3 text-left"
            >
              {avatar}
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[12.5px] font-semibold text-foreground">
                  {user?.firstName ?? t('runnerFallback')}
                </span>
                <span className="block text-[11px] text-muted-foreground">
                  {t('yourProfile')}
                </span>
              </span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

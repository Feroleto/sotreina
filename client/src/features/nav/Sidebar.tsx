import type { ReactNode } from 'react';
import { ChevronLeft, LogOut, Plus, type LucideIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { cn } from '@/lib/utils';
import { avatarMediumUrl } from '@/lib/avatarUrl';
import { THEME_OPTIONS, type ThemePref } from '@/lib/theme';
import SegmentedControl from '@/components/SegmentedControl';
import { useAuth } from '@/features/auth/AuthContext';
import { useAppLanguage } from '@/i18n/useAppLanguage';
import {
  activeParentId,
  NAV_SECTIONS,
  type NavItem,
  type NavSubItem,
  type PageId,
} from './navConfig';

interface SidebarProps {
  collapsed: boolean;
  onToggleCollapse: () => void;
  activePage: PageId;
  onNavigate: (page: PageId, opts?: { collapse?: boolean }) => void;
  themePref: ThemePref;
  onThemePref: (pref: ThemePref) => void;
}

function SidebarLabel({
  collapsed,
  children,
  className,
}: {
  collapsed: boolean;
  children: ReactNode;
  className?: string;
}) {
  return (
    <span
      className={cn(
        'overflow-hidden whitespace-nowrap transition-[max-width,opacity] duration-200 ease-in-out',
        collapsed ? 'max-w-0 opacity-0' : 'max-w-[150px] opacity-100',
        className,
      )}
    >
      {children}
    </span>
  );
}

function isItemActive(item: NavItem, activePage: PageId): boolean {
  if (item.subs) return activeParentId(activePage) === item.id;
  return item.page === activePage;
}

function NavItemRow({
  item,
  collapsed,
  active,
  onClick,
}: {
  item: NavItem;
  collapsed: boolean;
  active: boolean;
  onClick: () => void;
}) {
  const { t } = useTranslation('nav');
  const Icon = item.icon;
  const label = t(item.labelKey);
  return (
    <button
      onClick={onClick}
      disabled={item.disabled}
      title={collapsed ? label : undefined}
      className={cn(
        'flex w-full items-center gap-2.5 rounded-[9px] px-[9px] py-2 text-[13px] font-medium',
        collapsed && 'justify-center',
        item.disabled
          ? 'cursor-not-allowed text-muted-foreground'
          : active
            ? 'cursor-pointer bg-acc-bg font-semibold text-acc-tx'
            : 'cursor-pointer text-foreground hover:bg-chip',
      )}
    >
      <Icon className="h-4 w-4 flex-none" strokeWidth={1.7} />
      <SidebarLabel collapsed={collapsed} className="flex-1 text-left">
        {label}
      </SidebarLabel>
      {item.badgeKey && (
        <SidebarLabel collapsed={collapsed} className="flex-none">
          <span className="rounded-[5px] bg-chip px-1.5 py-0.5 text-[9.5px] font-semibold tracking-[.02em] text-muted-foreground uppercase">
            {t(item.badgeKey)}
          </span>
        </SidebarLabel>
      )}
    </button>
  );
}

function SubList({
  subs,
  activePage,
  onPick,
}: {
  subs: NavSubItem[];
  activePage: PageId;
  onPick: (sub: NavSubItem) => void;
}) {
  const { t } = useTranslation('nav');
  return (
    <div className="mt-1 mb-1 ml-[18px] flex flex-col gap-0.5 border-l border-border pl-3">
      {subs.map((sub) => {
        const active = sub.id === activePage;
        return (
          <button
            key={sub.id}
            onClick={() => !sub.disabled && onPick(sub)}
            disabled={sub.disabled}
            className={cn(
              'relative rounded-[7px] py-[5px] text-left text-[12.5px]',
              sub.disabled
                ? 'cursor-not-allowed text-muted-foreground/50'
                : active
                  ? 'cursor-pointer font-semibold text-acc-tx'
                  : 'cursor-pointer text-muted-foreground hover:text-foreground',
            )}
          >
            {active && (
              <span className="absolute top-0 -left-3 h-full w-[2px] bg-acc" />
            )}
            {t(sub.labelKey)}
          </button>
        );
      })}
    </div>
  );
}

function AddSportRow({ collapsed }: { collapsed: boolean }) {
  const { t } = useTranslation('nav');
  const Icon: LucideIcon = Plus;
  return (
    <button
      disabled
      title={collapsed ? t('addSport') : undefined}
      className={cn(
        'flex w-full cursor-not-allowed items-center gap-2.5 rounded-[9px] border border-dashed border-grid-ax px-[9px] py-2 text-[13px] font-medium text-muted-foreground',
        collapsed && 'justify-center',
      )}
    >
      <Icon className="h-4 w-4 flex-none" strokeWidth={1.7} />
      <SidebarLabel collapsed={collapsed}>{t('addSport')}</SidebarLabel>
    </button>
  );
}

export default function Sidebar({
  collapsed,
  onToggleCollapse,
  activePage,
  onNavigate,
  themePref,
  onThemePref,
}: SidebarProps) {
  const { t } = useTranslation('nav');
  const { user, logout } = useAuth();
  const { language, setLanguage } = useAppLanguage();
  const initials = user?.firstName
    ? user.firstName.slice(0, 2).toUpperCase()
    : '—';

  const handleNavClick = (item: NavItem) => {
    if (item.disabled) return;
    if (item.subs) {
      onNavigate(item.page ?? item.subs[0].id);
    } else if (item.page) {
      onNavigate(item.page, { collapse: true });
    }
  };

  return (
    <div
      className={cn(
        'sticky top-3.5 h-[calc(100vh-28px)] flex-none rounded-2xl border border-border bg-card transition-[width] duration-[280ms] ease-in-out max-md:hidden',
        collapsed ? 'w-[66px]' : 'w-[226px]',
      )}
      style={{ boxShadow: '0 8px 24px rgba(8,12,20,.08)' }}
    >
      <button
        onClick={onToggleCollapse}
        aria-label={collapsed ? t('expandSidebar') : t('collapseSidebar')}
        className="absolute top-[27px] -right-3 z-10 flex h-6 w-6 cursor-pointer items-center justify-center rounded-full border border-border bg-card"
        style={{ boxShadow: '0 2px 8px rgba(8,12,20,.16)' }}
      >
        <ChevronLeft
          className={cn(
            'h-3.5 w-3.5 text-muted-foreground transition-transform duration-[280ms]',
            collapsed && 'rotate-180',
          )}
          strokeWidth={1.7}
        />
      </button>

      <div className="flex h-full flex-col overflow-hidden px-3 pt-5 pb-4">
        <div className="flex items-center gap-2.5 px-[9px]">
          <div className="flex h-[30px] w-[30px] flex-none items-center justify-center rounded-[9px] bg-acc text-[14px] font-bold text-white">
            ST
          </div>
          <SidebarLabel
            collapsed={collapsed}
            className="text-[15px] font-semibold text-foreground"
          >
            SoTreina
          </SidebarLabel>
        </div>

        <nav className="mt-6 flex flex-col gap-4">
          {NAV_SECTIONS.map((section, i) => (
            <div key={i}>
              {section.titleKey && (
                <SidebarLabel
                  collapsed={collapsed}
                  className="mb-1.5 block px-[9px] text-[10.5px] font-semibold tracking-[.07em] text-muted-foreground uppercase"
                >
                  {t(section.titleKey)}
                </SidebarLabel>
              )}
              <div className="flex flex-col gap-1">
                {section.items.map((item) => (
                  <div key={item.id}>
                    <NavItemRow
                      item={item}
                      collapsed={collapsed}
                      active={isItemActive(item, activePage)}
                      onClick={() => handleNavClick(item)}
                    />
                    {item.subs &&
                      !collapsed &&
                      activeParentId(activePage) === item.id && (
                        <SubList
                          subs={item.subs}
                          activePage={activePage}
                          onPick={(sub) =>
                            onNavigate(sub.id, { collapse: true })
                          }
                        />
                      )}
                  </div>
                ))}
              </div>
            </div>
          ))}
          <AddSportRow collapsed={collapsed} />
        </nav>

        <div className="mt-auto border-t border-border pt-3">
          {!collapsed && (
            <div className="flex flex-wrap items-center gap-2">
              <SegmentedControl
                size="compact"
                items={THEME_OPTIONS.map(
                  ([k, key]) => [k, t(`common:${key}`)] as [ThemePref, string],
                )}
                active={themePref}
                onPick={onThemePref}
              />
              <SegmentedControl
                size="compact"
                items={[
                  ['pt', 'PT'],
                  ['en', 'EN'],
                ]}
                active={language}
                onPick={setLanguage}
              />
            </div>
          )}
          <div className="mt-3 flex items-center gap-2.5 px-[9px]">
            {user?.profileImgUrl ? (
              <img
                src={avatarMediumUrl(user.profileImgUrl)}
                alt=""
                width={30}
                height={30}
                className="h-[30px] w-[30px] flex-none rounded-full object-cover"
              />
            ) : (
              <div className="flex h-[30px] w-[30px] flex-none items-center justify-center rounded-full bg-chip text-[12px] font-semibold text-foreground">
                {initials}
              </div>
            )}
            <SidebarLabel collapsed={collapsed} className="flex-1">
              <div className="truncate text-[12.5px] font-semibold text-foreground">
                {user?.firstName ?? t('runnerFallback')}
              </div>
              <div className="text-[11px] text-muted-foreground">
                {t('yourProfile')}
              </div>
            </SidebarLabel>
            {!collapsed && (
              <button
                onClick={() => void logout()}
                title={t('logOut')}
                aria-label={t('logOut')}
                className="flex h-7 w-7 flex-none cursor-pointer items-center justify-center rounded-[7px] text-muted-foreground hover:bg-chip hover:text-foreground"
              >
                <LogOut className="h-3.5 w-3.5" strokeWidth={1.7} />
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

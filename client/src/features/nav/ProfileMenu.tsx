import { lazy, Suspense, useState } from 'react';
import { useTranslation } from 'react-i18next';
import MotionProvider from '@/components/MotionProvider';
import {
  ProfileAvatar,
  TRIGGER_CLASS,
} from '@/components/kokonutui/profile-avatar';
import { useAuth } from '@/features/auth/AuthContext';
import { useAppLanguage } from '@/i18n/useAppLanguage';
import type { ThemePref } from '@/lib/theme';
import type { PageId } from './navConfig';

// Motion stays out of the shell's chunks: the header renders a plain avatar
// and only the first tap downloads the dropdown (which then opens itself)
const ProfileDropdown = lazy(
  () => import('@/components/kokonutui/profile-dropdown'),
);

interface ProfileMenuProps {
  themePref: ThemePref;
  onThemePref: (pref: ThemePref) => void;
  onNavigate: (page: PageId) => void;
}

/** mobile header's account menu (top right): theme, language, settings, sign out */
export function ProfileMenu({
  themePref,
  onThemePref,
  onNavigate,
}: ProfileMenuProps) {
  const { t } = useTranslation(['nav', 'common']);
  const { user, logout } = useAuth();
  const { language, setLanguage } = useAppLanguage();
  // flips on the first tap and stays: the loaded dropdown keeps its own state
  const [armed, setArmed] = useState(false);
  const initials = user?.firstName
    ? user.firstName.slice(0, 2).toUpperCase()
    : '—';

  const placeholder = (
    <button
      type="button"
      aria-label={t('profileMenu.menu')}
      aria-haspopup="menu"
      aria-expanded={false}
      onClick={() => setArmed(true)}
      className={TRIGGER_CLASS}
    >
      <ProfileAvatar
        url={user?.profileImgUrl}
        initials={initials}
        size={34}
        className="text-[12px]"
      />
    </button>
  );

  if (!armed) return placeholder;

  return (
    <Suspense fallback={placeholder}>
      <MotionProvider>
        <ProfileDropdown
          defaultOpen
          name={user?.firstName ?? t('runnerFallback')}
          secondary={user?.email ?? t('profileMenu.viaStrava')}
          avatarUrl={user?.profileImgUrl}
          initials={initials}
          theme={themePref}
          onThemeChange={onThemePref}
          language={language}
          onLanguageChange={setLanguage}
          onSettings={() => onNavigate('profile')}
          onSignOut={() => void logout()}
          labels={{
            menu: t('profileMenu.menu'),
            theme: t('profileMenu.theme'),
            themeAuto: t('common:theme.auto'),
            themeLight: t('common:theme.light'),
            themeDark: t('common:theme.dark'),
            language: t('profileMenu.language'),
            settings: t('profileMenu.settings'),
            signOut: t('profileMenu.signOut'),
            hold: t('profileMenu.hold'),
            keepHolding: t('profileMenu.keepHolding'),
            holdHint: t('profileMenu.holdHint'),
          }}
        />
      </MotionProvider>
    </Suspense>
  );
}

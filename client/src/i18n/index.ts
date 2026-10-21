import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { resources } from './resources';

export const SUPPORTED_LANGUAGES = ['pt', 'en'] as const;
export type AppLanguage = (typeof SUPPORTED_LANGUAGES)[number];

const STORAGE_KEY = 'language';
const HTML_LANG: Record<AppLanguage, string> = { pt: 'pt-BR', en: 'en-US' };

function isAppLanguage(value: string | null): value is AppLanguage {
  return value === 'pt' || value === 'en';
}

// localStorage 'language' > navigator.language (pt* -> pt) > 'en' fallback
// guarded for non-browser environments (vitest runs without jsdom, see
// client/vitest.config.ts — only pure functions are exercised there, and
// this module is pulled in transitively via lib/dateLocale.ts)
function detectLanguage(): AppLanguage {
  if (typeof localStorage === 'undefined') return 'en';
  const stored = localStorage.getItem(STORAGE_KEY);
  if (isAppLanguage(stored)) return stored;
  if (typeof navigator === 'undefined') return 'en';
  return navigator.language.toLowerCase().startsWith('pt') ? 'pt' : 'en';
}

const initialLanguage = detectLanguage();

void i18n.use(initReactI18next).init({
  lng: initialLanguage,
  fallbackLng: 'en',
  supportedLngs: SUPPORTED_LANGUAGES as unknown as string[],
  ns: [
    'common',
    'auth',
    'onboarding',
    'nav',
    'dashboard',
    'overview',
    'activity',
    'analysis',
    'gym',
    'diet',
    'legal',
  ],
  defaultNS: 'common',
  resources,
  interpolation: { escapeValue: false },
  returnNull: false,
});

// persistence + <html lang> centralized here — fires on every language
// change regardless of which component triggered it
if (typeof document !== 'undefined') {
  document.documentElement.lang = HTML_LANG[initialLanguage];
}
i18n.on('languageChanged', (lng) => {
  const next = isAppLanguage(lng) ? lng : 'en';
  if (typeof localStorage !== 'undefined') localStorage.setItem(STORAGE_KEY, next);
  if (typeof document !== 'undefined') document.documentElement.lang = HTML_LANG[next];
});

export default i18n;

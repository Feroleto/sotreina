import commonEn from './locales/en/common.json';
import authEn from './locales/en/auth.json';
import onboardingEn from './locales/en/onboarding.json';
import navEn from './locales/en/nav.json';
import dashboardEn from './locales/en/dashboard.json';
import overviewEn from './locales/en/overview.json';
import activityEn from './locales/en/activity.json';
import analysisEn from './locales/en/analysis.json';
import gymEn from './locales/en/gym.json';
import dietEn from './locales/en/diet.json';
import legalEn from './locales/en/legal.json';

import commonPt from './locales/pt/common.json';
import authPt from './locales/pt/auth.json';
import onboardingPt from './locales/pt/onboarding.json';
import navPt from './locales/pt/nav.json';
import dashboardPt from './locales/pt/dashboard.json';
import overviewPt from './locales/pt/overview.json';
import activityPt from './locales/pt/activity.json';
import analysisPt from './locales/pt/analysis.json';
import gymPt from './locales/pt/gym.json';
import dietPt from './locales/pt/diet.json';
import legalPt from './locales/pt/legal.json';

export const resources = {
  en: {
    common: commonEn,
    auth: authEn,
    onboarding: onboardingEn,
    nav: navEn,
    dashboard: dashboardEn,
    overview: overviewEn,
    activity: activityEn,
    analysis: analysisEn,
    gym: gymEn,
    diet: dietEn,
    legal: legalEn,
  },
  pt: {
    common: commonPt,
    auth: authPt,
    onboarding: onboardingPt,
    nav: navPt,
    dashboard: dashboardPt,
    overview: overviewPt,
    activity: activityPt,
    analysis: analysisPt,
    gym: gymPt,
    diet: dietPt,
    legal: legalPt,
  },
} as const;

import { useTranslation } from 'react-i18next';
import LegalDocument, { type LegalSection } from './LegalDocument';

// Strava's API Policy (7.3, 2.1) requires a public privacy policy that says
// how to withdraw consent and request deletion. Standalone like
// ResetPasswordPage: reachable at /privacidade with or without a session,
// and linked from the Strava developer program form.
export default function PrivacyPage() {
  const { t } = useTranslation('legal');

  return (
    <LegalDocument
      title={t('title')}
      updated={t('updated')}
      sections={t('sections', { returnObjects: true }) as LegalSection[]}
      backLabel={t('back')}
    />
  );
}

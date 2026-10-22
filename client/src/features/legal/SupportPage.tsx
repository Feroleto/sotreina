import { useTranslation } from 'react-i18next';
import LegalDocument, { type LegalSection } from './LegalDocument';

// "Support URL" of the Strava developer program form: a public page athletes
// can reach without a session, same standalone treatment as PrivacyPage
export default function SupportPage() {
  const { t } = useTranslation('legal');

  return (
    <LegalDocument
      title={t('support.title')}
      sections={
        t('support.sections', { returnObjects: true }) as LegalSection[]
      }
      backLabel={t('back')}
    />
  );
}

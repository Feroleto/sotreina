import { useTranslation } from 'react-i18next';
import { ChevronLeft } from 'lucide-react';
import { useAuth } from '@/features/auth/AuthContext';
import EmailCodeForm from '@/features/auth/EmailCodeForm';

/** Perfil → "Verificar": same code step as sign-up, asking for a fresh code */
export default function VerifyEmailPage({ onBack }: { onBack: () => void }) {
  const { t } = useTranslation(['nav', 'auth']);
  const { user, setUser } = useAuth();

  return (
    <div className="px-5 pt-[18px] pb-8 md:max-w-[560px] md:px-[34px] md:pt-[30px]">
      <div className="mb-4 flex items-center gap-3">
        <button
          type="button"
          onClick={onBack}
          aria-label={t('profile.back')}
          className="flex h-8 w-8 flex-none cursor-pointer items-center justify-center rounded-[9px] text-muted-foreground hover:bg-chip hover:text-foreground"
        >
          <ChevronLeft className="h-4.5 w-4.5" strokeWidth={1.8} />
        </button>
        <h1 className="text-[15px] font-semibold text-foreground">
          {t('auth:verify.title')}
        </h1>
      </div>

      <p className="text-[13px] leading-[1.55] text-muted-foreground">
        {t('auth:verify.subtitle', { email: user?.email ?? '' })}
      </p>

      <EmailCodeForm
        sendOnMount
        onVerified={(me) => {
          setUser(me);
          onBack();
        }}
        onSkip={onBack}
      />
    </div>
  );
}

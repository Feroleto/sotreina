import { useState } from 'react';
import type { FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { ChevronLeft } from 'lucide-react';
import { useAuth } from '@/features/auth/AuthContext';
import { patchMe } from '@/lib/userMe';

// mirrors the server's parseFirstName bound
const MAX_NAME_LEN = 60;

/** Perfil → personal data: the name is editable, the email is shown read-only */
export default function EditNamePage({ onBack }: { onBack: () => void }) {
  const { t } = useTranslation('nav');
  const { user, setUser } = useAuth();
  const [name, setName] = useState(user?.firstName ?? '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(false);

  const trimmed = name.trim();
  const canSave = trimmed.length > 0 && trimmed !== (user?.firstName ?? '');

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!user || !canSave || saving) return;
    setSaving(true);
    setError(false);
    try {
      const snap = await patchMe({ firstName: trimmed });
      setUser({ ...user, firstName: snap.firstName });
      onBack();
    } catch {
      setError(true);
      setSaving(false);
    }
  };

  return (
    <form
      onSubmit={(e) => void submit(e)}
      className="px-5 pt-[18px] pb-8 md:max-w-[560px] md:px-[34px] md:pt-[30px]"
    >
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
          {t('profile.personalData')}
        </h1>
      </div>

      <label className="block text-[12.5px] font-medium text-muted-foreground">
        {t('profile.name')}
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          maxLength={MAX_NAME_LEN}
          autoComplete="given-name"
          required
          className="mt-1.5 w-full rounded-[11px] border border-border bg-transparent px-3.5 py-[11px] text-[16px] text-foreground outline-none focus:border-acc md:text-[14px]"
        />
      </label>

      <div className="mt-4 text-[12.5px] font-medium text-muted-foreground">
        {t('profile.email')}
      </div>
      <p className="mt-1.5 text-[14px] text-foreground">
        {user?.email ?? t('profile.noEmail')}
      </p>
      <p className="mt-1 text-[12px] leading-[1.5] text-muted-foreground">
        {t('profile.emailReadOnly')}
      </p>

      {error && (
        <p className="mt-3 text-[12px] text-neg">{t('profile.saveError')}</p>
      )}

      <button
        type="submit"
        disabled={!canSave || saving}
        className="press mt-6 w-full cursor-pointer rounded-[11px] bg-acc px-4 py-3 text-[14px] font-semibold text-acc-fg disabled:cursor-default disabled:opacity-50"
      >
        {saving ? t('profile.saving') : t('profile.save')}
      </button>
    </form>
  );
}

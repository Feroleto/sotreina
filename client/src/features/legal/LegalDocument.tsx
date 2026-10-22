import SegmentedControl from '@/components/SegmentedControl';
import { useAppLanguage } from '@/i18n/useAppLanguage';
import { Logo } from '@/components/Logo';

export interface LegalSection {
  title: string;
  body: string[];
}

interface Props {
  title: string;
  updated?: string;
  sections: LegalSection[];
  backLabel: string;
}

// shared shell of the public, session-agnostic text pages (privacy, support)
export default function LegalDocument({
  title,
  updated,
  sections,
  backLabel,
}: Props) {
  const { language, setLanguage } = useAppLanguage();

  return (
    <div className="min-h-svh bg-page-bg px-[22px] py-10 md:py-14">
      <article className="mx-auto max-w-[640px]">
        <div className="flex items-center justify-between gap-3">
          <a href="/" className="flex items-center gap-[10px]">
            <Logo className="text-foreground" />
            <span className="text-[14px] font-semibold text-foreground">
              SoTreina
            </span>
          </a>
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

        <h1 className="mt-8 text-[26px] font-semibold tracking-[-.02em] text-foreground">
          {title}
        </h1>
        {updated && (
          <p className="mt-1 text-[13px] text-muted-foreground">{updated}</p>
        )}

        {sections.map((section) => (
          <section key={section.title} className="mt-7">
            <h2 className="text-[16px] font-semibold text-foreground">
              {section.title}
            </h2>
            {section.body.map((paragraph) => (
              <p
                key={paragraph}
                className="mt-2 text-[14.5px] leading-[1.6] text-muted-foreground"
              >
                {paragraph}
              </p>
            ))}
          </section>
        ))}

        <a
          href="/"
          className="mt-10 inline-block text-[13.5px] font-medium text-foreground underline underline-offset-4"
        >
          {backLabel}
        </a>
      </article>
    </div>
  );
}

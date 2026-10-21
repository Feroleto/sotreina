import { useEffect, useState } from 'react';
import type { CSSProperties } from 'react';
import { useTranslation } from 'react-i18next';
import type { Gear } from '@/lib/types';
import { formatKm, formatMonthShortYear } from '@/lib/activityFormat';
import { apiFetch } from '@/lib/api';
import { useEntrance } from '@/lib/useEntrance';

// TODO: Strava's Gear API exposes no per-shoe mileage goal at all — this is a
// fixed placeholder until there's a real, user-settable goal field.
const SHOE_LIFESPAN_M = 800_000;

export default function ShoesSection() {
  const { t } = useTranslation('overview');
  const [gear, setGear] = useState<Gear[]>([]);
  const [loading, setLoading] = useState(true);
  // below the fold on mobile: the cards rise when the section scrolls in
  const { attach: enterRef, state: enterState } = useEntrance(
    'run/overview:shoes',
    { ready: !loading, inView: true },
  );

  useEffect(() => {
    apiFetch('/gear')
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then(setGear)
      .catch(() => setGear([]))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return null;

  const activeCount = gear.filter((g) => !g.retired).length;
  const retiredCount = gear.filter((g) => g.retired).length;

  return (
    <div ref={enterRef} data-enter={enterState}>
      <div className="flex items-center justify-between">
        <div className="text-[13.5px] font-semibold text-foreground">
          {t('shoes.title')}
        </div>
        <div className="text-[11.5px] text-muted-foreground">
          {t('shoes.activeRetired', {
            active: activeCount,
            retired: retiredCount,
          })}
        </div>
      </div>

      {/* mobile: edge-bleed horizontal carousel; desktop: 3-col grid */}
      <div className="no-scrollbar -mx-5 mt-3 flex gap-[14px] overflow-x-auto px-5 md:mx-0 md:grid md:grid-cols-3 md:overflow-visible md:px-0">
        {gear.map((g, i) => (
          <ShoeCard key={g.id} gear={g} index={i} />
        ))}
        {gear.length === 0 && (
          <p className="w-full py-6 text-center text-[12.5px] text-muted-foreground md:col-span-3">
            {t('shoes.empty')}
          </p>
        )}
      </div>
    </div>
  );
}

function ShoeCard({ gear, index }: { gear: Gear; index: number }) {
  const { t } = useTranslation('overview');
  const pct = Math.min(100, (gear.computedDistanceM / SHOE_LIFESPAN_M) * 100);
  const barColor = gear.retired
    ? 'var(--muted-foreground)'
    : pct > 85
      ? 'var(--neg)'
      : 'var(--acc)';

  // no "Race Day" tier: Strava's Gear API only has primary/retired, nothing
  // in between — a shoe that's neither gets no badge
  const badge = gear.primary
    ? { label: t('shoes.default'), bg: 'bg-acc-bg', text: 'text-acc-tx' }
    : gear.retired
      ? { label: t('shoes.retired'), bg: 'bg-neutral-bg', text: 'text-neutral' }
      : null;

  const meta =
    gear.retired && gear.firstUseDate && gear.lastUseDate
      ? t('shoes.dateRange', {
          start: formatMonthShortYear(new Date(gear.firstUseDate)),
          end: formatMonthShortYear(new Date(gear.lastUseDate)),
        })
      : gear.firstUseDate
        ? t('shoes.runsSince', {
            count: gear.runCount,
            date: formatMonthShortYear(new Date(gear.firstUseDate)),
          })
        : t('shoes.runsOnly', { count: gear.runCount });

  return (
    <div
      className={`enter-rise flex w-[230px] flex-none flex-col gap-[10px] rounded-[12px] border border-border bg-card p-4 md:w-auto ${
        gear.retired ? 'opacity-60' : ''
      }`}
      style={{ '--i': index } as CSSProperties}
    >
      <div className="flex items-center justify-between">
        <div className="text-[10px] font-semibold tracking-[.08em] text-muted-foreground uppercase">
          {gear.brandName ?? '—'}
        </div>
        {badge && (
          <span
            className={`rounded-[5px] px-[7px] py-[2px] text-[9.5px] font-semibold uppercase ${badge.bg} ${badge.text}`}
          >
            {badge.label}
          </span>
        )}
      </div>

      <div className="text-[15px] font-semibold text-foreground">
        {gear.modelName ?? gear.name}
      </div>

      <div className="flex items-baseline gap-1.5">
        <span className="text-[22px] font-bold text-foreground">
          {formatKm(gear.computedDistanceM / 1000)} km
        </span>
        <span className="text-[11.5px] text-muted-foreground">
          {t('shoes.ofLifespan', {
            km: Math.round(SHOE_LIFESPAN_M / 1000),
          })}
        </span>
      </div>

      <div className="h-[6px] rounded-[3px] bg-chip">
        <div
          className="h-full rounded-[3px]"
          style={{ width: `${pct}%`, background: barColor }}
        />
      </div>

      <div className="text-[11.5px] text-muted-foreground">{meta}</div>
    </div>
  );
}

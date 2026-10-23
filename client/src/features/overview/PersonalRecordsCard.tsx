import { Suspense, lazy, useEffect, useState } from 'react';
import type { CSSProperties, ReactNode } from 'react';
import { List, X } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import type { Activity, PersonalBestRecord } from '@/lib/types';
import {
  formatDurationShort,
  formatDistance,
  formatHms,
  formatMonthDayYear,
  formatPace,
} from '@/lib/activityFormat';
import { apiFetch } from '@/lib/api';
import { useEntrance } from '@/lib/useEntrance';
import { useAuth } from '@/features/auth/AuthContext';
import {
  newRecordKeys,
  readPrSnapshot,
  topRecordIdentities,
  writePrSnapshot,
} from './prSnapshot';
import { distanceLabel } from '@/lib/units';

const RecordCelebration = lazy(() => import('./RecordCelebration'));

interface PersonalRecordsCardProps {
  activities: Activity[];
}

// titleKey points into the 'overview' i18n namespace, translated at render time
const DISTANCES: { key: string; chip: string; titleKey: string }[] = [
  { key: '400m', chip: '400M', titleKey: 'records.distances.400m' },
  { key: '1/2 mile', chip: '½ MI', titleKey: 'records.distances.halfMile' },
  { key: '1k', chip: '1K', titleKey: 'records.distances.1k' },
  { key: '1 mile', chip: '1 MI', titleKey: 'records.distances.1mile' },
  { key: '2 mile', chip: '2 MI', titleKey: 'records.distances.2mile' },
  { key: '5k', chip: '5K', titleKey: 'records.distances.5k' },
  { key: '10k', chip: '10K', titleKey: 'records.distances.10k' },
  { key: '15k', chip: '15K', titleKey: 'records.distances.15k' },
  { key: '10 mile', chip: '10 MI', titleKey: 'records.distances.10mile' },
  { key: '20k', chip: '20K', titleKey: 'records.distances.20k' },
  {
    key: 'half-marathon',
    chip: 'HM',
    titleKey: 'records.distances.halfMarathon',
  },
  { key: 'marathon', chip: 'MAR', titleKey: 'records.distances.marathon' },
];

const COLUMNS = 3;
const PER_COLUMN = Math.ceil(DISTANCES.length / COLUMNS);

// mobile shows only the headline distances (plus the MAX row below)
const MOBILE_KEYS = ['1k', '5k', '10k'];

function Chip({ label, muted }: { label: string; muted?: boolean }) {
  return (
    <div
      className={`flex h-[34px] w-[42px] flex-none items-center justify-center rounded-[10px] text-[10.5px] font-bold ${
        muted ? 'bg-chip text-muted-foreground' : 'text-acc'
      }`}
      style={
        muted
          ? undefined
          : { background: 'color-mix(in oklab, var(--acc) 10%, transparent)' }
      }
    >
      {label}
    </div>
  );
}

// a distance whose top-1 changed since the user's last visit: the chip pops
// with a glow (Motion, lazy — only downloaded when there's something new)
// and a "New" badge stays next to the title for this visit
function CelebratedChip({
  isNew,
  children,
}: {
  isNew: boolean;
  children: ReactNode;
}) {
  if (!isNew) return <>{children}</>;
  return (
    <Suspense fallback={children}>
      <RecordCelebration>{children}</RecordCelebration>
    </Suspense>
  );
}

function NewBadge() {
  const { t } = useTranslation('overview');
  return (
    <span
      className="flex-none rounded-[6px] bg-acc px-[5px] py-[1px] text-[9.5px] font-bold text-acc-fg"
      title={t('records.newBadgeTitle')}
    >
      {t('records.newBadge')}
    </span>
  );
}

function MobileRecordRow({
  def,
  best,
  activityById,
  isNew,
}: {
  def: (typeof DISTANCES)[number];
  best: PersonalBestRecord | undefined;
  activityById: Map<string, Activity>;
  isNew: boolean;
}) {
  const { t } = useTranslation('overview');
  const bestActivity = best ? activityById.get(best.activityId) : undefined;
  const chip = (
    <div
      className={`flex h-[38px] w-[38px] flex-none items-center justify-center rounded-[10px] text-[10.5px] font-bold ${
        best ? 'text-acc' : 'bg-chip text-muted-foreground'
      }`}
      style={
        best
          ? { background: 'color-mix(in oklab, var(--acc) 10%, transparent)' }
          : undefined
      }
    >
      {def.chip}
    </div>
  );
  return (
    <div className="flex items-center gap-3 border-b border-border py-[11px]">
      <CelebratedChip isNew={isNew}>{chip}</CelebratedChip>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-1.5 truncate text-[13.5px] font-semibold text-foreground">
          {t(def.titleKey)}
          {isNew && <NewBadge />}
        </div>
        <div className="mt-[1px] truncate text-[11.5px] text-muted-foreground">
          {best
            ? [bestActivity?.name, formatMonthDayYear(new Date(best.startDate))]
                .filter(Boolean)
                .join(' · ')
            : t('records.noRecordYet')}
        </div>
      </div>
      <div className="flex-none text-right">
        <div className="text-[15px] font-bold text-foreground">
          {best ? formatHms(best.movingTime) : '—'}
        </div>
        {best && (
          <div className="mt-[1px] text-[11.5px] text-muted-foreground">
            {formatPace(best.movingTime / (best.distance / 1000))}
          </div>
        )}
      </div>
    </div>
  );
}

function RecordCell({
  def,
  records,
  activityById,
  expanded,
  onToggle,
  last,
  isNew,
}: {
  def: (typeof DISTANCES)[number];
  records: PersonalBestRecord[];
  activityById: Map<string, Activity>;
  expanded: boolean;
  onToggle: () => void;
  last: boolean;
  isNew: boolean;
}) {
  const { t } = useTranslation('overview');
  const best = records[0];
  const runnersUp = records.slice(1);
  const bestActivity = best ? activityById.get(best.activityId) : undefined;

  return (
    <div className={last ? '' : 'border-b border-border'}>
      <div
        onClick={runnersUp.length > 0 ? onToggle : undefined}
        className={`flex items-center gap-2.5 py-[11px] ${
          runnersUp.length > 0 ? 'cursor-pointer' : ''
        }`}
        aria-expanded={runnersUp.length > 0 ? expanded : undefined}
      >
        <CelebratedChip isNew={isNew}>
          <Chip label={def.chip} muted={!best} />
        </CelebratedChip>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-1.5 truncate text-[12.5px] font-semibold text-foreground">
            {t(def.titleKey)}
            {isNew && <NewBadge />}
          </div>
          {/* name and date on separate lines — the narrow cell can't fit
              both inline, and the date must never be the part that truncates */}
          {best ? (
            <>
              {bestActivity && (
                <div
                  className="mt-[1px] truncate text-[11px] text-muted-foreground"
                  title={bestActivity.name}
                >
                  {bestActivity.name}
                </div>
              )}
              <div className="mt-[1px] text-[11px] whitespace-nowrap text-muted-foreground">
                {formatMonthDayYear(new Date(best.startDate))}
              </div>
            </>
          ) : (
            <div className="mt-[1px] text-[11px] text-muted-foreground">
              {t('records.noRecordYet')}
            </div>
          )}
        </div>
        <div className="flex-none text-right">
          <div className="text-[15px] font-bold text-foreground">
            {best ? formatHms(best.movingTime) : '—'}
          </div>
          {best && (
            <div className="mt-[1px] text-[11px] text-muted-foreground">
              {formatPace(best.movingTime / (best.distance / 1000))}
            </div>
          )}
        </div>
        {runnersUp.length > 0 && (
          <span
            className="flex-none text-[13px] text-muted-foreground motion-safe:transition-transform motion-safe:duration-150"
            style={{ transform: expanded ? 'rotate(90deg)' : 'rotate(0deg)' }}
          >
            ›
          </span>
        )}
      </div>
      {expanded && (
        <div className="pb-3">
          {runnersUp.map((r) => {
            const activity = activityById.get(r.activityId);
            return (
              <div
                key={r.rank}
                className="flex items-center gap-2 py-[3px] text-[11.5px]"
              >
                <span className="w-[16px] flex-none font-semibold text-muted-foreground">
                  {r.rank}º
                </span>
                <span className="flex-none font-semibold text-foreground">
                  {formatHms(r.movingTime)}
                </span>
                <span
                  className="flex min-w-0 flex-1 items-baseline text-muted-foreground"
                  title={activity?.name}
                >
                  {activity && (
                    <span className="min-w-0 truncate">
                      {activity.name}&nbsp;·&nbsp;
                    </span>
                  )}
                  <span className="flex-none">
                    {formatMonthDayYear(new Date(r.startDate))}
                  </span>
                </span>
                {r.prRank === 1 && (
                  <span
                    className="flex-none rounded-[6px] px-[5px] py-[1px] text-[9.5px] font-bold text-acc"
                    style={{
                      background:
                        'color-mix(in oklab, var(--acc) 10%, transparent)',
                    }}
                    title={t('records.prBadgeTitle')}
                  >
                    {t('records.prBadge')}
                  </span>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

export default function PersonalRecordsCard({
  activities,
}: PersonalRecordsCardProps) {
  const { t } = useTranslation('overview');
  const [records, setRecords] = useState<PersonalBestRecord[]>([]);
  const [expandedKey, setExpandedKey] = useState<string | null>(null);
  const [showAll, setShowAll] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [newKeys, setNewKeys] = useState<string[]>([]);
  const { user } = useAuth();
  const userId = user?.id;
  // rows rise in once the records are in, once per session
  const { attach: enterRef, state: enterState } = useEntrance(
    'run/overview:records',
    { ready: loaded },
  );

  useEffect(() => {
    apiFetch('/personal-bests')
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((data: PersonalBestRecord[]) => {
        setRecords(data);
        // only a successful fetch moves the snapshot — writing the empty
        // list from a failed one would make every record "new" next time
        if (!userId) return;
        const next = topRecordIdentities(data);
        const keys = newRecordKeys(readPrSnapshot(userId), next);
        writePrSnapshot(userId, next);
        // StrictMode's second fetch reads the snapshot the first one just
        // wrote and finds nothing new — keep what the first one found
        setNewKeys((cur) => (keys.length > 0 ? keys : cur));
      })
      .catch(() => setRecords([]))
      .finally(() => setLoaded(true));
  }, [userId]);

  useEffect(() => {
    if (!showAll) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setShowAll(false);
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [showAll]);

  const activityById = new Map(activities.map((a) => [a.id, a]));

  const byName = new Map<string, PersonalBestRecord[]>();
  for (const r of records) {
    const key = r.name.toLowerCase();
    const list = byName.get(key) ?? [];
    list.push(r);
    byName.set(key, list);
  }
  for (const list of byName.values()) {
    list.sort((a, b) => a.rank - b.rank);
  }

  const columns = Array.from({ length: COLUMNS }, (_, c) =>
    DISTANCES.slice(c * PER_COLUMN, (c + 1) * PER_COLUMN),
  );

  const longest = activities.reduce<Activity | null>(
    (best, a) => ((a.distanceKm ?? 0) > (best?.distanceKm ?? 0) ? a : best),
    null,
  );

  return (
    <div
      ref={enterRef}
      data-enter={enterState}
      className="rounded-[12px] border border-border bg-card p-[18px_20px] max-md:rounded-none max-md:border-x-0 max-md:border-b-0 max-md:bg-transparent max-md:px-0"
    >
      <div className="flex items-center justify-between">
        <div className="text-[13.5px] font-semibold text-foreground">
          {t('records.title')}
        </div>
        <div className="hidden text-[11.5px] text-muted-foreground md:block">
          {t('records.subtitle')}
        </div>
        <button
          onClick={() => setShowAll(true)}
          aria-label={t('records.viewAllAriaLabel')}
          className="flex cursor-pointer items-center gap-1 rounded-full bg-chip px-2.5 py-1 text-[11.5px] font-medium text-foreground md:hidden"
        >
          <List className="h-3.5 w-3.5" strokeWidth={2} />
          {t('records.viewAll')}
        </button>
      </div>

      {/* mobile — headline distances only, single column */}
      <div className="mt-1 md:hidden">
        {DISTANCES.filter((d) => MOBILE_KEYS.includes(d.key)).map((def, i) => (
          <div
            key={def.key}
            className="enter-rise"
            style={{ '--i': i } as CSSProperties}
          >
            <MobileRecordRow
              def={def}
              best={byName.get(def.key)?.[0]}
              activityById={activityById}
              isNew={newKeys.includes(def.key)}
            />
          </div>
        ))}
      </div>

      <div className="mt-1 hidden grid-cols-3 gap-x-5 md:grid">
        {columns.map((defs, c) => (
          <div
            key={c}
            className={`enter-rise ${c > 0 ? 'border-l border-border pl-5' : ''}`}
            style={{ '--i': c } as CSSProperties}
          >
            {defs.map((def, i) => (
              <RecordCell
                key={def.key}
                def={def}
                records={byName.get(def.key) ?? []}
                activityById={activityById}
                expanded={expandedKey === def.key}
                onToggle={() =>
                  setExpandedKey(expandedKey === def.key ? null : def.key)
                }
                last={i === defs.length - 1}
                isNew={newKeys.includes(def.key)}
              />
            ))}
          </div>
        ))}
      </div>

      {longest && (
        <div className="flex items-center gap-3 pt-3 md:border-t md:border-border">
          <div
            className="flex h-[38px] w-[38px] flex-none items-center justify-center rounded-[10px] text-[10.5px] font-bold text-acc md:h-[34px] md:w-[42px]"
            style={{
              background: 'color-mix(in oklab, var(--acc) 10%, transparent)',
            }}
          >
            {t('records.max')}
          </div>
          <div className="min-w-0 flex-1">
            <div className="text-[13.5px] font-semibold text-foreground md:text-[12.5px]">
              {t('records.longestRun')}
            </div>
            <div className="mt-[1px] truncate text-[11.5px] text-muted-foreground md:text-[11px]">
              {longest.name} · {formatMonthDayYear(new Date(longest.startDate))}
            </div>
          </div>
          <div className="flex-none text-right">
            <div className="text-[15px] font-bold text-foreground">
              {formatDistance(longest.distanceKm ?? 0)} {distanceLabel()}
            </div>
            <div className="mt-[1px] text-[11px] text-muted-foreground">
              {formatDurationShort(longest.movingTimeSec)}
            </div>
          </div>
        </div>
      )}

      {showAll && (
        <>
          <div
            className="fixed inset-0 z-40 bg-[rgba(8,12,20,.35)] md:hidden dark:bg-[rgba(4,7,12,.55)]"
            onClick={() => setShowAll(false)}
          />
          <div
            className="fixed inset-x-0 bottom-0 z-50 max-h-[80vh] overflow-y-auto overscroll-contain rounded-t-[20px] border bg-card p-5 pb-[calc(20px+env(safe-area-inset-bottom))] md:hidden"
            style={{
              borderColor: 'var(--grid-ax)',
              boxShadow: '0 12px 32px rgba(8,12,20,.16)',
            }}
          >
            <div className="mb-2 flex items-center justify-between">
              <div className="text-[14px] font-semibold text-foreground">
                {t('records.allRecordsTitle')}
              </div>
              <button
                onClick={() => setShowAll(false)}
                aria-label={t('records.closeAriaLabel')}
                className="flex h-8 w-8 cursor-pointer items-center justify-center rounded-full text-muted-foreground hover:bg-chip"
              >
                <X className="h-[18px] w-[18px]" strokeWidth={1.8} />
              </button>
            </div>
            {DISTANCES.map((def, i) => (
              <RecordCell
                key={def.key}
                def={def}
                records={byName.get(def.key) ?? []}
                activityById={activityById}
                expanded={expandedKey === def.key}
                onToggle={() =>
                  setExpandedKey(expandedKey === def.key ? null : def.key)
                }
                last={i === DISTANCES.length - 1}
                isNew={newKeys.includes(def.key)}
              />
            ))}
          </div>
        </>
      )}
    </div>
  );
}

import { useTranslation } from 'react-i18next';
import {
  WORKOUT_META,
  formatDuration,
  formatKm,
  formatNumber,
  formatPace,
} from '@/lib/activityFormat';
import { useAuth } from '@/features/auth/AuthContext';
import { API_BASE_URL } from '@/lib/apiUrl';
import { ConnectWithStrava } from '@/components/StravaBrand';
import SyncPanel from './SyncPanel';
import { TYPE_OPTIONS, type TypeFilter } from './bins';

function ConnectStravaBanner() {
  const { t } = useTranslation('dashboard');
  return (
    <div className="mt-[26px]">
      <div className="mb-2.5 text-[11.5px] font-medium tracking-[.05em] uppercase text-muted-foreground">
        {t('sync.title')}
      </div>
      <p className="mb-3 text-[12.5px] text-muted-foreground">
        {t('connectBanner.message')}
      </p>
      <ConnectWithStrava href={`${API_BASE_URL}/strava/connect`} />
    </div>
  );
}

function RailStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between border-b border-border py-[13px]">
      <div className="text-[13px] text-muted-foreground">{label}</div>
      <div className="text-[15px] font-semibold text-foreground">{value}</div>
    </div>
  );
}

interface RailProps {
  subtitle: string;
  totals: { km: number; sec: number; count: number; elev: number };
  avgPace: number | null;
  typeFilter: TypeFilter;
  onTypeFilter: (type: TypeFilter) => void;
  typeCounts: Record<string, number>;
  onSynced: () => void;
}

export default function Rail({
  subtitle,
  totals,
  avgPace,
  typeFilter,
  onTypeFilter,
  typeCounts,
  onSynced,
}: RailProps) {
  const { t } = useTranslation('dashboard');
  const { user } = useAuth();
  return (
    <div className="flex flex-col">
      <div className="text-2xl font-semibold tracking-[-.02em] text-foreground">
        {t('rail.title')}
      </div>
      <div className="mt-[3px] text-[13px] text-muted-foreground">
        {subtitle}
      </div>

      <div className="mt-8">
        <div className="text-[52px] leading-none font-bold tracking-[-.03em] text-foreground">
          {formatKm(totals.km)}
        </div>
        <div className="mt-1.5 text-[13.5px] text-muted-foreground">
          {t('rail.kmSubtitle')}
        </div>
      </div>

      <div className="mt-7 border-t border-border">
        <RailStat label={t('rail.activities')} value={String(totals.count)} />
        <RailStat label={t('rail.averagePace')} value={formatPace(avgPace)} />
        <RailStat label={t('rail.totalTime')} value={formatDuration(totals.sec)} />
        <RailStat
          label={t('rail.elevationGain')}
          value={`${formatNumber(Math.round(totals.elev))} m`}
        />
      </div>

      <div className="mt-[26px]">
        <div className="mb-2.5 text-[11.5px] font-medium tracking-[.05em] uppercase text-muted-foreground">
          {t('rail.workoutType')}
        </div>
        <div className="flex flex-col gap-1.5">
          {TYPE_OPTIONS.map(([key, labelKey]) => {
            const active = typeFilter === key;
            return (
              <button
                key={key}
                onClick={() => onTypeFilter(key)}
                className={`flex cursor-pointer items-center gap-2.5 rounded-[10px] border px-[13px] py-[9px] text-left text-[13px] font-medium ${
                  active
                    ? 'border-grid-ax bg-card text-foreground'
                    : 'border-transparent text-muted-foreground'
                }`}
              >
                <span
                  className="h-[7px] w-[7px] rounded-full"
                  style={{
                    background:
                      key === 'ALL'
                        ? 'var(--muted-foreground)'
                        : WORKOUT_META[key].dot,
                  }}
                />
                {t(labelKey)}
                <span className="ml-auto font-normal text-muted-foreground">
                  {typeCounts[key] ?? 0}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {user?.hasStravaAccount ? (
        <SyncPanel onSynced={onSynced} />
      ) : (
        <ConnectStravaBanner />
      )}
    </div>
  );
}

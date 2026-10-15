import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { apiFetch } from '@/lib/api';
import type { SyncStatus } from '@/lib/types';

interface SyncPanelProps {
  onSynced: () => void;
}

const POLL_MS = 2000;

export default function SyncPanel({ onSynced }: SyncPanelProps) {
  const { t } = useTranslation('dashboard');

  const formatEta = (sec: number): string => {
    if (sec >= 3600) {
      const h = Math.floor(sec / 3600);
      const m = Math.round((sec % 3600) / 60);
      return t('sync.etaHoursMin', { h, m });
    }
    if (sec >= 60) {
      const m = Math.floor(sec / 60);
      const s = sec % 60;
      return t('sync.etaMinSec', { m, s });
    }
    return t('sync.etaSec', { s: sec });
  };

  const [status, setStatus] = useState<SyncStatus | null>(null);
  // whether this session watched the current/last sync run (avoids showing a
  // stale "sync complete" message from a run that finished before page load)
  const [watching, setWatching] = useState(false);
  const [requestError, setRequestError] = useState<string | null>(null);
  const onSyncedRef = useRef(onSynced);
  onSyncedRef.current = onSynced;

  const running = status?.state === 'running';

  useEffect(() => {
    apiFetch('/strava/sync/status')
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((s: SyncStatus) => {
        setStatus(s);
        if (s.state === 'running') setWatching(true);
      })
      .catch(() => {
        // status is cosmetic on load; the button will surface real errors
      });
  }, []);

  useEffect(() => {
    if (!running) return;
    const id = setInterval(() => {
      apiFetch('/strava/sync/status')
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.json();
        })
        .then((s: SyncStatus) => {
          setStatus(s);
          if (s.state !== 'running') onSyncedRef.current();
        })
        .catch(() => {});
    }, POLL_MS);
    return () => clearInterval(id);
  }, [running]);

  const startSync = () => {
    setRequestError(null);
    setWatching(true);
    apiFetch('/strava/sync', { method: 'POST' })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then((s: SyncStatus) => setStatus(s))
      .catch((err) => setRequestError(err.message));
  };

  const total = status?.total ?? null;
  const processed = status?.processed ?? 0;
  const synced = status?.synced ?? 0;
  const errors = status?.errors ?? 0;
  const percent =
    total == null ? 0 : total === 0 ? 100 : (processed / total) * 100;

  let statusLine: string;
  let statusTone = 'text-muted-foreground';
  if (requestError) {
    statusLine = t('sync.failureToStart', { message: requestError });
    statusTone = 'text-neg';
  } else if (running && status?.phase === 'listing') {
    statusLine = t('sync.searching');
  } else if (running && status?.phase === 'rate_limited') {
    statusLine = t('sync.rateLimited');
    statusTone = 'text-neg';
  } else if (running) {
    statusLine =
      total != null
        ? t('sync.savedOfTotal', { synced, total }) +
          (errors > 0 ? t('sync.withErrors', { count: errors }) : '')
        : t('sync.processing');
  } else if (watching && status?.state === 'done') {
    statusLine =
      total === 0
        ? t('sync.syncedNothingNew')
        : t('sync.syncedNewActivity', { count: synced }) +
          (errors > 0 ? t('sync.errorsSuffix', { count: errors }) : '');
  } else if (watching && status?.state === 'error') {
    statusLine = t('sync.syncFailure', {
      message: status.message ?? t('sync.unknownError'),
    });
    statusTone = 'text-neg';
  } else {
    statusLine = t('sync.syncNew');
  }

  return (
    <div className="mt-[26px]">
      <div className="mb-2.5 text-[11.5px] font-medium tracking-[.05em] uppercase text-muted-foreground">
        {t('sync.title')}
      </div>
      <div className="flex items-center justify-between gap-2.5">
        <p className={`min-w-0 text-[12.5px] ${statusTone}`}>{statusLine}</p>
        <button
          onClick={startSync}
          disabled={running}
          className="shrink-0 cursor-pointer rounded-[9px] bg-chip px-[13px] py-1.5 text-[12.5px] font-medium text-foreground hover:bg-grid-ax disabled:cursor-not-allowed disabled:opacity-50"
        >
          {running ? t('sync.syncing') : t('sync.sync')}
        </button>
      </div>

      {running && (
        <div className="mt-2.5">
          <div className="h-1.5 w-full overflow-hidden rounded-full bg-chip">
            {total == null ? (
              <div className="h-full w-1/3 animate-pulse rounded-full bg-acc" />
            ) : (
              // progress → linear; clip-path reveal instead of width (layout)
              <div
                className="h-full bg-acc ease-linear motion-safe:transition-[clip-path] motion-safe:duration-700"
                style={{ clipPath: `inset(0 ${100 - percent}% 0 0 round 999px)` }}
              />
            )}
          </div>
          {status?.etaSeconds != null && (
            <div className="mt-1.5 text-[11px] text-muted-foreground">
              {formatEta(status.etaSeconds)}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

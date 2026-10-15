import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { ActivityDetail } from '@/lib/types';
import { useLapEditor } from './useLapEditor';
import LapEditorRow from './LapEditorRow';
import LapEditorToolbar from './LapEditorToolbar';

interface LapEditorPanelProps {
  activity: ActivityDetail;
  onClose: () => void;
  onSaved: (updated: ActivityDetail) => void;
}

export default function LapEditorPanel({
  activity,
  onClose,
  onSaved,
}: LapEditorPanelProps) {
  const { t } = useTranslation('activity');
  const editor = useLapEditor(activity.id, activity.laps);
  const [editingKey, setEditingKey] = useState<string | null>(null);
  const [confirmingClose, setConfirmingClose] = useState(false);
  const [dragKey, setDragKey] = useState<string | null>(null);
  const lastKey = editor.resolved.length > 0
    ? editor.resolved[editor.resolved.length - 1].key
    : null;

  // drag-to-reorder: reorders live as the pointer crosses into another row
  // (via elementFromPoint + data-lap-key, set by LapEditorRow), not just on
  // drop — works for both mouse and touch since it's driven by Pointer Events
  useEffect(() => {
    if (!dragKey) return;
    const onMove = (e: PointerEvent) => {
      const el = document
        .elementFromPoint(e.clientX, e.clientY)
        ?.closest<HTMLElement>('[data-lap-key]');
      const overKey = el?.dataset.lapKey;
      if (overKey && overKey !== dragKey) {
        editor.reorderLap(dragKey, overKey);
      }
    };
    const onUp = () => setDragKey(null);
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('pointercancel', onUp);
    return () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      window.removeEventListener('pointercancel', onUp);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dragKey]);

  const requestClose = () => {
    if (editor.dirty) {
      setConfirmingClose(true);
      return;
    }
    onClose();
  };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') requestClose();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [editor.dirty]);

  async function handleSave() {
    try {
      const updated = await editor.save();
      onSaved(updated);
    } catch {
      // surfaced inline via editor.saveError
    }
  }

  const progressPct =
    editor.progress.totalM > 0
      ? Math.min(100, (editor.progress.coveredM / editor.progress.totalM) * 100)
      : 0;

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-page-bg md:items-center md:justify-center md:bg-[rgba(8,12,20,.35)]">
      <div className="flex h-full w-full flex-col overflow-hidden bg-card md:h-auto md:max-h-[88vh] md:w-full md:max-w-3xl md:rounded-[var(--rad)] md:border md:border-border">
        <div className="flex items-center justify-between border-b border-border px-5 py-4">
          <div className="text-[15px] font-semibold text-foreground">
            {t('laps.edit')}
          </div>
          <button
            type="button"
            onClick={requestClose}
            aria-label={t('laps.close')}
            className="cursor-pointer rounded-[8px] p-1.5 text-[15px] text-muted-foreground hover:bg-chip hover:text-foreground"
          >
            ×
          </button>
        </div>

        {confirmingClose && (
          <div className="flex items-center justify-between gap-3 border-b border-border bg-chip px-5 py-3">
            <span className="text-[13px] text-foreground">
              {t('laps.discardConfirm')}
            </span>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setConfirmingClose(false)}
                className="cursor-pointer rounded-[8px] px-2.5 py-1 text-[12.5px] font-medium text-muted-foreground hover:text-foreground"
              >
                {t('laps.keepEditing')}
              </button>
              <button
                type="button"
                onClick={onClose}
                className="cursor-pointer rounded-[8px] bg-neg px-2.5 py-1 text-[12.5px] font-medium text-white"
              >
                {t('laps.discard')}
              </button>
            </div>
          </div>
        )}

        <div className="flex-1 overflow-y-auto overscroll-contain px-5 py-3">
          {editor.streamLoading && (
            <p className="py-10 text-center text-[13.5px] text-muted-foreground">
              {t('laps.streamLoading')}
            </p>
          )}

          {editor.streamError && !editor.streamLoading && (
            <div className="flex flex-col items-center gap-3 py-10 text-center">
              <p className="text-[13.5px] text-neg">{t('laps.streamError')}</p>
              <button
                type="button"
                onClick={editor.retryStream}
                className="cursor-pointer rounded-[8px] bg-chip px-3 py-1.5 text-[12.5px] font-medium text-foreground hover:bg-grid-ax"
              >
                {t('laps.retry')}
              </button>
            </div>
          )}

          {!editor.streamLoading && !editor.streamError && (
            <>
              <LapEditorToolbar
                onAddLap={(lap) => editor.insertLap(lastKey, lap)}
                onAddReps={(count, workout, rest) =>
                  editor.insertReps(lastKey, count, workout, rest)
                }
              />

              <div className="flex items-center gap-1.5 px-0.5 pb-[7px] text-[11px] tracking-[.03em] uppercase text-muted-foreground md:gap-[13px]">
                <div className="w-[22px]">{t('laps.index')}</div>
                <div className="w-[84px] md:w-[110px]">{t('laps.lap')}</div>
                <div className="hidden flex-1 md:block" />
                <div className="w-[58px] text-right md:w-[66px]">
                  {t('laps.dist')}
                </div>
                <div className="w-11 text-right md:w-14">{t('laps.time')}</div>
                <div className="w-14 text-right md:w-16">{t('laps.pace')}</div>
                <div className="hidden w-11 text-right md:block">
                  {t('laps.spm')}
                </div>
                <div className="w-11 text-right">{t('laps.avgHr')}</div>
                <div className="hidden w-11 text-right md:block">
                  {t('laps.maxHr')}
                </div>
                <div className="ml-1 w-16" />
              </div>

              {editor.resolved.map((lap, i) => (
                <LapEditorRow
                  key={lap.key}
                  resolved={lap}
                  points={editor.points}
                  index={i + 1}
                  isEditing={editingKey === lap.key}
                  isDragging={dragKey === lap.key}
                  onStartEdit={() => setEditingKey(lap.key)}
                  onCommit={(patch) => {
                    editor.updateLap(lap.key, patch);
                    setEditingKey(null);
                  }}
                  onCancelEdit={() => setEditingKey(null)}
                  onDelete={() => editor.deleteLap(lap.key)}
                  onDragStart={(e) => {
                    e.preventDefault();
                    setDragKey(lap.key);
                  }}
                />
              ))}

              {editor.resolved.length === 0 && (
                <p className="py-8 text-center text-[13px] text-muted-foreground">
                  {t('laps.empty')}
                </p>
              )}
            </>
          )}
        </div>

        <div className="border-t border-border px-5 py-4 pb-[calc(16px+env(safe-area-inset-bottom))]">
          <div className="mb-2.5 flex items-center justify-between text-[12px] text-muted-foreground">
            <span>{t('laps.progress')}</span>
            <span
              className={
                editor.progress.isComplete
                  ? 'font-medium text-pos'
                  : 'text-foreground'
              }
            >
              {(editor.progress.coveredM / 1000).toFixed(2)} /{' '}
              {(editor.progress.totalM / 1000).toFixed(2)} km
            </span>
          </div>
          <div className="mb-3 h-1.5 overflow-hidden rounded-[3px] bg-chip">
            {/* clip-path reveal instead of width: no layout per edit */}
            <div
              className="h-full ease-[var(--motion-ease-out)] motion-safe:transition-[clip-path] motion-safe:duration-150"
              style={{
                clipPath: `inset(0 ${100 - progressPct}% 0 0 round 3px)`,
                background: editor.progress.isComplete
                  ? 'var(--pos)'
                  : 'var(--acc)',
              }}
            />
          </div>

          {editor.saveError && (
            <p className="mb-2 text-[12.5px] text-neg">
              {t('common:error', { message: editor.saveError })}
            </p>
          )}

          <div className="flex items-center justify-end gap-2">
            <button
              type="button"
              onClick={requestClose}
              className="cursor-pointer rounded-[9px] px-3 py-2 text-[13px] font-medium text-muted-foreground hover:text-foreground"
            >
              {t('laps.cancel')}
            </button>
            <button
              type="button"
              onClick={handleSave}
              disabled={!editor.canSave}
              className="press cursor-pointer rounded-[9px] bg-acc px-4 py-2 text-[13px] font-semibold text-white disabled:cursor-not-allowed disabled:opacity-40"
            >
              {editor.saving ? t('laps.saving') : t('laps.save')}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

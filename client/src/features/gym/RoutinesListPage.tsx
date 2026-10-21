import type { CSSProperties } from 'react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Pencil, Plus, Trash2 } from 'lucide-react';
import type { TemplateSummary } from '@/lib/types';
import { useWorkoutTemplates } from './useWorkoutTemplates';
import { formatLastPerformed } from './relativeTime';
import RoutineWorkoutToggleButton from './RoutineWorkoutToggleButton';
import RoutineDetailPage from './RoutineDetailPage';
import DrillStack from '@/components/DrillStack';
import { useEntrance } from '@/lib/useEntrance';
import { DelayedSkeleton, Skeleton } from '@/components/Skeleton';

interface RoutinesListPageProps {
  onCreateNew: () => void;
  onEdit: (templateId: string) => void;
  onStartWorkout: (templateId: string) => void;
  /** open this routine's detail as soon as the list has it (from Treino overview) */
  initialTemplateId?: string | null;
}

export default function RoutinesListPage({
  onCreateNew,
  onEdit,
  onStartWorkout,
  initialTemplateId = null,
}: RoutinesListPageProps) {
  const { t } = useTranslation('gym');
  const { templates, loading, error, remove } = useWorkoutTemplates();
  // routine cards rise in, once per session
  const { attach: enterRef, state: enterState } = useEntrance('gym/workouts', { ready: !loading });
  const [confirmingId, setConfirmingId] = useState<string | null>(null);
  // read-only routine detail, opened by tapping a card (see the card's
  // onClick below) — holds the already-fetched summary so the detail screen
  // doesn't need to refetch the list just for the chips/meta line
  const [viewingTemplate, setViewingTemplate] = useState<TemplateSummary | null>(null);
  // adjusted during render (not in an effect) once the list arrives — same
  // "derive from props" pattern DrillStack uses for its depth tracking
  const [pendingOpenId, setPendingOpenId] = useState(initialTemplateId);
  if (pendingOpenId && !loading) {
    setPendingOpenId(null);
    const found = templates.find((tpl) => tpl.id === pendingOpenId);
    if (found) setViewingTemplate(found);
  }

  // while the list loads, the stack already sits on that routine's screen
  // (same key, empty body) so the detail appears in place instead of
  // pushing over a half-loaded list
  const openId = viewingTemplate?.id ?? pendingOpenId;

  return (
    <DrillStack depth={openId ? 1 : 0} viewKey={openId ? `routine:${openId}` : 'list'}>
      {!viewingTemplate && pendingOpenId ? (
        <div className="min-h-[60vh]" />
      ) : viewingTemplate ? (
        <RoutineDetailPage
          template={viewingTemplate}
          onStart={() => onStartWorkout(viewingTemplate.id)}
          onBack={() => setViewingTemplate(null)}
          onEdit={() => onEdit(viewingTemplate.id)}
          onDelete={() => {
            remove(viewingTemplate.id);
            setViewingTemplate(null);
          }}
        />
      ) : (
        <div ref={enterRef} data-enter={enterState} className="px-5 pt-[18px] pb-[44px]">
          <div className="flex items-center justify-between gap-3">
            <span className="text-[12.5px] font-medium text-muted-foreground">
              {t('start.savedRoutinesCount', { count: templates.length })}
            </span>
            <button
              type="button"
              onClick={onCreateNew}
              className="flex cursor-pointer items-center gap-1 rounded-[10px] border border-border bg-card p-[8px_12px] text-[12.5px] font-semibold text-foreground hover:bg-chip"
            >
              <Plus className="h-[13px] w-[13px]" strokeWidth={2} />
              {t('routines.new')}
            </button>
          </div>

          {error && <p className="mt-3 text-[12.5px] text-neg">{error}</p>}
          {loading && (
            <DelayedSkeleton>
              <div className="mt-4 flex flex-col gap-3">
                {[0, 1, 2].map((i) => (
                  <Skeleton key={i} className="h-[112px] rounded-[14px]" />
                ))}
              </div>
            </DelayedSkeleton>
          )}
          {!loading && templates.length === 0 && (
            <p className="mt-8 text-center text-[13.5px] text-muted-foreground">
              {t('routines.empty')}
            </p>
          )}

          {templates.map((tpl, i) => (
            <div
              key={tpl.id}
              onClick={() => setViewingTemplate(tpl)}
              style={{ '--i': i } as CSSProperties}
              className="enter-rise mt-4 cursor-pointer rounded-[14px] border border-border bg-card p-[16px]"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="text-[15px] font-semibold tracking-[-.01em] text-foreground">
                  {tpl.name}
                </div>
                <div className="flex flex-none items-center gap-1.5">
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      onEdit(tpl.id);
                    }}
                    aria-label={t('editor.editTitle')}
                    className="flex h-[30px] w-[30px] cursor-pointer items-center justify-center rounded-[8px] bg-chip text-muted-foreground hover:text-foreground"
                  >
                    <Pencil className="h-3.5 w-3.5" strokeWidth={1.8} />
                  </button>
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      setConfirmingId(tpl.id);
                    }}
                    aria-label={t('routines.delete')}
                    className="flex h-[30px] w-[30px] cursor-pointer items-center justify-center rounded-[8px] bg-chip text-muted-foreground hover:text-neg"
                  >
                    <Trash2 className="h-3.5 w-3.5" strokeWidth={1.8} />
                  </button>
                </div>
              </div>

              {confirmingId === tpl.id && (
                <div
                  onClick={(e) => e.stopPropagation()}
                  className="mt-2 flex items-center gap-2.5 text-[12px]"
                >
                  <span className="text-muted-foreground">{t('routines.deleteConfirm')}</span>
                  <button
                    type="button"
                    onClick={() => setConfirmingId(null)}
                    className="cursor-pointer font-medium text-muted-foreground hover:text-foreground"
                  >
                    {t('routines.cancel')}
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      remove(tpl.id);
                      setConfirmingId(null);
                    }}
                    className="cursor-pointer font-medium text-neg"
                  >
                    {t('routines.delete')}
                  </button>
                </div>
              )}

              {tpl.muscleGroups.length > 0 && (
                <div className="mt-2.5 flex flex-wrap gap-[6px]">
                  {tpl.muscleGroups.map((mg) => (
                    <span
                      key={mg}
                      className="rounded-full bg-chip p-[4px_9px] text-[10.5px] font-semibold text-muted-foreground"
                    >
                      {t(`muscles.${mg}`, mg)}
                    </span>
                  ))}
                </div>
              )}

              <div className="mt-2 text-[12px] text-muted-foreground">
                {t('routines.exerciseCount', { count: tpl.exerciseCount })} ·{' '}
                {tpl.lastPerformedAt
                  ? t('routines.lastPerformed', { when: formatLastPerformed(t, tpl.lastPerformedAt) })
                  : t('routines.neverPerformed')}
              </div>

              <div onClick={(e) => e.stopPropagation()}>
                <RoutineWorkoutToggleButton onClick={() => onStartWorkout(tpl.id)} />
              </div>
            </div>
          ))}

          <button
            type="button"
            onClick={onCreateNew}
            className="mt-4 flex w-full cursor-pointer items-center justify-center rounded-[14px] border border-dashed border-border p-[18px] text-[13px] font-semibold text-muted-foreground hover:border-acc hover:text-acc-tx"
          >
            {t('routines.createNew')}
          </button>
        </div>
      )}
    </DrillStack>
  );
}

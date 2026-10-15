import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Search, X } from 'lucide-react';
import { apiFetch } from '@/lib/api';
import type { ExerciseListItem, ExercisesResponse } from '@/lib/types';

interface ExercisePickerProps {
  onClose: () => void;
  // full item (not just the id) — routine editor's create mode needs the
  // name to render a local, not-yet-persisted row
  onPick: (exercise: ExerciseListItem) => void;
}

const SEARCH_DEBOUNCE_MS = 250;

export default function ExercisePicker({ onClose, onPick }: ExercisePickerProps) {
  const { t } = useTranslation('gym');
  const [search, setSearch] = useState('');
  const [items, setItems] = useState<ExerciseListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    const handle = setTimeout(() => {
      const qs = search.trim()
        ? `?search=${encodeURIComponent(search.trim())}&limit=30`
        : '?limit=30';
      apiFetch(`/exercises${qs}`)
        .then((res) => {
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return res.json() as Promise<ExercisesResponse>;
        })
        .then((data) => {
          if (!cancelled) setItems(data.items);
        })
        .catch(() => {
          if (!cancelled) setItems([]);
        })
        .finally(() => {
          if (!cancelled) setLoading(false);
        });
    }, SEARCH_DEBOUNCE_MS);
    return () => {
      cancelled = true;
      clearTimeout(handle);
    };
  }, [search]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-page-bg md:items-center md:justify-center md:bg-[rgba(8,12,20,.35)]">
      <div className="flex h-full w-full flex-col overflow-hidden bg-card md:h-auto md:max-h-[80vh] md:w-full md:max-w-md md:rounded-[var(--rad)] md:border md:border-border">
        <div className="flex items-center gap-2 border-b border-border px-4 py-3 pt-[calc(12px+env(safe-area-inset-top))] md:pt-3">
          <Search className="h-4 w-4 flex-none text-muted-foreground" strokeWidth={1.8} />
          <input
            ref={inputRef}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t('picker.searchPlaceholder')}
            className="h-10 flex-1 bg-transparent text-[16px] text-foreground outline-none placeholder:text-muted-foreground md:text-[15px]"
          />
          <button
            type="button"
            onClick={onClose}
            aria-label={t('picker.close')}
            className="cursor-pointer rounded-[8px] p-1.5 text-muted-foreground hover:bg-chip hover:text-foreground"
          >
            <X className="h-4 w-4" strokeWidth={1.8} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto overscroll-contain px-2 py-2">
          {loading && (
            <p className="py-8 text-center text-[13px] text-muted-foreground">
              {t('picker.loading')}
            </p>
          )}
          {!loading && items.length === 0 && (
            <p className="py-8 text-center text-[13px] text-muted-foreground">
              {t('picker.empty')}
            </p>
          )}
          {!loading &&
            items.map((ex) => (
              <button
                key={ex.id}
                type="button"
                onClick={() => onPick(ex)}
                className="flex min-h-[52px] w-full cursor-pointer flex-col items-start justify-center rounded-[10px] px-3 py-2 text-left hover:bg-chip"
              >
                <span className="text-[14px] font-medium text-foreground">{ex.name}</span>
                {(ex.equipment || ex.primaryMuscles[0]) && (
                  <span className="text-[11.5px] text-muted-foreground">
                    {[ex.equipment, ex.primaryMuscles[0]].filter(Boolean).join(' · ')}
                  </span>
                )}
              </button>
            ))}
        </div>
      </div>
    </div>
  );
}

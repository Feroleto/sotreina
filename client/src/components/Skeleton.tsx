import { useState } from 'react';
import type { CSSProperties, ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { cn } from '@/lib/utils';
import { useDelayedFlag } from '@/lib/useDelayedFlag';

/** one placeholder block — size it with className/style like the real thing */
export function Skeleton({
  className,
  style,
}: {
  className?: string;
  style?: CSSProperties;
}) {
  return (
    <div
      aria-hidden
      className={cn('skeleton rounded-[6px]', className)}
      style={style}
    />
  );
}

/**
 * Loading → content swap: nothing for the first 150ms, then `skeleton`, and
 * the real content fades in when it arrives. Content that was ready on mount
 * (boot prefetch, cached) appears as-is, with no fade.
 */
export function LoadingSwap({
  loading,
  skeleton,
  children,
  className,
}: {
  loading: boolean;
  skeleton: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  const { t } = useTranslation('common');
  const showSkeleton = useDelayedFlag(loading);
  const [wasLoading, setWasLoading] = useState(loading);
  if (loading && !wasLoading) setWasLoading(true);

  if (loading) {
    return (
      <div role="status" aria-busy="true" className={className}>
        <span className="sr-only">{t('loading')}</span>
        {showSkeleton && skeleton}
      </div>
    );
  }
  return (
    <div className={cn(wasLoading && 'content-fade-in', className)}>
      {children}
    </div>
  );
}

/**
 * For a section that's only mounted while loading: shows `children` after
 * the same 150ms grace period, announcing the busy state meanwhile.
 */
export function DelayedSkeleton({ children }: { children: ReactNode }) {
  const { t } = useTranslation('common');
  const show = useDelayedFlag(true);
  return (
    <div role="status" aria-busy="true">
      <span className="sr-only">{t('loading')}</span>
      {show && children}
    </div>
  );
}

/** generic list placeholder: index · title/subtitle · trailing value */
export function SkeletonRows({ count = 4 }: { count?: number }) {
  return (
    <DelayedSkeleton>
      {Array.from({ length: count }, (_, i) => (
        <div
          key={i}
          className="flex items-center gap-3 border-b border-border py-[14px]"
        >
          <Skeleton className="h-[10px] w-[14px] flex-none" />
          <div className="flex-1">
            <Skeleton className="h-[13px] w-[50%]" />
            <Skeleton className="mt-1.5 h-[10px] w-[30%]" />
          </div>
          <Skeleton className="h-[12px] w-[48px] flex-none" />
        </div>
      ))}
    </DelayedSkeleton>
  );
}

import type { CSSProperties, ReactNode } from 'react';

interface NutritionRingProps {
  value: number;
  max: number;
  size?: number;
  strokeWidth?: number;
  children?: ReactNode;
}

// pure SVG ring — track in --chip, fill in --acc (--neg once value passes
// max, same "over" rule as DietHistoryPage's bars); caller supplies the
// centered content (kcal readout) via children so this stays diet-agnostic.
// Fill motion lives in index.css (.ring-fill): sweeps in under a
// data-enter ancestor, transitions on later value changes
export default function NutritionRing({
  value,
  max,
  size = 176,
  strokeWidth = 14,
  children,
}: NutritionRingProps) {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const progress = max > 0 ? Math.min(1, value / max) : 0;
  const offset = circumference * (1 - progress);
  const over = max > 0 && value > max;
  const center = size / 2;

  return (
    <div className="relative" style={{ width: size, height: size }}>
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        className="-rotate-90"
      >
        <circle
          cx={center}
          cy={center}
          r={radius}
          fill="none"
          stroke="var(--chip)"
          strokeWidth={strokeWidth}
        />
        <circle
          cx={center}
          cy={center}
          r={radius}
          fill="none"
          className="ring-fill"
          stroke={over ? 'var(--neg)' : 'var(--acc)'}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          style={{ '--ring-empty': circumference } as CSSProperties}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        {children}
      </div>
    </div>
  );
}

interface MacroBarProps {
  label: string;
  value: number;
  max: number;
  color: string;
}

export default function MacroBar({ label, value, max, color }: MacroBarProps) {
  const pct = max > 0 ? Math.min(100, (value / max) * 100) : 0;

  return (
    <div>
      <div className="flex items-baseline justify-between">
        <span className="text-[13px] font-medium text-foreground">{label}</span>
        <span className="text-[12px] tabular-nums text-muted-foreground">
          {Math.round(value)}g / {Math.round(max)}g
        </span>
      </div>
      <div className="mt-1.5 h-[7px] w-full overflow-hidden rounded-full bg-chip">
        {/* full width, revealed by clip-path rather than animating width
            (layout) or scaleX (would squash the rounded end) */}
        <div
          className="macro-fill h-full"
          style={{
            clipPath: `inset(0 ${100 - pct}% 0 0 round 999px)`,
            backgroundColor: color,
          }}
        />
      </div>
    </div>
  );
}

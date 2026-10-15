import type { CSSProperties } from 'react';

// Decorative hero graphic for the login page: weekly volume bars (gym/diet)
// rise behind an elevation route (run) that draws itself like a GPS track,
// then a runner dot with a heartbeat ring travels the route on a loop.
// All motion lives in index.css under .hero-trace, gated by
// prefers-reduced-motion.

const ROUTE =
  'M8 96 C 80 88 130 60 200 64 C 270 68 310 36 380 42 C 450 48 510 80 570 54 C 620 32 675 26 712 30';

// relative heights (0–1) — a believable training week-over-week rhythm
const BARS = [
  0.34, 0.5, 0.42, 0.62, 0.3, 0.55, 0.72, 0.46, 0.38, 0.66, 0.52, 0.8, 0.44,
  0.58, 0.7, 0.4, 0.62, 0.86,
];
const BASELINE = 110;
const BAR_MAX = 64;
const BAR_W = 6;
const BAR_STEP = 700 / (BARS.length - 1);

export default function HeroTrace() {
  return (
    <svg
      viewBox="0 0 720 120"
      className="hero-trace mt-auto w-full"
      fill="none"
      aria-hidden="true"
    >
      <defs>
        <linearGradient id="hero-area" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="var(--acc)" stopOpacity=".22" />
          <stop offset="1" stopColor="var(--acc)" stopOpacity="0" />
        </linearGradient>
      </defs>

      {BARS.map((h, i) => (
        <rect
          key={i}
          className="hero-bar"
          style={{ '--i': i } as CSSProperties}
          x={10 + i * BAR_STEP - BAR_W / 2}
          y={BASELINE - h * BAR_MAX}
          width={BAR_W}
          height={h * BAR_MAX}
          rx={BAR_W / 2}
          fill="rgba(255,255,255,.07)"
        />
      ))}

      <line
        x1="0"
        y1={BASELINE}
        x2="720"
        y2={BASELINE}
        stroke="rgba(255,255,255,.14)"
        strokeWidth="1"
      />

      <path
        className="hero-area"
        d={`${ROUTE} L712 ${BASELINE} L8 ${BASELINE} Z`}
        fill="url(#hero-area)"
      />
      <path
        className="hero-route"
        d={ROUTE}
        pathLength={1}
        stroke="var(--acc)"
        strokeWidth="2.5"
        strokeLinecap="round"
        opacity=".7"
      />

      <circle
        className="hero-finish"
        cx="712"
        cy="30"
        r="3.5"
        fill="var(--acc)"
      />

      <g className="hero-runner" style={{ offsetPath: `path('${ROUTE}')` }}>
        <circle
          className="hero-pulse"
          r="5"
          stroke="var(--acc)"
          strokeWidth="1.5"
        />
        <circle r="5" fill="#EDF1F7" />
        <circle r="2.5" fill="var(--acc)" />
      </g>
    </svg>
  );
}

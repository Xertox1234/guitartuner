// ============================================================
// strobe-reduced.jsx — Reduce-Motion fallback gauge
// Not a downgrade: a luminous arc + needle + big tabular numerals.
// Error read by needle POSITION (+ sign + colour), no flashing motion.
// Needle eases smoothly; conveys information, not decoration.
// Exports: ReducedGauge
// ============================================================

const { useState, useEffect, useRef, useMemo, useCallback, useLayoutEffect } = React;

function polar(cx, cy, r, deg) {
  const a = (deg - 90) * Math.PI / 180;
  return [cx + r * Math.cos(a), cy + r * Math.sin(a)];
}
function arcPath(cx, cy, r, a0, a1) {
  const [x0, y0] = polar(cx, cy, r, a0);
  const [x1, y1] = polar(cx, cy, r, a1);
  const large = Math.abs(a1 - a0) > 180 ? 1 : 0;
  const sweep = a1 > a0 ? 1 : 0;
  return `M ${x0} ${y0} A ${r} ${r} 0 ${large} ${sweep} ${x1} ${y1}`;
}

// cents (-50..50) -> dial angle (deg, 0 = top/up)
const SPAN = 122; // degrees each side
const angOf = (c) => Math.max(-SPAN, Math.min(SPAN, (c / 50) * SPAN));

function ReducedGauge({ centsRef, cents = 0, locked: lockedProp, theme = "dark" }) {
  const [c, setC] = useState(centsRef ? centsRef.current : cents);
  // live: ease the local value toward the ref, throttled
  const last = useRef(0);
  useClock((t, dt) => {
    if (!centsRef) return;
    if (t - last.current > 0.045) { last.current = t; setC((v) => v + (centsRef.current - v) * 0.5); }
  }, [!!centsRef]);
  const val = centsRef ? c : cents;
  const a = angOf(val);
  const absV = Math.abs(val);
  const locked = lockedProp != null ? lockedProp : absV < LOCK_CENTS;
  const sign = val < -0.001 ? "flat" : val > 0.001 ? "sharp" : "tune";
  const glow = locked ? "var(--in-tune)" : sign === "flat" ? "var(--flat)" : sign === "sharp" ? "var(--sharp)" : "var(--ink)";

  const cx = 110, cy = 124, R = 86;
  const ticks = [];
  for (let cc = -50; cc <= 50; cc += 5) {
    const ta = angOf(cc);
    const major = cc % 25 === 0;
    const [x0, y0] = polar(cx, cy, R - (major ? 16 : 9), ta);
    const [x1, y1] = polar(cx, cy, R, ta);
    ticks.push(
      <line key={cc} x1={x0} y1={y0} x2={x1} y2={y1}
        stroke={cc === 0 ? "var(--in-tune)" : "var(--line-2)"}
        strokeWidth={cc === 0 ? 2.4 : major ? 1.6 : 1}
        strokeLinecap="round" opacity={cc === 0 ? 0.9 : major ? 0.8 : 0.5} />
    );
  }
  const [nx, ny] = polar(cx, cy, R - 4, a);

  return (
    <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
      <svg viewBox="0 0 220 220" style={{ width: "100%", height: "100%", overflow: "visible" }}>
        {/* track */}
        <path d={arcPath(cx, cy, R, -SPAN, SPAN)} fill="none" stroke="var(--line)" strokeWidth="3" strokeLinecap="round" />
        {/* coloured fill from 0 to needle */}
        <path d={arcPath(cx, cy, R, Math.min(0, a), Math.max(0, a))} fill="none"
          stroke={glow} strokeWidth="4.5" strokeLinecap="round"
          style={{ filter: `drop-shadow(0 0 6px ${glow})`, transition: "stroke 240ms" }} />
        {ticks}
        {/* needle */}
        <g style={{ transition: "transform 120ms linear" }}>
          <line x1={cx} y1={cy} x2={nx} y2={ny} stroke={glow} strokeWidth="2.6" strokeLinecap="round"
            style={{ filter: `drop-shadow(0 0 5px ${glow})` }} />
          <circle cx={nx} cy={ny} r={locked ? 6 : 4.2} fill={glow} style={{ filter: `drop-shadow(0 0 8px ${glow})` }} />
          <circle cx={cx} cy={cy} r="4" fill="var(--surface-3)" stroke="var(--line-2)" />
        </g>
        {/* lock ring */}
        {locked && (
          <circle cx={cx} cy={cy} r={R + 8} fill="none" stroke="var(--in-tune)" strokeWidth="1.5" opacity="0.35"
            style={{ filter: "drop-shadow(0 0 10px var(--in-tune))" }} />
        )}
      </svg>
    </div>
  );
}

window.ReducedGauge = ReducedGauge;
window._gaugeUtil = { polar, arcPath, angOf };

// ============================================================
// appicon.jsx — app-icon concepts from the strobe language
// Glowing tuned ring / locked column / frozen waveform on the dark canvas.
// Exports: AppIcon ({variant, size})
// ============================================================

function IconTile({ size = 180, children, radiusRatio = 0.225 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size * radiusRatio,
      position: "relative", overflow: "hidden",
      background: "radial-gradient(120% 100% at 50% 0%, #12141d, #07080c 70%)",
      boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.06), 0 18px 40px -16px rgba(0,0,0,0.7)",
    }}>
      {children}
    </div>
  );
}

// A) Radial phase ring — frozen, locked, blooming mint
function IconRing({ size = 180 }) {
  const c = size / 2, R = size * 0.30, marks = 24;
  const ticks = [];
  for (let i = 0; i < marks; i++) {
    const a = (i / marks) * Math.PI * 2 - Math.PI / 2;
    const r0 = R - size * 0.045, r1 = R + size * 0.045;
    ticks.push(<line key={i}
      x1={c + Math.cos(a) * r0} y1={c + Math.sin(a) * r0}
      x2={c + Math.cos(a) * r1} y2={c + Math.sin(a) * r1}
      stroke="#28F0C0" strokeWidth={size * 0.018} strokeLinecap="round" opacity="0.95" />);
  }
  return (
    <IconTile size={size}>
      <div style={{ position: "absolute", inset: 0, background: `radial-gradient(40% 40% at 50% 50%, rgba(40,240,192,0.28), transparent 70%)` }} />
      <svg width={size} height={size} style={{ position: "absolute", inset: 0, filter: `drop-shadow(0 0 ${size*0.03}px rgba(40,240,192,0.8))` }}>
        <circle cx={c} cy={c} r={R} fill="none" stroke="rgba(40,240,192,0.25)" strokeWidth={size * 0.06} />
        {ticks}
        <circle cx={c} cy={c} r={size * 0.05} fill="#28F0C0" style={{ filter: `drop-shadow(0 0 ${size*0.04}px #28F0C0)` }} />
      </svg>
    </IconTile>
  );
}

// B) Aurora column — bright mint centre flanked by cool/warm ribbons
function IconColumn({ size = 180 }) {
  const bars = [
    { x: 0.28, c: "rgba(77,139,255,0.55)", w: 0.05 },
    { x: 0.39, c: "rgba(138,107,255,0.5)", w: 0.045 },
    { x: 0.5, c: "#28F0C0", w: 0.11 },
    { x: 0.61, c: "rgba(255,165,60,0.5)", w: 0.045 },
    { x: 0.72, c: "rgba(255,106,77,0.55)", w: 0.05 },
  ];
  return (
    <IconTile size={size}>
      <div style={{ position: "absolute", inset: 0, background: `radial-gradient(35% 60% at 50% 50%, rgba(40,240,192,0.22), transparent 70%)` }} />
      {bars.map((b, i) => (
        <div key={i} style={{
          position: "absolute", top: size * 0.16, bottom: size * 0.16,
          left: b.x * size, width: b.w * size, transform: "translateX(-50%)",
          borderRadius: size, background: `linear-gradient(transparent, ${b.c} 22%, ${b.c} 78%, transparent)`,
          filter: `blur(${size*0.006}px) drop-shadow(0 0 ${size*(i===2?0.05:0.02)}px ${b.c})`,
          opacity: i === 2 ? 1 : 0.85,
        }} />
      ))}
    </IconTile>
  );
}

// C) Locked waveform — a single frozen, perfectly-tuned sine
function IconWave({ size = 180 }) {
  const mid = size / 2, amp = size * 0.16, k = (Math.PI * 2) / (size * 0.42);
  let d = `M ${size*0.14} ${mid}`;
  for (let x = size * 0.14; x <= size * 0.86; x += 2) {
    d += ` L ${x} ${mid + Math.sin((x - size*0.14) * k) * amp}`;
  }
  return (
    <IconTile size={size}>
      <div style={{ position: "absolute", inset: 0, background: `radial-gradient(60% 36% at 50% 50%, rgba(40,240,192,0.2), transparent 70%)` }} />
      <svg width={size} height={size} style={{ position: "absolute", inset: 0 }}>
        <line x1={size*0.14} y1={mid} x2={size*0.86} y2={mid} stroke="rgba(255,255,255,0.08)" strokeWidth="1" />
        <path d={d} fill="none" stroke="#28F0C0" strokeWidth={size * 0.035} strokeLinecap="round" strokeLinejoin="round"
          style={{ filter: `drop-shadow(0 0 ${size*0.03}px rgba(40,240,192,0.9))` }} />
      </svg>
    </IconTile>
  );
}

function AppIcon({ variant = "ring", size = 180 }) {
  if (variant === "column") return <IconColumn size={size} />;
  if (variant === "wave") return <IconWave size={size} />;
  return <IconRing size={size} />;
}

Object.assign(window, { AppIcon, IconRing, IconColumn, IconWave, IconTile });

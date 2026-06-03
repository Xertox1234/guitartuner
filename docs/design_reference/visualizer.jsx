// visualizer.jsx — hero radial pitch dial
const { useEffect, useRef, useState, useMemo } = React;

// Spring-physics smoothing
function useSpring(target, { stiffness = 180, damping = 22 } = {}) {
  const [value, setValue] = useState(target);
  const stateRef = useRef({ v: target, vel: 0, last: performance.now() });
  const rafRef = useRef(0);
  useEffect(() => {
    let alive = true;
    const tick = (t) => {
      if (!alive) return;
      const s = stateRef.current;
      const dt = Math.min(0.05, (t - s.last) / 1000);
      s.last = t;
      const force = -stiffness * (s.v - target);
      const damp = -damping * s.vel;
      s.vel += (force + damp) * dt;
      s.v += s.vel * dt;
      if (Math.abs(s.v - target) < 0.001 && Math.abs(s.vel) < 0.001) {
        s.v = target; s.vel = 0;
        setValue(target);
        return;
      }
      setValue(s.v);
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
    return () => { alive = false; cancelAnimationFrame(rafRef.current); };
  }, [target, stiffness, damping]);
  return value;
}

function arcPath(cx, cy, r, a1Deg, a2Deg) {
  const toRad = (d) => (d - 90) * Math.PI / 180;
  const x1 = cx + r * Math.cos(toRad(a1Deg));
  const y1 = cy + r * Math.sin(toRad(a1Deg));
  const x2 = cx + r * Math.cos(toRad(a2Deg));
  const y2 = cy + r * Math.sin(toRad(a2Deg));
  const large = Math.abs(a2Deg - a1Deg) > 180 ? 1 : 0;
  const sweep = a2Deg > a1Deg ? 1 : 0;
  return `M ${x1} ${y1} A ${r} ${r} 0 ${large} ${sweep} ${x2} ${y2}`;
}

function Visualizer({ note, octave, freq, cents, locked, active }) {
  const targetAngle = Math.max(-50, Math.min(50, cents)) * 1.8; // -90..+90
  const angle = useSpring(targetAngle, { stiffness: 140, damping: 17 });
  const animFreq = useSpring(freq, { stiffness: 70, damping: 16 });

  // Particle bloom on lock transition
  const [particles, setParticles] = useState([]);
  const wasLockedRef = useRef(false);
  const [pulseKey, setPulseKey] = useState(0);
  useEffect(() => {
    if (locked && !wasLockedRef.current) {
      const newParts = Array.from({ length: 16 }, () => ({
        id: Math.random().toString(36),
        dx: (Math.random() - 0.5) * 100,
        delay: Math.random() * 250,
        size: 2 + Math.random() * 3,
      }));
      setParticles((p) => [...p, ...newParts]);
      setPulseKey((k) => k + 1);
      setTimeout(() => {
        setParticles((p) => p.filter((x) => !newParts.find((n) => n.id === x.id)));
      }, 2000);
    }
    wasLockedRef.current = locked;
  }, [locked]);

  // SVG viewBox 1000x1000
  const cx = 500, cy = 500;
  const rOuter = 470;
  const rTickOuter = 452;
  const rTickInnerMajor = 408;
  const rTickInnerMinor = 428;
  const rLabel = 376;
  const rArc = 360;
  const rRingInner = 332;
  const rNeedleTip = 400;
  const rNeedleTail = 282;

  // Ticks every 2 cents
  const ticks = useMemo(() => {
    const arr = [];
    for (let c = -50; c <= 50; c += 2) {
      const a = c * 1.8;
      const isMajor = c % 10 === 0;
      const isZero = c === 0;
      const rIn = isMajor ? rTickInnerMajor : rTickInnerMinor;
      arr.push({ c, a, isMajor, isZero, rIn });
    }
    return arr;
  }, []);

  const labels = [-50, -25, 0, 25, 50];

  // Arc fill 0 → current
  const arcEnd = Math.max(-90, Math.min(90, angle));
  const arcFillPath = useMemo(() => {
    if (Math.abs(arcEnd) < 0.5) return "";
    return arcPath(cx, cy, rArc, 0, arcEnd);
  }, [arcEnd]);

  const absCents = Math.abs(cents);
  const hotState = absCents > 15;
  const lockState = locked;

  // Needle endpoints — rim pointer only
  const needleRad = (angle - 90) * Math.PI / 180;
  const nx1 = cx + Math.cos(needleRad) * rNeedleTail;
  const ny1 = cy + Math.sin(needleRad) * rNeedleTail;
  const nx2 = cx + Math.cos(needleRad) * rNeedleTip;
  const ny2 = cy + Math.sin(needleRad) * rNeedleTip;

  // Formatting
  const freqStr = animFreq.toFixed(2).padStart(7, "0");
  const sign = cents >= 0 ? "+" : "−";
  const centsStr = `${sign}${Math.abs(cents).toFixed(1).padStart(4, "0")}`;
  const noteLetter = (note || "—").replace("#", "").replace("b", "");
  const accidental = (note || "").includes("#") ? "♯" : (note || "").includes("b") ? "♭" : "";

  return (
    <div className="viz">
      <svg className="dial" viewBox="0 0 1000 1000" aria-hidden="true">
        {/* Outer ring */}
        <circle cx={cx} cy={cy} r={rOuter} className="ring-outer" />
        <circle cx={cx} cy={cy} r={rRingInner} className="ring-inner" />

        {/* Ticks */}
        {ticks.map((t) => {
          const aRad = (t.a - 90) * Math.PI / 180;
          const x1 = cx + Math.cos(aRad) * rTickOuter;
          const y1 = cy + Math.sin(aRad) * rTickOuter;
          const x2 = cx + Math.cos(aRad) * t.rIn;
          const y2 = cy + Math.sin(aRad) * t.rIn;
          let cls = "tick";
          if (t.isMajor) cls += " major";
          if (t.isZero) cls += " zero";
          const passed = (angle >= 0 && t.a > 0 && t.a <= angle) || (angle < 0 && t.a < 0 && t.a >= angle);
          if (passed && active && !lockState) cls += " hot";
          if (passed && active && lockState) cls += " cool";
          return <line key={t.c} className={cls} x1={x1} y1={y1} x2={x2} y2={y2} />;
        })}

        {/* Cents labels */}
        {labels.map((c) => {
          const a = c * 1.8;
          const aRad = (a - 90) * Math.PI / 180;
          const x = cx + Math.cos(aRad) * rLabel;
          const y = cy + Math.sin(aRad) * rLabel;
          return (
            <text key={c} className="cents-label" x={x} y={y}
                  textAnchor="middle" dominantBaseline="middle">
              {c > 0 ? `+${c}` : c}
            </text>
          );
        })}

        {/* Arc track */}
        <path d={arcPath(cx, cy, rArc, -90, 90)} className="arc-track" />

        {/* Arc fill */}
        {active && arcFillPath && (
          <path d={arcFillPath} className={"arc-fill " + (lockState ? "locked" : "")} />
        )}

        {/* Needle */}
        {active && (
          <>
            <line className={"needle-shadow " + (lockState ? "locked" : "")} x1={nx1} y1={ny1} x2={nx2} y2={ny2} />
            <line className={"needle " + (lockState ? "locked" : "")} x1={nx1} y1={ny1} x2={nx2} y2={ny2} />
          </>
        )}
      </svg>

      {/* Lock pulse ring */}
      <div key={pulseKey} className={"lock-ring " + (locked ? "active" : "")} />

      {/* Particles */}
      <div className="particles">
        {particles.map((p) => (
          <span
            key={p.id}
            className="particle"
            style={{
              "--dx": p.dx + "px",
              width: p.size + "px",
              height: p.size + "px",
              animationDelay: p.delay + "ms",
            }}
          />
        ))}
      </div>

      {/* Big note letter — watermark behind UI */}
      <div className="viz-note-bg">
        <span className={"viz-note " + (lockState ? "locked" : "")}>{noteLetter}</span>
        {accidental && <span className="viz-accidental">{accidental}</span>}
        <span className="viz-octave">{octave}</span>
      </div>

      {/* Centered foreground stack */}
      <div className="viz-center">
        <div className={"viz-cents " + (lockState ? "locked" : hotState && active ? "hot" : "")}>
          <span className="num">{active ? centsStr : "−−.−"}</span>
          <span className="unit">cents</span>
        </div>
        <div className="viz-center-spacer" aria-hidden="true"></div>
        <div className="viz-freq">
          <span className="v">{active ? freqStr : "000.00"}</span>
          <span className="unit">Hz</span>
        </div>
        <div className={"viz-status " + (lockState ? "locked" : hotState && active ? "hot" : "")}>
          <span className={"arrow left " + ((cents > -1.5 || !active) ? "hidden" : "")}></span>
          <span>
            {!active ? "select a string" : lockState ? "in tune" : cents < -1.5 ? "tune up" : cents > 1.5 ? "tune down" : "almost"}
          </span>
          <span className={"arrow right " + ((cents < 1.5 || !active) ? "hidden" : "")}></span>
        </div>
      </div>
    </div>
  );
}

window.Visualizer = Visualizer;

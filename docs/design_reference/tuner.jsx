// tuner.jsx — Tuner mobile app
const { useState, useEffect, useRef, useMemo, useCallback } = React;

// ── Tunings ────────────────────────────────────────────────
const TUNINGS = {
  guitar: {
    label: "Guitar",
    strings: [
      // 6=lowest pitched (E2), 1=highest (E4). Render left-to-right as 6→1.
      { idx: 6, note: "E", octave: 2, freq: 82.4069 },
      { idx: 5, note: "A", octave: 2, freq: 110.000 },
      { idx: 4, note: "D", octave: 3, freq: 146.832 },
      { idx: 3, note: "G", octave: 3, freq: 195.998 },
      { idx: 2, note: "B", octave: 3, freq: 246.942 },
      { idx: 1, note: "E", octave: 4, freq: 329.628 },
    ],
  },
  bass: {
    label: "Bass",
    strings: [
      { idx: 4, note: "E", octave: 1, freq: 41.2034 },
      { idx: 3, note: "A", octave: 1, freq: 55.0000 },
      { idx: 2, note: "D", octave: 2, freq: 73.4162 },
      { idx: 1, note: "G", octave: 2, freq: 97.9989 },
    ],
  },
};

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "dark",
  "instrument": "guitar",
  "pickup": "electric"
}/*EDITMODE-END*/;

// ── Segmented control (CSS-positioned, no JS measurement) ───
function Segmented({ value, onChange, options }) {
  const activeIdx = Math.max(0, options.findIndex((o) => o.key === value));
  return (
    <div
      className="seg"
      style={{ "--count": options.length, "--idx": activeIdx }}
    >
      <div className="pill" />
      {options.map((o) => (
        <button
          key={o.key}
          className={value === o.key ? "active" : ""}
          onClick={() => onChange(o.key)}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

// ── Icons ──────────────────────────────────────────────────
const IconSun = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
    <circle cx="12" cy="12" r="4" />
    <path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.5 4.5l2 2M17.5 17.5l2 2M4.5 19.5l2-2M17.5 6.5l2-2"/>
  </svg>
);
const IconMoon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
    <path d="M20 14.5A8 8 0 1 1 9.5 4 6.5 6.5 0 0 0 20 14.5Z" />
  </svg>
);
const IconCog = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
    <path d="M4 6h7M16 6h4M4 12h3M12 12h8M4 18h11M20 18h0"/>
    <circle cx="13" cy="6" r="2" fill="var(--paper)"/>
    <circle cx="9" cy="12" r="2" fill="var(--paper)"/>
    <circle cx="17" cy="18" r="2" fill="var(--paper)"/>
  </svg>
);

// ── App ────────────────────────────────────────────────────
function App() {
  const [theme, setTheme] = useState(TWEAK_DEFAULTS.theme);
  const [instrument, setInstrument] = useState(TWEAK_DEFAULTS.instrument);
  const [pickup, setPickup] = useState(TWEAK_DEFAULTS.pickup);
  const [activeStringIdx, setActiveStringIdx] = useState(5); // pre-select A2
  const [cents, setCents] = useState(-22); // engaged initial state
  const [autoMode, setAutoMode] = useState(false);
  const [drifting, setDrifting] = useState(true); // pitch wobble simulation while string is active

  // Apply theme to screen + host body for outer page bg
  useEffect(() => {
    document.documentElement.setAttribute("data-host-theme", theme);
  }, [theme]);

  const tuning = TUNINGS[instrument];
  const activeString = useMemo(() => {
    if (activeStringIdx == null) return tuning.strings[0];
    return tuning.strings.find((s) => s.idx === activeStringIdx) || tuning.strings[0];
  }, [activeStringIdx, instrument]);

  const stringIsSelected = activeStringIdx != null;

  // Reset selection on instrument change (skip first mount)
  const didMountRef = useRef(false);
  useEffect(() => {
    if (!didMountRef.current) { didMountRef.current = true; return; }
    const firstIdx = TUNINGS[instrument].strings[Math.floor(TUNINGS[instrument].strings.length / 2)].idx;
    setActiveStringIdx(firstIdx);
    setCents((Math.random() - 0.5) * 50);
    setAutoMode(false);
  }, [instrument]);

  // Animation loop: drift / auto-tune. Throttled to ~12fps so the rest of the tree doesn't re-render every paint.
  useEffect(() => {
    if (!stringIsSelected) return;
    let alive = true;
    let last = performance.now();
    let acc = 0;
    const STEP = 1 / 12; // seconds per update
    const tick = (t) => {
      if (!alive) return;
      const dt = Math.min(0.2, (t - last) / 1000);
      last = t;
      acc += dt;
      if (acc >= STEP) {
        const stepDt = acc;
        acc = 0;
        setCents((c) => {
          let next = c;
          if (autoMode) {
            const dir = Math.sign(0 - next);
            const speed = 18 + Math.abs(next) * 0.4;
            next += dir * Math.min(Math.abs(next), speed * stepDt);
            const wob = Math.abs(next) > 4 ? 1.4 : 0.5;
            next += (Math.random() - 0.5) * wob * stepDt * 60;
          } else if (drifting) {
            next = c * 0.985 + (Math.random() - 0.5) * 0.6;
          }
          return Math.max(-50, Math.min(50, next));
        });
      }
      requestAnimationFrame(tick);
    };
    const id = requestAnimationFrame(tick);
    return () => { alive = false; cancelAnimationFrame(id); };
  }, [stringIsSelected, autoMode, drifting]);

  // String tap: select + bump to a random offset; preserves intent of "you just plucked an out-of-tune string"
  const chooseString = (idx) => {
    setActiveStringIdx(idx);
    setCents((Math.random() - 0.5) * 50);
    setAutoMode(false);
  };

  const locked = stringIsSelected && Math.abs(cents) < 2;

  const displayedFreq = stringIsSelected
    ? activeString.freq * Math.pow(2, cents / 1200)
    : activeString.freq;

  // Theme toggle on screen
  const isDark = theme === "dark";

  return (
    <IOSDevice width={402} height={874} dark={isDark}>
      <div className="screen" data-theme={theme}>
        <div className="screen-body">
          {/* ── Top bar ────────────────────────── */}
          <header className="topbar">
            <div className="brand">
              <div className="brand-glyph" />
              <div className="brand-lockup">
                <div className="brand-mark">TUNER</div>
                <div className="brand-meta">{tuning.label} · {pickup} · A=440</div>
              </div>
            </div>
            <div className="top-actions">
              <button
                className="icon-btn"
                aria-label="Toggle theme"
                onClick={() => setTheme(isDark ? "light" : "dark")}
              >
                {isDark ? <IconSun /> : <IconMoon />}
              </button>
              <button className="icon-btn" aria-label="Settings">
                <IconCog />
              </button>
            </div>
          </header>

          {/* ── Visualizer ─────────────────────── */}
          <div className="viz-wrap">
            <Visualizer
              note={activeString.note}
              octave={activeString.octave}
              freq={displayedFreq}
              cents={stringIsSelected ? cents : 0}
              locked={locked}
              active={stringIsSelected}
            />
          </div>

          {/* ── Oscilloscope ───────────────────── */}
          <div className="scope">
            <Oscilloscope
              freq={displayedFreq}
              cents={stringIsSelected ? cents : 0}
              locked={locked}
              active={stringIsSelected}
            />
            <div className="scope-labels">
              <span>
                {stringIsSelected ? <><b>{Math.round(displayedFreq)}</b> Hz</> : "no signal"}
              </span>
              <span>
                <span>YIN-AC</span>
                <span className="sep">·</span>
                <span>48k</span>
                <span className="sep">·</span>
                <span style={{ color: locked ? "var(--cool)" : "inherit" }}>
                  {locked ? "LOCKED" : stringIsSelected ? "TRACKING" : "STANDBY"}
                </span>
              </span>
            </div>
          </div>

          {/* ── Controls ───────────────────────── */}
          <div className="controls">
            <div className="seg-row">
              <Segmented
                value={instrument}
                onChange={setInstrument}
                options={[
                  { key: "guitar", label: "Guitar" },
                  { key: "bass", label: "Bass" },
                ]}
              />
              <Segmented
                value={pickup}
                onChange={setPickup}
                options={[
                  { key: "electric", label: "Electric" },
                  { key: "acoustic", label: "Acoustic" },
                ]}
              />
            </div>

            <div className="string-bank" data-count={tuning.strings.length}>
              {tuning.strings.map((s) => {
                const isActive = activeStringIdx === s.idx;
                return (
                  <button
                    key={s.idx + s.note + s.octave}
                    className={
                      "string-btn " +
                      (isActive ? "active " : "") +
                      (isActive && locked ? "locked-now" : "")
                    }
                    onClick={() => chooseString(s.idx)}
                    aria-label={`String ${s.idx}, ${s.note}${s.octave}`}
                  >
                    <span className="idx">0{s.idx}</span>
                    <span className="n">{s.note}</span>
                    <span className="o">{s.octave}</span>
                  </button>
                );
              })}
            </div>

            <div className="tune-row">
              <div className="hint">
                {locked
                  ? "string is in tune · pluck next"
                  : autoMode
                  ? "auto-tuning…"
                  : stringIsSelected
                  ? "tap auto to tune for you"
                  : "tap a string to begin"}
              </div>
              <button
                className={"auto-btn " + (autoMode ? "running" : "")}
                onClick={() => stringIsSelected && setAutoMode((v) => !v)}
                disabled={!stringIsSelected}
              >
                {autoMode ? "Stop" : "Auto Tune"}
              </button>
            </div>
          </div>

          {/* ── Bottom strip ───────────────────── */}
          <div className={"bottom-strip " + (stringIsSelected ? "live" : "")}>
            <span><span className="dot"></span>{stringIsSelected ? "Listening" : "Idle"}</span>
            <span>Tuner · v0.4 · 18.05.26</span>
          </div>
        </div>
      </div>
    </IOSDevice>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);

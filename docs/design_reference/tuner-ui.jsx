// ============================================================
// tuner-ui.jsx — component library + composed TunerScreen
// Atoms: NoteReadout, CentsReadout, StateLine, TargetChip, StringRow,
//        A4Control, InputSource, ToneToggle, SettingsBtn, Brand
// TunerScreen composes them over a strobe field. Works LIVE (useTunerSim)
// or in a forced STATE (idle/flat/locked/string-lock/tone), dark or light.
// Exports: TunerScreen + all atoms
// ============================================================

const { useState, useEffect, useRef, useMemo, useCallback, useLayoutEffect } = React;

/* ---------- icons ---------- */
const Gear = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
    <circle cx="12" cy="12" r="3.2" />
    <path d="M12 2.5v2.2M12 19.3v2.2M21.5 12h-2.2M4.7 12H2.5M18.7 5.3l-1.6 1.6M6.9 17.1l-1.6 1.6M18.7 18.7l-1.6-1.6M6.9 6.9 5.3 5.3" strokeLinecap="round"/>
  </svg>
);
const Mic = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
    <rect x="9" y="3" width="6" height="11" rx="3"/><path d="M6 11a6 6 0 0 0 12 0M12 17v4"/>
  </svg>
);
const Jack = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
    <path d="M14 3v7M10 3v7M8 10h8v3a4 4 0 0 1-8 0z M12 17v4"/>
  </svg>
);
const Wave = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" className="wave">
    <path d="M2 12h2.5l2-6 3 13 3-16 3 13 2-4H22"/>
  </svg>
);

/* ---------- atoms ---------- */
function Brand({ label = "LUMA" }) {
  return (
    <div className="brand-min">
      <div className="brand-dot" />
      <div className="brand-word">{label}</div>
    </div>
  );
}

function NoteReadout({ note, octave, locked, dim }) {
  const { letter, accidental } = Music.parts(note);
  return (
    <div className={"note" + (locked ? " lock" : "")} style={dim ? { opacity: 0.32 } : null}>
      <span className="ltr">{letter}</span>
      {accidental && <span className="acc">{accidental}</span>}
      <span className="oct">{octave}</span>
    </div>
  );
}

function CentsReadout({ cents, state }) {
  const v = Math.round(cents);
  const sign = v > 0 ? "+" : v < 0 ? "\u2212" : "\u00B1";
  const mag = Math.abs(v);
  const arrow = state === "flat" ? "up" : state === "sharp" ? "down" : "off";
  return (
    <div className="cents" data-state={state}>
      <span className={"arrow " + arrow} />
      <span className="val">{sign}{mag}</span>
      <span className="unit">{"\u00A2"}</span>
    </div>
  );
}

function StateLine({ state }) {
  const map = {
    idle: ["STANDBY", "pluck a string"],
    flat: ["FLAT", "tune up"],
    sharp: ["SHARP", "tune down"],
    tune: ["IN TUNE", "hold it"],
  };
  const [tag, sub] = map[state] || map.idle;
  return (
    <div className="state-line" data-state={state}>
      <span className="tag">{tag}</span>
      <span className="sub">{sub}</span>
    </div>
  );
}

function FreqLine({ freq, algo = "YIN", rate = "48k" }) {
  return (
    <div className="freq-line">
      <b>{freq.toFixed(1)}</b> Hz · {algo} · {rate}
    </div>
  );
}

function TargetChip({ mode, onChange }) {
  const opts = [{ k: "auto", l: "Auto" }, { k: "lock", l: "String" }];
  const idx = opts.findIndex((o) => o.k === mode);
  return (
    <div className="target">
      <div className="glider" style={{ width: "calc(50% - 3px)", transform: `translateX(${idx * 100}%)` }} />
      {opts.map((o) => (
        <button key={o.k} data-on={mode === o.k} onClick={() => onChange && onChange(o.k)}>{o.l}</button>
      ))}
    </div>
  );
}

function StringRow({ tuning, activeIdx, lockedIdx, onPick }) {
  return (
    <div className="stringrow">
      {tuning.strings.map((s) => (
        <button key={s.idx} className="string"
          data-on={activeIdx === s.idx}
          data-lock={lockedIdx === s.idx}
          onClick={() => onPick && onPick(s.idx)}
          aria-label={`String ${s.idx}, ${s.note}${s.octave}`}>
          <span className="sx">{String(s.idx).padStart(2, "0")}</span>
          <span className="sn">{s.note}</span>
          <span className="so">{s.octave}</span>
        </button>
      ))}
    </div>
  );
}

function A4Control({ a4, onChange }) {
  return (
    <div className="a4">
      <span className="lbl">A4</span>
      <button className="step" onClick={() => onChange && onChange(Math.max(430, a4 - 1))} aria-label="A4 down">{"\u2212"}</button>
      <span className="val">{a4.toFixed(0)} Hz</span>
      <button className="step" onClick={() => onChange && onChange(Math.min(450, a4 + 1))} aria-label="A4 up">+</button>
    </div>
  );
}

function InputSource({ source = "di", onToggle }) {
  return (
    <button className="edge-btn" onClick={onToggle} aria-label="Input source">
      <span className="src-dot" />
      {source === "di" ? <Jack /> : <Mic />}
      <span>{source === "di" ? "DI" : "MIC"}</span>
    </button>
  );
}

function ToneToggle({ on, onToggle, label = "Tone" }) {
  return (
    <button className="tone" data-on={on} onClick={onToggle} aria-label="Tone generator">
      <Wave /><span>{label}</span>
    </button>
  );
}

function SettingsBtn() {
  return <div className="edge-icon" aria-label="Settings"><Gear /></div>;
}

/* ---------- tiny Web-Audio tone ---------- */
function useTone() {
  const ctxRef = useRef(null), oscRef = useRef(null), gainRef = useRef(null);
  const start = useCallback((freq) => {
    try {
      let ctx = ctxRef.current;
      if (!ctx) { ctx = new (window.AudioContext || window.webkitAudioContext)(); ctxRef.current = ctx; }
      if (ctx.state === "suspended") ctx.resume();
      stop();
      const osc = ctx.createOscillator(), gain = ctx.createGain();
      osc.type = "sine"; osc.frequency.value = freq;
      gain.gain.value = 0; osc.connect(gain); gain.connect(ctx.destination);
      osc.start(); gain.gain.linearRampToValueAtTime(0.12, ctx.currentTime + 0.05);
      oscRef.current = osc; gainRef.current = gain;
    } catch (e) {}
  }, []);
  const stop = useCallback(() => {
    const ctx = ctxRef.current, osc = oscRef.current, gain = gainRef.current;
    if (ctx && gain && osc) {
      try { gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.05); osc.stop(ctx.currentTime + 0.08); } catch (e) {}
    }
    oscRef.current = null; gainRef.current = null;
  }, []);
  useEffect(() => () => stop(), []);
  return { start, stop };
}

/* ---------- Strobe field selector ---------- */
function StrobeField({ variant, reduceMotion, ...rest }) {
  if (reduceMotion) return <ReducedGauge {...rest} />;
  if (variant === "radial") return <RadialStrobe {...rest} />;
  return <AuroraStrobe {...rest} />;
}

/* ============================================================
   TunerScreen
   props:
     live        — wire useTunerSim (interactive)
     variant     — "aurora" | "radial"
     reduceMotion, theme, padTop, instrument, a4
     preset      — forced state when not live:
        { note, octave, cents|null, mode, activeIdx, tone, idle }
   ============================================================ */
function TunerScreen({
  live = false, variant = "aurora", reduceMotion = false, theme = "dark",
  padTop = 16, instrument = "guitar", a4: a4Prop = 440, preset = null,
  onVariant,
}) {
  const tone = useTone();

  // ---------- LIVE ----------
  const sim = live ? useTunerSim({ instrument, a4: a4Prop }) : null;
  const [a4, setA4] = useState(a4Prop);
  const [source, setSource] = useState("di");
  const [toneOn, setToneOn] = useState(false);
  const [mode, setMode] = useState(live ? "auto" : (preset && preset.mode) || "auto");

  // static cents ref so the strobe can read a fixed value
  const staticRef = useRef(preset ? (preset.cents ?? 0) : 0);
  staticRef.current = preset ? (preset.cents ?? 0) : 0;

  let note, octave, cents, locked, hasSignal, tuning, activeIdx, lockedIdx, centsRef, displayedFreq, idle, toneActive;

  if (live) {
    tuning = sim.tuning;
    note = sim.activeString.note; octave = sim.activeString.octave;
    cents = sim.displayCents; locked = sim.locked; hasSignal = true;
    activeIdx = sim.stringIdx; lockedIdx = locked ? sim.stringIdx : null;
    centsRef = sim.centsRef; displayedFreq = sim.displayedFreq;
    idle = false; toneActive = toneOn;
  } else {
    tuning = TUNINGS[instrument];
    note = preset.note; octave = preset.octave;
    hasSignal = preset.cents != null && !preset.idle;
    cents = preset.cents ?? 0;
    locked = hasSignal && Math.abs(cents) < LOCK_CENTS;
    activeIdx = preset.activeIdx ?? null; lockedIdx = locked && preset.mode === "lock" ? activeIdx : null;
    centsRef = staticRef; idle = !!preset.idle; toneActive = !!preset.tone;
    const baseFreq = activeIdx ? Music.freq((tuning.strings.find(s => s.idx === activeIdx) || tuning.strings[0]).midi, a4) : Music.freq(57, a4);
    displayedFreq = baseFreq * Math.pow(2, cents / 1200);
  }

  // tone generator playing with no live input = a steady "sounding reference"
  const toneStandalone = toneActive && !hasSignal;
  // visual state token
  const vstate = toneStandalone ? "tune" : !hasSignal ? "idle" : locked ? "tune" : cents < 0 ? "flat" : "sharp";
  // glow hue var on the screen root
  const glowVar = vstateGlow(vstate);
  // what the strobe field renders
  const fieldCents = toneStandalone ? 0 : cents;
  const fieldLocked = toneStandalone ? true : locked;
  if (!live) staticRef.current = fieldCents;

  // live tone wiring
  useEffect(() => {
    if (!live) return;
    if (toneOn) tone.start(Music.freq(sim.activeString.midi, a4));
    else tone.stop();
  }, [toneOn, live, sim && sim.activeString.midi, a4]);

  const handlePick = (idx) => {
    if (live) { sim.pluck(idx); if (mode !== "lock") setMode("lock"); }
  };

  // animate only the live hero + breathing idle; state-snapshots render as
  // crisp frozen frames (keeps many side-by-side canvases performant)
  const animated = !reduceMotion && (live || idle);

  return (
    <div className="scr" data-theme={theme} style={{ "--glow": glowVar }}>
      <div className="scr-inner" style={{ paddingTop: padTop }}>
        {/* top edge chrome */}
        <div className="scr-top">
          <Brand />
          <div className="scr-top-actions">
            <InputSource source={source} onToggle={() => live && setSource(s => s === "di" ? "mic" : "di")} />
            <SettingsBtn />
          </div>
        </div>

        {/* hero field */}
        <div className="field">
          <div className="field-frame">
            <StrobeField variant={variant} reduceMotion={reduceMotion}
              centsRef={centsRef} cents={centsRef.current} animated={animated}
              idle={idle} theme={theme} locked={fieldLocked} />
          </div>
          <div className="note-stack">
            <NoteReadout note={note} octave={octave} locked={fieldLocked} dim={idle && !toneStandalone} />
            {toneStandalone ? (
              <React.Fragment>
                <div className="state-line" data-state="tune" style={{ marginTop: "var(--s-6)" }}>
                  <span className="tag">SOUNDING</span><span className="sub">reference tone</span>
                </div>
                <FreqLine freq={displayedFreq} algo="TONE" rate="sine" />
              </React.Fragment>
            ) : hasSignal ? (
              <React.Fragment>
                <CentsReadout cents={cents} state={vstate} />
                <StateLine state={vstate} />
                <FreqLine freq={displayedFreq} />
              </React.Fragment>
            ) : (
              <StateLine state="idle" />
            )}
          </div>
        </div>

        {/* controls dock */}
        <div className="dock">
          <TargetChip mode={mode} onChange={(m) => { setMode(m); }} />
          <StringRow tuning={tuning} activeIdx={activeIdx} lockedIdx={lockedIdx} onPick={handlePick} />
          <div className="util">
            <div className="util-left">
              <A4Control a4={a4} onChange={(v) => live && setA4(v)} />
            </div>
            <ToneToggle on={toneActive} onToggle={() => live && setToneOn(v => !v)} />
          </div>
        </div>
      </div>
    </div>
  );
}

function vstateGlow(v) {
  return v === "tune" ? "var(--in-tune)" : v === "flat" ? "var(--flat)" : v === "sharp" ? "var(--sharp)" : "var(--faint)";
}

Object.assign(window, {
  TunerScreen, NoteReadout, CentsReadout, StateLine, FreqLine, TargetChip,
  StringRow, A4Control, InputSource, ToneToggle, SettingsBtn, Brand, StrobeField, vstateGlow,
});

// ============================================================
// canvas-app.jsx — assembles the whole system onto a pan/zoom canvas
// ============================================================

// ---- Strobe concept demo card (field + note overlay + caption) ----
function StrobeDemo({ variant, cents = 0, idle = false, reduceMotion = false, note = "A", octave = 2, caption, sub, w = 360, h = 460 }) {
  const locked = Math.abs(cents) < LOCK_CENTS && !idle;
  const vstate = idle ? "idle" : locked ? "tune" : cents < 0 ? "flat" : "sharp";
  const { letter, accidental } = Music.parts(note);
  return (
    <div data-theme="dark" style={{
      width: w, height: h, position: "relative", overflow: "hidden",
      borderRadius: 22, background: "radial-gradient(120% 90% at 50% 0%, var(--bg-grad), var(--bg) 62%)",
      boxShadow: "inset 0 0 0 1px var(--line)", fontFamily: "var(--font-ui)", color: "var(--ink)",
      "--glow": vstateGlow(vstate),
    }}>
      <div style={{ position: "absolute", inset: 0, top: 0, bottom: 72 }}>
        <StrobeField variant={variant} reduceMotion={reduceMotion} cents={cents} animated={!reduceMotion} idle={idle} theme="dark" locked={locked} />
        <div style={{ position: "absolute", inset: "0 0 0 0", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", pointerEvents: "none" }}>
          <div className={"note" + (locked ? " lock" : "")} style={{ opacity: idle ? 0.35 : 1 }}>
            <span className="ltr" style={{ fontSize: 120 }}>{letter}</span>
            {accidental && <span className="acc" style={{ fontSize: 40 }}>{accidental}</span>}
            <span className="oct">{octave}</span>
          </div>
          {!idle && (
            <div className="cents" data-state={vstate} style={{ marginTop: 12 }}>
              <span className={"arrow " + (vstate === "flat" ? "up" : vstate === "sharp" ? "down" : "off")} />
              <span className="val" style={{ fontSize: 24 }}>{cents > 0 ? "+" : cents < 0 ? "−" : "±"}{Math.abs(Math.round(cents))}</span>
              <span className="unit">{"¢"}</span>
            </div>
          )}
        </div>
      </div>
      {/* caption strip */}
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: 72, padding: "0 22px", display: "flex", flexDirection: "column", justifyContent: "center", gap: 4, borderTop: "1px solid var(--line)", background: "color-mix(in oklab, var(--bg) 70%, transparent)" }}>
        <div style={{ fontFamily: "var(--font-display)", fontWeight: 600, fontSize: 15, letterSpacing: "0.01em" }}>{caption}</div>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.06em", color: "var(--dim)" }}>{sub}</div>
      </div>
    </div>
  );
}

// ---- iPhone screen artboard helper ----
function Phone({ variant = "aurora", theme = "dark", reduceMotion = false, live = false, preset }) {
  return (
    <IPhoneFrame theme={theme}>
      <TunerScreen variant={variant} theme={theme} reduceMotion={reduceMotion} live={live} preset={preset} padTop={50} />
    </IPhoneFrame>
  );
}

// presets for the five key screens
const PRESETS = {
  idle:       { note: "E", octave: 2, cents: null, idle: true, mode: "auto", activeIdx: null },
  flat:       { note: "A", octave: 2, cents: -6, mode: "auto", activeIdx: 5 },
  locked:     { note: "D", octave: 3, cents: 0, mode: "auto", activeIdx: 4 },
  stringlock: { note: "G", octave: 3, cents: 7, mode: "lock", activeIdx: 3 },
  tone:       { note: "A", octave: 2, cents: null, tone: true, mode: "auto", activeIdx: 5 },
};

const SCREEN_META = {
  idle: ["Idle / attract", "breathing ambient field"],
  flat: ["Tracking · flat", "−6¢ — tune up"],
  locked: ["Locked / in-tune", "the reward — freeze + bloom"],
  stringlock: ["String-lock", "one string targeted"],
  tone: ["Tone generator", "sounding a reference"],
};

function PhoneSet({ variant, theme, idPrefix }) {
  const order = ["idle", "flat", "locked", "stringlock", "tone"];
  return (
    <React.Fragment>
      <DCArtboard id={`${idPrefix}-live`} label="Live · tap a string" width={393} height={852}>
        <Phone variant={variant} theme={theme} live />
      </DCArtboard>
      {order.map((k) => (
        <DCArtboard key={k} id={`${idPrefix}-${k}`} label={`${SCREEN_META[k][0]} · ${SCREEN_META[k][1]}`} width={393} height={852}>
          <Phone variant={variant} theme={theme} preset={PRESETS[k]} />
        </DCArtboard>
      ))}
    </React.Fragment>
  );
}

// ---- App-icon size strip ----
function IconStrip({ variant }) {
  const sizes = [120, 76, 48, 30];
  return (
    <div style={{ display: "flex", alignItems: "flex-end", gap: 22, padding: 28, background: "radial-gradient(120% 90% at 50% 0%, #14161d, #07080c 70%)", borderRadius: 18, height: "100%", boxSizing: "border-box" }}>
      {sizes.map((s) => <AppIcon key={s} variant={variant} size={s} />)}
    </div>
  );
}

function CanvasApp() {
  return (
    <DesignCanvas>
      {/* ============ HERO STROBES ============ */}
      <DCSection id="concepts" title="The Hero — a modern strobe" subtitle="Motion encodes pitch error · off-pitch drifts · dead-on freezes + blooms · both concepts, choose one">
        <DCArtboard id="a-flow" label="A · Aurora Ribbons — drifting flat" width={360} height={460}>
          <StrobeDemo variant="aurora" cents={-26} note="A" octave={2} caption="Aurora Ribbons · flat" sub="RIBBONS SLIDE LEFT · FASTER = FURTHER OFF" />
        </DCArtboard>
        <DCArtboard id="a-lock" label="A · Aurora Ribbons — locked" width={360} height={460}>
          <StrobeDemo variant="aurora" cents={0} note="A" octave={2} caption="Aurora Ribbons · in tune" sub="CONVERGES TO ONE STILL COLUMN · BLOOMS" />
        </DCArtboard>
        <DCArtboard id="b-flow" label="B · Radial Phase Ring — drifting sharp" width={360} height={460}>
          <StrobeDemo variant="radial" cents={22} note="D" octave={3} caption="Radial Phase Ring · sharp" sub="MARKS ROTATE CW · SPEED = ERROR" />
        </DCArtboard>
        <DCArtboard id="b-lock" label="B · Radial Phase Ring — locked" width={360} height={460}>
          <StrobeDemo variant="radial" cents={0} note="D" octave={3} caption="Radial Phase Ring · in tune" sub="ROTATION FREEZES · RING BLOOMS MINT" />
        </DCArtboard>
        <DCArtboard id="rm-demo" label="Reduce-Motion fallback" width={360} height={460}>
          <StrobeDemo variant="aurora" reduceMotion cents={-12} note="E" octave={2} caption="Reduce-Motion · arc + needle" sub="POSITION + SIGN + COLOUR · NOT A DOWNGRADE" />
        </DCArtboard>
      </DCSection>

      {/* ============ iPHONE · CONCEPT A ============ */}
      <DCSection id="iphone-a-dark" title="iPhone · Concept A (Aurora) · Dark" subtitle="The five key screens · first card is live — tap a string to track + lock">
        <PhoneSet variant="aurora" theme="dark" idPrefix="ad" />
      </DCSection>

      {/* ============ iPHONE · CONCEPT B ============ */}
      <DCSection id="iphone-b-dark" title="iPhone · Concept B (Radial) · Dark" subtitle="Same five screens, the rotating phase-ring hero">
        <PhoneSet variant="radial" theme="dark" idPrefix="bd" />
      </DCSection>

      {/* ============ iPHONE · LIGHT ============ */}
      <DCSection id="iphone-light" title="iPhone · Light mode" subtitle="Polished light — the sacred mint deepens to read on white; error coding holds">
        <DCArtboard id="la-live" label="Aurora · live" width={393} height={852}><Phone variant="aurora" theme="light" live /></DCArtboard>
        <DCArtboard id="la-flat" label="Aurora · flat" width={393} height={852}><Phone variant="aurora" theme="light" preset={PRESETS.flat} /></DCArtboard>
        <DCArtboard id="la-lock" label="Aurora · locked" width={393} height={852}><Phone variant="aurora" theme="light" preset={PRESETS.locked} /></DCArtboard>
        <DCArtboard id="lb-lock" label="Radial · locked" width={393} height={852}><Phone variant="radial" theme="light" preset={PRESETS.locked} /></DCArtboard>
        <DCArtboard id="lb-tone" label="Radial · tone" width={393} height={852}><Phone variant="radial" theme="light" preset={PRESETS.tone} /></DCArtboard>
        <DCArtboard id="l-rm" label="Reduce-Motion · in context" width={393} height={852}><Phone variant="aurora" theme="light" reduceMotion preset={PRESETS.flat} /></DCArtboard>
      </DCSection>

      {/* ============ iPAD ============ */}
      <DCSection id="ipad" title="iPad" subtitle="Same system, more air — propped on a stand at the session">
        <DCArtboard id="ipad-a" label="iPad · Aurora · Dark · live" width={744} height={1020}>
          <IPadFrame theme="dark"><TunerScreen variant="aurora" theme="dark" live padTop={44} /></IPadFrame>
        </DCArtboard>
        <DCArtboard id="ipad-b" label="iPad · Radial · Light · locked" width={744} height={1020}>
          <IPadFrame theme="light"><TunerScreen variant="radial" theme="light" preset={PRESETS.locked} padTop={44} /></IPadFrame>
        </DCArtboard>
      </DCSection>

      {/* ============ MAC ============ */}
      <DCSection id="mac" title="Mac" subtitle="A focused desktop window — the field goes wide and cinematic">
        <DCArtboard id="mac-a" label="Mac · Aurora · Dark · live" width={1120} height={720}>
          <MacFrame theme="dark"><TunerScreen variant="aurora" theme="dark" live padTop={14} /></MacFrame>
        </DCArtboard>
        <DCArtboard id="mac-b" label="Mac · Radial · Light · string-lock" width={1120} height={720}>
          <MacFrame theme="light"><TunerScreen variant="radial" theme="light" preset={PRESETS.stringlock} padTop={14} /></MacFrame>
        </DCArtboard>
      </DCSection>

      {/* ============ FOUNDATIONS ============ */}
      <DCSection id="foundations" title="Foundations" subtitle="Tokens — colour, type, spacing, and the glow / bloom elevation system">
        <DCArtboard id="color-dark" label="Colour · dark" width={420} height={560}><ColorTokens theme="dark" /></DCArtboard>
        <DCArtboard id="color-light" label="Colour · light" width={420} height={560}><ColorTokens theme="light" /></DCArtboard>
        <DCArtboard id="type" label="Type scale" width={420} height={560}><TypeScale theme="dark" /></DCArtboard>
        <DCArtboard id="space" label="Spacing · radius" width={420} height={560}><SpaceRadius theme="dark" /></DCArtboard>
        <DCArtboard id="glow" label="Glow / bloom" width={420} height={460}><GlowScale theme="dark" /></DCArtboard>
        <DCArtboard id="comp" label="Component library" width={460} height={560}><ComponentLib theme="dark" /></DCArtboard>
      </DCSection>

      {/* ============ APP ICON ============ */}
      <DCSection id="appicon" title="App icon" subtitle="Drawn from the strobe language — a tuned ring, a locked column, a frozen waveform">
        <DCArtboard id="ic-ring" label="Phase ring" width={240} height={240}><div style={{ display: "grid", placeItems: "center", height: "100%", background: "#0a0b10" }}><AppIcon variant="ring" size={180} /></div></DCArtboard>
        <DCArtboard id="ic-col" label="Aurora column" width={240} height={240}><div style={{ display: "grid", placeItems: "center", height: "100%", background: "#0a0b10" }}><AppIcon variant="column" size={180} /></div></DCArtboard>
        <DCArtboard id="ic-wave" label="Locked waveform" width={240} height={240}><div style={{ display: "grid", placeItems: "center", height: "100%", background: "#0a0b10" }}><AppIcon variant="wave" size={180} /></div></DCArtboard>
        <DCArtboard id="ic-sizes" label="Ring · scales" width={420} height={240}><IconStrip variant="ring" /></DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<CanvasApp />);

// ============================================================
// foundations.jsx — token + component documentation cards
// Exports: ColorTokens, TypeScale, SpaceRadius, GlowScale, ComponentLib
// Each renders on its own themed panel for placement in artboards.
// ============================================================

const { useState, useEffect, useRef, useMemo, useCallback, useLayoutEffect } = React;

function Panel({ theme = "dark", pad = 28, children, style }) {
  return (
    <div data-theme={theme} style={{
      background: "radial-gradient(120% 90% at 50% 0%, var(--bg-grad), var(--bg) 65%)",
      color: "var(--ink)", fontFamily: "var(--font-ui)", padding: pad,
      width: "100%", height: "100%", boxSizing: "border-box",
      WebkitFontSmoothing: "antialiased", ...style,
    }}>{children}</div>
  );
}

function CardTitle({ k, t }) {
  return (
    <div style={{ marginBottom: 22 }}>
      <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.2em", textTransform: "uppercase", color: "var(--dim)" }}>{k}</div>
      <div style={{ fontFamily: "var(--font-display)", fontWeight: 600, fontSize: 24, marginTop: 6, letterSpacing: "0.01em" }}>{t}</div>
    </div>
  );
}

/* ---------- COLOR ---------- */
function Swatch({ varName, name, hex, glow }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
      <div style={{
        width: 46, height: 46, borderRadius: 12, flexShrink: 0,
        background: `var(${varName})`,
        boxShadow: glow ? `0 0 18px color-mix(in oklab, var(${varName}) 55%, transparent), inset 0 0 0 1px var(--line-2)` : "inset 0 0 0 1px var(--line-2)",
      }} />
      <div style={{ lineHeight: 1.3 }}>
        <div style={{ fontFamily: "var(--font-display)", fontWeight: 600, fontSize: 14 }}>{name}</div>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--dim)" }}>{varName}</div>
        {hex && <div style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--faint)" }}>{hex}</div>}
      </div>
    </div>
  );
}

function ColorTokens({ theme = "dark" }) {
  const neutrals = [
    ["--bg", "bg", theme === "dark" ? "#0A0B10" : "#E7EAF1"],
    ["--surface", "surface", theme === "dark" ? "#14161F" : "#FFFFFF"],
    ["--surface-2", "surface-2", ""],
    ["--ink", "ink", theme === "dark" ? "#EEF1F8" : "#0D0F16"],
    ["--dim", "dim", ""],
    ["--faint", "faint", ""],
  ];
  const signal = [
    ["--flat", "flat", theme === "dark" ? "#4D8BFF" : "#2E6BFF", true],
    ["--flat-2", "flat · violet", "", true],
    ["--sharp", "sharp", theme === "dark" ? "#FFA53C" : "#D9760F", true],
    ["--sharp-2", "sharp · coral", "", true],
    ["--in-tune", "in-tune • SACRED", theme === "dark" ? "#28F0C0" : "#07A07C", true],
    ["--in-tune-2", "in-tune deep", "", true],
  ];
  return (
    <Panel theme={theme}>
      <CardTitle k={`Color · ${theme}`} t="Semantic tokens" />
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "18px 24px" }}>
        {neutrals.map((s) => <Swatch key={s[0]} varName={s[0]} name={s[1]} hex={s[2]} />)}
      </div>
      <div style={{ height: 1, background: "var(--line)", margin: "24px 0 22px" }} />
      <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.18em", textTransform: "uppercase", color: "var(--dim)", marginBottom: 16 }}>
        Error coding — never colour alone
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "18px 24px" }}>
        {signal.map((s) => <Swatch key={s[0]} varName={s[0]} name={s[1]} hex={s[2]} glow={s[3]} />)}
      </div>
    </Panel>
  );
}

/* ---------- TYPE ---------- */
function TypeScale({ theme = "dark" }) {
  const rows = [
    ["Display · note", "var(--font-display)", 600, 64, "A♯"],
    ["Numerals · cents", "var(--font-mono)", 500, 40, "−4¢"],
    ["Numerals · freq", "var(--font-mono)", 500, 22, "146.8 Hz"],
    ["UI · title", "var(--font-ui)", 600, 20, "In tune"],
    ["UI · label", "var(--font-ui)", 500, 15, "Tune up"],
    ["Mono · eyebrow", "var(--font-mono)", 500, 11, "STANDBY"],
  ];
  return (
    <Panel theme={theme}>
      <CardTitle k="Type" t="Chakra Petch · JetBrains Mono · System" />
      <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
        {rows.map((r, i) => (
          <div key={i} style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: 20, borderBottom: "1px solid var(--line)", paddingBottom: 16 }}>
            <div style={{ fontFamily: r[1], fontWeight: r[2], fontSize: r[3], letterSpacing: r[1].includes("mono") ? "0.04em" : "0", fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap" }}>{r[4]}</div>
            <div style={{ textAlign: "right", flexShrink: 0 }}>
              <div style={{ fontFamily: "var(--font-ui)", fontSize: 12, color: "var(--ink)" }}>{r[0]}</div>
              <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--dim)" }}>{r[3]}px / {r[2]}</div>
            </div>
          </div>
        ))}
      </div>
      <div style={{ marginTop: 18, fontFamily: "var(--font-mono)", fontSize: 10.5, lineHeight: 1.7, color: "var(--dim)", letterSpacing: "0.02em" }}>
        Numerals are <b style={{ color: "var(--ink)" }}>tabular</b> everywhere — cents, Hz and A4 never jitter as values change.
      </div>
    </Panel>
  );
}

/* ---------- SPACING + RADIUS ---------- */
function SpaceRadius({ theme = "dark" }) {
  const space = [["s-2", 4], ["s-3", 8], ["s-4", 12], ["s-5", 16], ["s-6", 20], ["s-7", 24], ["s-8", 32], ["s-9", 40], ["s-11", 64]];
  const radii = [["r-1", 8], ["r-2", 12], ["r-3", 16], ["r-4", 20], ["r-5", 28]];
  return (
    <Panel theme={theme}>
      <CardTitle k="Spacing · Radius" t="4pt rhythm" />
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {space.map(([n, v]) => (
          <div key={n} style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{ width: 64, fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--dim)" }}>{n}</div>
            <div style={{ height: 12, width: v, background: "var(--in-tune)", borderRadius: 3, boxShadow: "0 0 10px color-mix(in oklab, var(--in-tune) 40%, transparent)" }} />
            <div style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--faint)" }}>{v}</div>
          </div>
        ))}
      </div>
      <div style={{ height: 1, background: "var(--line)", margin: "24px 0 20px" }} />
      <div style={{ display: "flex", gap: 14, alignItems: "flex-end" }}>
        {radii.map(([n, v]) => (
          <div key={n} style={{ textAlign: "center" }}>
            <div style={{ width: 56, height: 56, borderTopLeftRadius: v, borderTopRightRadius: v, background: "var(--surface-2)", border: "1px solid var(--line-2)", borderBottom: "none" }} />
            <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--dim)", marginTop: 6 }}>{n}</div>
          </div>
        ))}
      </div>
    </Panel>
  );
}

/* ---------- GLOW / BLOOM ---------- */
function GlowScale({ theme = "dark" }) {
  const levels = [["bloom-1", "core"], ["bloom-2", "near"], ["bloom-3", "lock"]];
  return (
    <Panel theme={theme}>
      <CardTitle k="Elevation" t="Glow / Bloom — additive light" />
      <div style={{ fontFamily: "var(--font-mono)", fontSize: 10.5, color: "var(--dim)", lineHeight: 1.7, marginBottom: 26 }}>
        Depth comes from luminosity, not drop-shadows. Each level layers a tight
        core glow plus a soft outer bloom in the active hue.
      </div>
      <div style={{ display: "flex", gap: 30, alignItems: "center", justifyContent: "center", padding: "10px 0 26px" }}>
        {levels.map(([cls, lbl]) => (
          <div key={cls} style={{ textAlign: "center", "--glow": "var(--in-tune)" }}>
            <div className={cls} style={{ width: 60, height: 60, borderRadius: 16, background: "var(--in-tune)", margin: "0 auto" }} />
            <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--dim)", marginTop: 16 }}>{cls}</div>
            <div style={{ fontFamily: "var(--font-mono)", fontSize: 9, color: "var(--faint)" }}>{lbl}</div>
          </div>
        ))}
      </div>
      <div style={{ borderTop: "1px solid var(--line)", paddingTop: 24, textAlign: "center", "--glow": "var(--in-tune)" }}>
        <span className="bloom-text" style={{ fontFamily: "var(--font-display)", fontWeight: 600, fontSize: 56, color: "var(--in-tune)" }}>A</span>
        <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--dim)", marginTop: 10 }}>.bloom-text — the locked reward</div>
      </div>
    </Panel>
  );
}

/* ---------- COMPONENT LIBRARY ---------- */
function LibBlock({ label, children }) {
  return (
    <div style={{ marginBottom: 22 }}>
      <div style={{ fontFamily: "var(--font-mono)", fontSize: 9.5, letterSpacing: "0.18em", textTransform: "uppercase", color: "var(--faint)", marginBottom: 12 }}>{label}</div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 16, alignItems: "center" }}>{children}</div>
    </div>
  );
}

function ComponentLib({ theme = "dark" }) {
  const [mode, setMode] = useState("auto");
  const [src, setSrc] = useState("di");
  const [toneOn, setToneOn] = useState(false);
  const [a4, setA4] = useState(440);
  const [pick, setPick] = useState(5);
  return (
    <Panel theme={theme} pad={30}>
      <CardTitle k="Components" t="Library" />
      <LibBlock label="Cents readout">
        <CentsReadout cents={-6} state="flat" />
        <CentsReadout cents={4} state="sharp" />
        <CentsReadout cents={0} state="tune" />
      </LibBlock>
      <LibBlock label="State line">
        <StateLine state="flat" /><StateLine state="sharp" /><StateLine state="tune" /><StateLine state="idle" />
      </LibBlock>
      <LibBlock label="Target chip · A4 · input · tone">
        <TargetChip mode={mode} onChange={setMode} />
        <A4Control a4={a4} onChange={setA4} />
        <InputSource source={src} onToggle={() => setSrc(s => s === "di" ? "mic" : "di")} />
        <ToneToggle on={toneOn} onToggle={() => setToneOn(v => !v)} />
      </LibBlock>
      <LibBlock label="String selector">
        <div style={{ width: "100%", maxWidth: 380 }}>
          <StringRow tuning={TUNINGS.guitar} activeIdx={pick} lockedIdx={null} onPick={setPick} />
        </div>
      </LibBlock>
    </Panel>
  );
}

Object.assign(window, { Panel, ColorTokens, TypeScale, SpaceRadius, GlowScale, ComponentLib, CardTitle });

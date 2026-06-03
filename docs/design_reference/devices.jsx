// ============================================================
// devices.jsx — dark-luminous device frames
// Exports: IPhoneFrame, IPadFrame, MacFrame, StatusBar
// Each wraps a <TunerScreen/> (or anything). Frames are sized at natural
// pixel dimensions; the design canvas scales them.
// ============================================================

function StatusBar({ theme = "dark", time = "9:41", pad = "12px 28px 6px", island = true }) {
  const c = theme === "dark" ? "rgba(255,255,255,0.92)" : "rgba(0,0,0,0.85)";
  return (
    <div style={{
      position: "absolute", top: 0, left: 0, right: 0, zIndex: 40,
      display: "flex", alignItems: "center", justifyContent: "space-between",
      padding: pad, pointerEvents: "none",
      fontFamily: "-apple-system, system-ui", fontWeight: 600, fontSize: 15, color: c,
    }}>
      <div style={{ minWidth: 54 }}>{time}</div>
      <div style={{ display: "flex", gap: 7, alignItems: "center" }}>
        <svg width="18" height="11" viewBox="0 0 18 11"><g fill={c}>
          <rect x="0" y="7" width="3" height="4" rx="0.6"/><rect x="4.5" y="5" width="3" height="6" rx="0.6"/>
          <rect x="9" y="2.5" width="3" height="8.5" rx="0.6"/><rect x="13.5" y="0" width="3" height="11" rx="0.6"/>
        </g></svg>
        <svg width="25" height="12" viewBox="0 0 25 12">
          <rect x="0.5" y="0.5" width="21" height="11" rx="3" fill="none" stroke={c} strokeOpacity="0.4"/>
          <rect x="2" y="2" width="16" height="8" rx="1.6" fill={c}/>
          <path d="M23 4v4c.8-.3 1.3-1 1.3-2S23.8 4.3 23 4Z" fill={c} fillOpacity="0.5"/>
        </svg>
      </div>
    </div>
  );
}

function IPhoneFrame({ children, theme = "dark", w = 393, h = 852 }) {
  return (
    <div style={{
      width: w, height: h, borderRadius: 56, position: "relative",
      background: "#000", padding: 11, boxSizing: "border-box",
      boxShadow: "0 50px 90px -30px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.06), inset 0 0 0 2px #1a1a1f",
    }}>
      <div style={{ position: "relative", width: "100%", height: "100%", borderRadius: 46, overflow: "hidden", background: "#000" }}>
        <StatusBar theme={theme} />
        {/* dynamic island */}
        <div style={{ position: "absolute", top: 11, left: "50%", transform: "translateX(-50%)", width: 122, height: 35, borderRadius: 20, background: "#000", zIndex: 50 }} />
        {children}
        {/* home indicator */}
        <div style={{ position: "absolute", bottom: 8, left: "50%", transform: "translateX(-50%)", width: 134, height: 5, borderRadius: 100, background: theme === "dark" ? "rgba(255,255,255,0.55)" : "rgba(0,0,0,0.3)", zIndex: 60, pointerEvents: "none" }} />
      </div>
    </div>
  );
}

function IPadFrame({ children, theme = "dark", w = 744, h = 1020 }) {
  return (
    <div style={{
      width: w, height: h, borderRadius: 34, position: "relative",
      background: "#000", padding: 16, boxSizing: "border-box",
      boxShadow: "0 50px 90px -30px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.06), inset 0 0 0 2px #18181d",
    }}>
      <div style={{ position: "relative", width: "100%", height: "100%", borderRadius: 20, overflow: "hidden", background: "#000" }}>
        <StatusBar theme={theme} pad="14px 30px 6px" />
        {/* front camera */}
        <div style={{ position: "absolute", top: 14, left: "50%", transform: "translateX(-50%)", width: 7, height: 7, borderRadius: "50%", background: "#0c0c10", boxShadow: "0 0 0 2px rgba(255,255,255,0.04)", zIndex: 50 }} />
        {children}
        <div style={{ position: "absolute", bottom: 7, left: "50%", transform: "translateX(-50%)", width: 220, height: 5, borderRadius: 100, background: theme === "dark" ? "rgba(255,255,255,0.5)" : "rgba(0,0,0,0.28)", zIndex: 60 }} />
      </div>
    </div>
  );
}

function MacFrame({ children, theme = "dark", w = 1120, h = 720, title = "LUMA Tuner" }) {
  const dark = theme === "dark";
  const bar = dark ? "#16181f" : "#e9ebf1";
  const barText = dark ? "rgba(255,255,255,0.6)" : "rgba(0,0,0,0.55)";
  return (
    <div style={{
      width: w, height: h, borderRadius: 14, position: "relative", overflow: "hidden",
      boxShadow: "0 50px 100px -30px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.07)",
      background: "#000", fontFamily: "-apple-system, system-ui",
    }}>
      {/* title bar */}
      <div style={{ height: 40, background: bar, display: "flex", alignItems: "center", padding: "0 16px", gap: 8, position: "relative", zIndex: 30, borderBottom: dark ? "1px solid rgba(255,255,255,0.06)" : "1px solid rgba(0,0,0,0.08)" }}>
        <div style={{ display: "flex", gap: 8 }}>
          <span style={{ width: 12, height: 12, borderRadius: "50%", background: "#ff5f57" }} />
          <span style={{ width: 12, height: 12, borderRadius: "50%", background: "#febc2e" }} />
          <span style={{ width: 12, height: 12, borderRadius: "50%", background: "#28c840" }} />
        </div>
        <div style={{ position: "absolute", left: 0, right: 0, textAlign: "center", fontSize: 13, color: barText, fontWeight: 500, letterSpacing: 0.2 }}>{title}</div>
      </div>
      {/* window body */}
      <div style={{ position: "absolute", top: 40, left: 0, right: 0, bottom: 0 }}>
        {children}
      </div>
    </div>
  );
}

Object.assign(window, { IPhoneFrame, IPadFrame, MacFrame, StatusBar });

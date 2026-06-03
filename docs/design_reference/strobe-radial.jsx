// ============================================================
// strobe-radial.jsx — Concept B: RADIAL PHASE RING
// A glowing ring of phase marks rotating around the note. Rotation speed =
// pitch error, direction = sharp(CW)/flat(CCW). On pitch the ring FREEZES
// and blooms into a continuous mint halo. Additive luminosity, dark field.
// Exports: RadialStrobe
// Relies on _strobeUtil from strobe-aurora.jsx (mix, rgba, readPalette).
// ============================================================

const { useState, useEffect, useRef, useMemo, useCallback, useLayoutEffect } = React;

function RadialStrobe({ centsRef, cents = 0, animated = true, idle = false, theme = "dark", marks = 36 }) {
  const wrapRef = useRef(null);
  const canvasRef = useRef(null);
  const palRef = useRef(null);
  const angRef = useRef(0);
  const lockRef = useRef(0);
  const sizeRef = useRef({ w: 10, h: 10, dpr: 1 });
  const U = window._strobeUtil;

  useLayoutEffect(() => {
    if (wrapRef.current) palRef.current = U.readPalette(wrapRef.current);
  }, [theme]);

  const getErr = () => (centsRef ? centsRef.current : cents);

  function measure() {
    const el = wrapRef.current, cv = canvasRef.current;
    if (!el || !cv) return false;
    const cw = el.clientWidth, ch = el.clientHeight;
    if (cw < 2 || ch < 2) return false;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    if (cw !== sizeRef.current.w || ch !== sizeRef.current.h || dpr !== sizeRef.current.dpr) {
      sizeRef.current = { w: cw, h: ch, dpr };
      cv.width = Math.round(cw * dpr);
      cv.height = Math.round(ch * dpr);
    }
    return true;
  }

  function draw(err, t, dt) {
    const cv = canvasRef.current; if (!cv) return;
    const pal = palRef.current; if (!pal) return;
    if (!measure()) return;
    const ctx = cv.getContext("2d");
    const { w, h, dpr } = sizeRef.current;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);

    const cx = w / 2, cy = h / 2;
    const R = Math.min(w, h) * 0.40;       // ring radius
    const absErr = Math.abs(err), sign = Math.sign(err) || 1;
    const inLock = absErr < LOCK_CENTS;
    const light = theme === "light";

    const target = inLock ? 1 : 0;
    lockRef.current += (target - lockRef.current) * Math.min(1, dt * 6 + (animated ? 0 : 1));
    const lock = lockRef.current;
    const prox = Math.max(0, 1 - absErr / 18);

    // rotation speed ∝ error, frozen at lock
    const omega = sign * absErr * 0.010 * (1 - lock);
    if (animated) angRef.current += omega * (dt * 60);
    const breath = idle ? 0.55 + 0.45 * Math.sin(t * 1.4) : 1;

    const side = sign < 0 ? U.mix(pal.flat, pal.flat2, 0.35) : U.mix(pal.sharp, pal.sharp2, 0.35);
    const col = U.mix(side, pal.tune, Math.max(prox * 0.7, lock));

    ctx.globalCompositeOperation = light ? "source-over" : "lighter";

    // faint base track
    ctx.strokeStyle = U.rgba(pal.ink, 0.05);
    ctx.lineWidth = Math.max(8, R * 0.13);
    ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2); ctx.stroke();

    // phase marks
    const markLen = R * 0.20;
    const markW = Math.max(2.5, R * 0.045);
    for (let i = 0; i < marks; i++) {
      const base = (i / marks) * Math.PI * 2;
      const a = base + angRef.current;
      // brightness sweeps so the leading edge reads as motion; at top (-PI/2) brightest
      const phase = Math.cos(a - Math.atan2(-1, 0));
      const env = 0.35 + 0.65 * Math.pow((phase + 1) / 2, 1.5);
      const alpha = (0.12 + 0.6 * env) * breath * (1 - lock * 0.35) * (light ? 0.6 : 1);
      const r0 = R - markLen / 2, r1 = R + markLen / 2;
      const x0 = cx + Math.cos(a) * r0, y0 = cy + Math.sin(a) * r0;
      const x1 = cx + Math.cos(a) * r1, y1 = cy + Math.sin(a) * r1;
      const g = ctx.createLinearGradient(x0, y0, x1, y1);
      g.addColorStop(0, U.rgba(col, alpha * 0.5));
      g.addColorStop(0.5, U.rgba(col, alpha));
      g.addColorStop(1, U.rgba(col, alpha * 0.5));
      ctx.strokeStyle = g;
      ctx.lineWidth = markW;
      ctx.lineCap = "round";
      ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.stroke();
    }

    // continuous solid ring as we lock
    if (lock > 0.01 || prox > 0.4) {
      const ringA = Math.max(lock, (prox - 0.4) * 0.6);
      ctx.strokeStyle = U.rgba(U.mix(col, pal.tune, lock), 0.5 * ringA);
      ctx.lineWidth = markW * (1 + lock);
      ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2); ctx.stroke();
    }

    // bloom halo at lock
    if (lock > 0.01) {
      const bScale = light ? 0.55 : 1;
      const rg = ctx.createRadialGradient(cx, cy, R * 0.2, cx, cy, R * 1.5);
      rg.addColorStop(0, U.rgba(pal.tune, 0.10 * lock * bScale));
      rg.addColorStop(0.45, U.rgba(pal.tune, 0.22 * lock * bScale));
      rg.addColorStop(0.7, U.rgba(pal.tune, 0.06 * lock * bScale));
      rg.addColorStop(1, U.rgba(pal.tune, 0));
      ctx.fillStyle = rg;
      ctx.beginPath(); ctx.arc(cx, cy, R * 1.5, 0, Math.PI * 2); ctx.fill();
    }

    ctx.globalCompositeOperation = "source-over";
  }

  useClock((t, dt) => { if (animated) draw(getErr(), t, dt); }, [animated, idle, marks]);
  useEffect(() => {
    if (animated) return;
    let raf = requestAnimationFrame(() => { draw(getErr(), 0, 0); raf = requestAnimationFrame(() => draw(getErr(), 0, 0)); });
    return () => cancelAnimationFrame(raf);
  }, [animated, cents, theme]);

  return (
    <div ref={wrapRef} style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <canvas ref={canvasRef} style={{ width: "100%", height: "100%", display: "block" }} />
    </div>
  );
}

window.RadialStrobe = RadialStrobe;

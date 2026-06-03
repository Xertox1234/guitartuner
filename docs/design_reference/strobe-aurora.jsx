// ============================================================
// strobe-aurora.jsx — Concept A: AURORA RIBBONS
// Vertical ribbons of light flowing laterally. Flow speed = pitch error,
// direction = sharp(right)/flat(left). As you near pitch the ribbons
// converge to one bright central column; at lock it FREEZES and blooms
// in the sacred in-tune mint. Additive luminosity on a dark field.
// Exports: AuroraStrobe
// ============================================================

const { useState, useEffect, useRef, useMemo, useCallback, useLayoutEffect } = React;

// read a CSS color string -> {r,g,b} via canvas normalisation
const _ccx = document.createElement("canvas").getContext("2d");
function cssRGB(str) {
  _ccx.fillStyle = "#000";
  _ccx.fillStyle = str;
  const h = _ccx.fillStyle; // normalised to #rrggbb or rgba()
  if (h[0] === "#") {
    return { r: parseInt(h.slice(1, 3), 16), g: parseInt(h.slice(3, 5), 16), b: parseInt(h.slice(5, 7), 16) };
  }
  const m = h.match(/[\d.]+/g);
  return { r: +m[0], g: +m[1], b: +m[2] };
}
function mix(a, b, t) {
  return { r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t };
}
function rgba(c, a) { return `rgba(${c.r | 0},${c.g | 0},${c.b | 0},${a})`; }

function readPalette(el) {
  const cs = getComputedStyle(el);
  const g = (n) => cssRGB(cs.getPropertyValue(n).trim() || "#888");
  return {
    flat: g("--flat"), flat2: g("--flat-2"),
    sharp: g("--sharp"), sharp2: g("--sharp-2"),
    tune: g("--in-tune"), tune2: g("--in-tune-2"),
    bg: g("--bg"), ink: g("--ink"),
  };
}

function AuroraStrobe({ centsRef, cents = 0, animated = true, idle = false, theme = "dark", count = 13 }) {
  const wrapRef = useRef(null);
  const canvasRef = useRef(null);
  const palRef = useRef(null);
  const scrollRef = useRef(0);
  const lockRef = useRef(0);
  const sizeRef = useRef({ w: 10, h: 10, dpr: 1 });

  // palette (re-read on theme change)
  useLayoutEffect(() => {
    if (wrapRef.current) palRef.current = readPalette(wrapRef.current);
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

    const cx = w / 2, absErr = Math.abs(err), sign = Math.sign(err) || 1;
    const inLock = absErr < LOCK_CENTS;
    const light = theme === "light";

    // ease lock mix
    const target = inLock ? 1 : 0;
    lockRef.current += (target - lockRef.current) * Math.min(1, dt * 6 + (animated ? 0 : 1));
    const lock = lockRef.current;

    // proximity 0..1 (1 = on pitch) drives convergence + colour toward mint
    const prox = Math.max(0, 1 - absErr / 18);

    // scroll speed ∝ error (px/s on a 0..1 normalised track). frozen at lock.
    const speed = (sign * absErr) * 0.0009 * (1 - lock);
    if (animated) scrollRef.current += speed * (dt * 60);

    // breathing for idle / subtle life
    const breath = idle ? 0.6 + 0.4 * Math.sin(t * 1.4) : 1;

    // colour for current side, blended toward mint by proximity + lock
    const side = sign < 0 ? mix(pal.flat, pal.flat2, 0.35) : mix(pal.sharp, pal.sharp2, 0.35);
    const col = mix(side, pal.tune, Math.max(prox * 0.7, lock));

    // convergence: spacing of ribbons compresses toward centre as we lock
    const spread = (0.5 - 0.34 * Math.max(prox, lock)); // fraction of width half-span

    ctx.globalCompositeOperation = light ? "source-over" : "lighter";

    const ribW = Math.max(3, w * 0.05);
    for (let i = 0; i < count; i++) {
      const f = count === 1 ? 0.5 : i / (count - 1);     // 0..1
      const centered = (f - 0.5) * 2;                     // -1..1
      let pos = 0.5 + centered * spread + scrollRef.current;
      pos = pos - Math.floor(pos);                         // wrap 0..1
      const x = pos * w;
      // brightness envelope: bright at centre column, dim at edges
      const env = Math.exp(-Math.pow((x - cx) / (w * 0.34), 2));
      const a = (0.10 + 0.5 * env) * breath * (1 - lock * 0.55) * (light ? 0.5 : 1);
      if (a < 0.01) continue;
      const grad = ctx.createLinearGradient(x, 0, x, h);
      grad.addColorStop(0, rgba(col, 0));
      grad.addColorStop(0.5, rgba(col, a));
      grad.addColorStop(1, rgba(col, 0));
      ctx.fillStyle = grad;
      const bw = ribW * (0.7 + env * 1.1);
      // soft horizontal falloff using a radial-ish gradient band
      const hgrad = ctx.createLinearGradient(x - bw, 0, x + bw, 0);
      hgrad.addColorStop(0, rgba(col, 0));
      hgrad.addColorStop(0.5, rgba(col, a));
      hgrad.addColorStop(1, rgba(col, 0));
      ctx.fillStyle = hgrad;
      ctx.fillRect(x - bw, 0, bw * 2, h);
    }

    // central column — grows as we converge / lock
    const colCol = mix(col, pal.tune, lock);
    const colA = (0.18 + 0.55 * Math.max(prox, lock)) * breath * (light ? 0.5 : 1);
    const colW = w * (0.018 + 0.05 * Math.max(prox, lock));
    const cg = ctx.createLinearGradient(cx - colW * 3, 0, cx + colW * 3, 0);
    cg.addColorStop(0, rgba(colCol, 0));
    cg.addColorStop(0.5, rgba(colCol, colA));
    cg.addColorStop(1, rgba(colCol, 0));
    ctx.fillStyle = cg;
    ctx.fillRect(cx - colW * 3, 0, colW * 6, h);

    // bloom halo at lock
    if (lock > 0.01) {
      const bScale = light ? 0.55 : 1;
      const rg = ctx.createRadialGradient(cx, h / 2, 0, cx, h / 2, h * 0.55);
      rg.addColorStop(0, rgba(pal.tune, 0.32 * lock * bScale));
      rg.addColorStop(0.5, rgba(pal.tune, 0.12 * lock * bScale));
      rg.addColorStop(1, rgba(pal.tune, 0));
      ctx.fillStyle = rg;
      ctx.fillRect(0, 0, w, h);
    }

    ctx.globalCompositeOperation = "source-over";

    // direction guide: a faint centre baseline + drift arrows (legibility, not colour-only)
    ctx.strokeStyle = rgba(pal.ink, 0.05);
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, h / 2); ctx.lineTo(w, h / 2); ctx.stroke();
  }

  useClock((t, dt) => { if (animated) draw(getErr(), t, dt); }, [animated, idle, count]);
  // draw a couple of frames for static instances (after layout + palette ready)
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

window.AuroraStrobe = AuroraStrobe;
window._strobeUtil = { cssRGB, mix, rgba, readPalette };

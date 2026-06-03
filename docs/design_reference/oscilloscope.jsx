// oscilloscope.jsx — animated waveform showing the "live" signal
const { useEffect, useRef } = React;

function Oscilloscope({ freq, cents, locked, active }) {
  const canvasRef = useRef(null);
  // Store latest props in a ref so the RAF loop reads fresh values
  // without restarting the effect (which would cancel each frame).
  const propsRef = useRef({ freq, cents, locked, active });
  useEffect(() => {
    propsRef.current = { freq, cents, locked, active };
  }, [freq, cents, locked, active]);

  function cssVar(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  }

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    const dpr = window.devicePixelRatio || 1;
    let alive = true;
    let rafId = 0;
    let phase = 0;
    let last = performance.now();

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    window.addEventListener("resize", resize);

    const draw = (t) => {
      if (!alive) return;
      const dt = (t - last) / 1000;
      last = t;
      const { freq, cents, locked, active } = propsRef.current;
      const visualFreq = 1.2 + (freq / 330) * 1.4;
      phase += dt * visualFreq * Math.PI * 2;

      const rect = canvas.getBoundingClientRect();
      const w = rect.width, h = rect.height;
      ctx.clearRect(0, 0, w, h);

      const lineCol = cssVar("--line");
      const lineCol2 = cssVar("--line-2");
      const fgFaint = cssVar("--fg-faint");
      const accent = locked ? cssVar("--cool") : cssVar("--hot");

      // Center line
      ctx.strokeStyle = lineCol;
      ctx.lineWidth = 1;
      ctx.globalAlpha = 0.35;
      ctx.beginPath();
      ctx.moveTo(0, h/2);
      ctx.lineTo(w, h/2);
      ctx.stroke();
      ctx.globalAlpha = 1;

      // Vertical tick marks
      ctx.strokeStyle = lineCol2;
      ctx.globalAlpha = 0.25;
      for (let i = 1; i < 12; i++) {
        const x = (w * i) / 12;
        ctx.beginPath();
        ctx.moveTo(x, h/2 - 4);
        ctx.lineTo(x, h/2 + 4);
        ctx.stroke();
      }
      ctx.globalAlpha = 1;

      const amplitude = active ? (h * 0.38) : 0;
      const centsDetune = (cents || 0) * 0.02;

      // Build waveform points
      const samples = 320;
      const pts = [];
      const cycles = 3.2 + (freq / 200) * 1.4;
      for (let i = 0; i <= samples; i++) {
        const x = (i / samples) * w;
        const u = i / samples;
        const ang = u * Math.PI * 2 * cycles + phase;
        let y = 0;
        y += Math.sin(ang) * 1.0;
        y += Math.sin(ang * 2 + 0.4) * 0.42;
        y += Math.sin(ang * 3 + 0.9) * 0.20;
        y += Math.sin(ang * 4 + 1.2) * 0.10;
        y += Math.sin(u * 543.21 + phase * 17.3) * 0.06;
        y += Math.sin(ang + centsDetune * 6 + phase * 0.3) * 0.05;
        const env = 0.7 + 0.3 * Math.sin(u * Math.PI);
        y *= env;
        const yPx = h/2 - y * (amplitude / 1.7);
        pts.push([x, yPx]);
      }

      // Filled gradient (subtle)
      if (active) {
        ctx.fillStyle = accent;
        ctx.globalAlpha = 0.10;
        ctx.beginPath();
        ctx.moveTo(0, h/2);
        for (const [x, y] of pts) ctx.lineTo(x, y);
        ctx.lineTo(w, h/2);
        ctx.closePath();
        ctx.fill();
        ctx.globalAlpha = 1;
      }

      // Mirrored ghost
      if (active) {
        ctx.strokeStyle = accent;
        ctx.globalAlpha = 0.20;
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let i = 0; i < pts.length; i++) {
          const [x, y] = pts[i];
          const my = h - y;
          if (i === 0) ctx.moveTo(x, my); else ctx.lineTo(x, my);
        }
        ctx.stroke();
        ctx.globalAlpha = 1;
      }

      // Main waveform
      ctx.strokeStyle = active ? accent : fgFaint;
      ctx.lineWidth = active ? 1.8 : 1;
      ctx.globalAlpha = active ? 1 : 0.4;
      ctx.lineJoin = "round";
      ctx.lineCap = "round";
      ctx.beginPath();
      for (let i = 0; i < pts.length; i++) {
        const [x, y] = pts[i];
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.stroke();
      ctx.globalAlpha = 1;

      // Head dot
      if (active) {
        const last = pts[pts.length - 1];
        ctx.fillStyle = accent;
        ctx.beginPath();
        ctx.arc(last[0], last[1], 2.6, 0, Math.PI * 2);
        ctx.fill();
      }

      rafId = requestAnimationFrame(draw);
    };
    rafId = requestAnimationFrame(draw);

    return () => {
      alive = false;
      cancelAnimationFrame(rafId);
      window.removeEventListener("resize", resize);
    };
  }, []); // Run once

  return <canvas ref={canvasRef} className="scope-canvas" />;
}

window.Oscilloscope = Oscilloscope;

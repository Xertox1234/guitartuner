// ============================================================
// strobe-core.jsx — shared animation clock + pitch math
// One rAF loop drives every strobe on the canvas. Components draw
// directly (canvas / ref transforms) so React never re-renders per frame.
// Exports to window: Clock, useClock, Music, TUNINGS, useTunerSim, LOCK_CENTS
// ============================================================
const { useState, useEffect, useRef, useMemo, useCallback, useLayoutEffect } = React;

const LOCK_CENTS = 3.0;          // |cents| under this = locked
const TRACK_CENTS = 50;          // full-scale error window

// ---- Global clock: a single rAF loop with subscribers ----
const Clock = (function () {
  const subs = new Set();
  let running = false;
  let last = 0;
  function frame(now) {
    if (!running) return;
    const dt = last ? Math.min(0.05, (now - last) / 1000) : 0;
    last = now;
    subs.forEach((fn) => { try { fn(now / 1000, dt); } catch (e) {} });
    requestAnimationFrame(frame);
  }
  return {
    subscribe(fn) {
      subs.add(fn);
      if (!running) { running = true; last = 0; requestAnimationFrame(frame); }
      return () => {
        subs.delete(fn);
        if (subs.size === 0) running = false;
      };
    },
  };
})();

// Subscribe a frame callback for the component's lifetime.
function useClock(fn, deps = []) {
  const ref = useRef(fn);
  ref.current = fn;
  useEffect(() => {
    const unsub = Clock.subscribe((t, dt) => ref.current(t, dt));
    return unsub;
  }, deps);
}

// ---- Music ----
const NOTE_NAMES = ["C", "C\u266F", "D", "D\u266F", "E", "F", "F\u266F", "G", "G\u266F", "A", "A\u266F", "B"];

const Music = {
  // midi -> frequency at a given A4 reference
  freq(midi, a4 = 440) { return a4 * Math.pow(2, (midi - 69) / 12); },
  // frequency -> nearest note info
  nearest(freq, a4 = 440) {
    const midiFloat = 69 + 12 * Math.log2(freq / a4);
    const midi = Math.round(midiFloat);
    const cents = Math.round((midiFloat - midi) * 100);
    const name = NOTE_NAMES[((midi % 12) + 12) % 12];
    const octave = Math.floor(midi / 12) - 1;
    return { name, octave, cents, midi };
  },
  // split a note label like "C\u266F" into letter + accidental
  parts(name) {
    return { letter: name[0], accidental: name.length > 1 ? name.slice(1) : "" };
  },
};

// ---- Tunings ----
// idx: 6 = lowest pitched, rendered left->right low->high
const TUNINGS = {
  guitar: {
    label: "Guitar",
    strings: [
      { idx: 6, midi: 40, note: "E", octave: 2 },
      { idx: 5, midi: 45, note: "A", octave: 2 },
      { idx: 4, midi: 50, note: "D", octave: 3 },
      { idx: 3, midi: 55, note: "G", octave: 3 },
      { idx: 2, midi: 59, note: "B", octave: 3 },
      { idx: 1, midi: 64, note: "E", octave: 4 },
    ],
  },
  bass: {
    label: "Bass",
    strings: [
      { idx: 4, midi: 28, note: "E", octave: 1 },
      { idx: 3, midi: 33, note: "A", octave: 1 },
      { idx: 2, midi: 38, note: "D", octave: 2 },
      { idx: 1, midi: 43, note: "G", octave: 2 },
    ],
  },
};

// ============================================================
// useTunerSim — drives a live, interactive tuning simulation.
// Tap a string => fresh out-of-tune reading that converges to lock,
// simulating the player turning the peg. Returns smooth cents via a
// ref the strobe reads each frame (no per-frame React renders) plus
// a throttled cents value for text readouts.
// ============================================================
function useTunerSim({ instrument = "guitar", a4 = 440, autoConverge = true } = {}) {
  const tuning = TUNINGS[instrument];
  const midStr = tuning.strings[Math.floor(tuning.strings.length / 2)];
  const [stringIdx, setStringIdx] = useState(midStr.idx);
  const [mode, setMode] = useState("auto");       // "auto" chromatic | "lock"
  const [displayCents, setDisplayCents] = useState(-18);
  const [running, setRunning] = useState(true);
  const centsRef = useRef(-18);                    // smooth value for strobe
  const targetRef = useRef(-18);                   // where we're converging
  const wobRef = useRef(0);

  const activeString = useMemo(
    () => tuning.strings.find((s) => s.idx === stringIdx) || tuning.strings[0],
    [stringIdx, instrument]
  );

  // reset on instrument change
  const mounted = useRef(false);
  useEffect(() => {
    if (!mounted.current) { mounted.current = true; return; }
    const m = TUNINGS[instrument].strings[Math.floor(TUNINGS[instrument].strings.length / 2)];
    setStringIdx(m.idx);
    const v = (Math.random() < 0.5 ? -1 : 1) * (16 + Math.random() * 24);
    centsRef.current = v; targetRef.current = 0; setDisplayCents(Math.round(v));
  }, [instrument]);

  // pluck/select a string -> jump out of tune, then converge
  const pluck = useCallback((idx) => {
    setStringIdx(idx);
    const v = (Math.random() < 0.5 ? -1 : 1) * (15 + Math.random() * 28);
    centsRef.current = v;
    targetRef.current = 0;
    setRunning(true);
    setDisplayCents(Math.round(v));
  }, []);

  const detune = useCallback(() => {
    const dir = Math.random() < 0.5 ? -1 : 1;
    centsRef.current = dir * (18 + Math.random() * 26);
    targetRef.current = 0;
    setRunning(true);
  }, []);

  // integrate convergence + wobble
  const lastEmit = useRef(0);
  useClock((t, dt) => {
    if (!running) return;
    let c = centsRef.current;
    if (autoConverge) {
      // approach target (0) at a rate that eases as we get close — "turning the peg"
      const toGo = targetRef.current - c;
      const speed = Math.sign(toGo) * Math.min(Math.abs(toGo), (8 + Math.abs(toGo) * 0.9) * dt * 6);
      c += speed;
      // micro string wobble, fades as we lock
      wobRef.current += dt;
      const wobAmp = Math.abs(c) > LOCK_CENTS ? Math.min(1.6, 0.4 + Math.abs(c) * 0.03) : 0.25;
      c += Math.sin(wobRef.current * 11) * wobAmp * dt * 8 * (Math.random() * 0.6 + 0.7);
    }
    c = Math.max(-TRACK_CENTS, Math.min(TRACK_CENTS, c));
    centsRef.current = c;
    // throttle text updates to ~20fps so tabular numerals don't thrash
    if (t - lastEmit.current > 0.05) {
      lastEmit.current = t;
      setDisplayCents(Math.round(c));
    }
  }, [running, autoConverge]);

  const freq = useMemo(() => Music.freq(activeString.midi, a4), [activeString, a4]);
  const displayedFreq = freq * Math.pow(2, displayCents / 1200);
  const locked = Math.abs(displayCents) < LOCK_CENTS;

  return {
    tuning, activeString, stringIdx, setStringIdx,
    mode, setMode, pluck, detune,
    centsRef, displayCents, displayedFreq, freq, locked,
    running, setRunning,
  };
}

Object.assign(window, { Clock, useClock, Music, NOTE_NAMES, TUNINGS, useTunerSim, LOCK_CENTS, TRACK_CENTS });

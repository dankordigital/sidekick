// The Nothing ad's music grid: "Funky Funky Music" (prettyjohn1), 112.06 BPM,
// first beat at 0.069 s. b(n) is beat n. Bars of 4 beats; phrases of 16:
// the intro (no hi-hats) to b(16), the groove from b(16), a new layer from
// b(32), the last hit at b(73) (39.15 s), silence from ~40.7 s.
export const FPS = 60;
export const END = 42;
export const BEAT = 0.53543;
export const LEAD = 0.069;
export const b = (n: number) => LEAD + n * BEAT;

/** The funky stabs before the groove starts (seconds). */
export const STABS = [7.0, 7.42, 7.84, 8.35];

export const clamp = (x: number, a = 0, c = 1) => Math.min(c, Math.max(a, x));
export const lerp = (a: number, c: number, t: number) => a + (c - a) * t;
export const prog = (t: number, t0: number, dur: number) => clamp((t - t0) / dur);
export const easeOut = (x: number) => 1 - Math.pow(1 - x, 4);
export const easeOut3 = (x: number) => 1 - Math.pow(1 - x, 3);
export const easeIn = (x: number) => x * x * x;
export const easeInOut = (x: number) => (x < 0.5 ? 8 * x ** 4 : 1 - Math.pow(-2 * x + 2, 4) / 2);
export const smooth = (x: number) => x * x * (3 - 2 * x);
/** Overshoots a little, then settles. */
export const back = (x: number, s = 1.7) => 1 + (s + 1) * Math.pow(x - 1, 3) + s * Math.pow(x - 1, 2);

/** 1 on every beat from [from], fading fast. */
export const pulse = (t: number, from = 0, decay = 9) => {
  if (t < from) return 0;
  return Math.exp(-((t - LEAD) % BEAT) * decay);
};

/** Piecewise-linear map of t through [t, v] keys (clamped at both ends). */
export const keys = (t: number, k: [number, number][], ease: (x: number) => number = (x) => x) => {
  if (t <= k[0][0]) return k[0][1];
  for (let i = 1; i < k.length; i++) {
    if (t <= k[i][0]) {
      const [t0, v0] = k[i - 1];
      const [t1, v1] = k[i];
      return lerp(v0, v1, ease((t - t0) / (t1 - t0)));
    }
  }
  return k[k.length - 1][1];
};

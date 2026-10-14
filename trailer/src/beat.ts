// The music's grid (hitslab "technology tech presentation", 132.5 BPM), the
// same one the trailer uses: bars from LEAD; the riser's hit at B(16), the
// breakdown, the drop at B(18), the last hit at B(32); the ad ends at 62 s.
export const FPS = 60;
export const END = 62;
export const LEAD = 1.86;
export const BEAT = 0.452789;
export const BAR = 4 * BEAT;
export const B = (n: number) => LEAD + n * BAR;

export const HIT = B(16);
export const DROP = B(18);
export const FINAL = B(32);

export const clamp = (x: number, a = 0, b = 1) => Math.min(b, Math.max(a, x));
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const prog = (t: number, t0: number, dur: number) => clamp((t - t0) / dur);
export const easeOut = (x: number) => 1 - Math.pow(1 - x, 4);
export const easeIn = (x: number) => x * x * x;
export const easeInOut = (x: number) => (x < 0.5 ? 8 * x ** 4 : 1 - Math.pow(-2 * x + 2, 4) / 2);
/** Overshoots a little, then settles (a "pop"). */
export const back = (x: number, s = 1.7) => 1 + (s + 1) * Math.pow(x - 1, 3) + s * Math.pow(x - 1, 2);

/** 1 right on a beat, fading fast: for pulses. */
export const pulse = (t: number, every = BEAT, decay = 7) => {
  if (t < LEAD) return 0;
  const x = (t - LEAD) % every;
  return Math.exp(-x * decay);
};

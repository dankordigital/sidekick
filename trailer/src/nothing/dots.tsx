import React from 'react';
import { back, clamp, easeOut, prog } from './beat';

export const INK = '#0A0A0A';
export const PAPER = '#F0F0EC';
export const RED = '#D71921';
export const GREEN = '#22C55E';
export const GREY = '#8A8A85';
export const LINE = '#242422';
export const MONO = 'JetBrainsMono';

// The app's 5×7 dot font (app/lib/ui/nothing.dart), plus a few signs.
const G: Record<string, string[]> = {
  A: ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  B: ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  C: ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
  D: ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  E: ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  F: ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  G: ['01111', '10000', '10000', '10011', '10001', '10001', '01111'],
  H: ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
  I: ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
  J: ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
  K: ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
  L: ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  M: ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
  N: ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  O: ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  P: ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
  Q: ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
  R: ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  S: ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  T: ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  U: ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  V: ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
  W: ['10001', '10001', '10001', '10101', '10101', '10101', '01010'],
  X: ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
  Y: ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  Z: ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
  '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': ['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
  '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
  '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
  '%': ['11001', '11010', '00010', '00100', '01000', '01011', '10011'],
  ':': ['00000', '00100', '00100', '00000', '00100', '00100', '00000'],
  '.': ['00000', '00000', '00000', '00000', '00000', '00110', '00110'],
  ',': ['00000', '00000', '00000', '00000', '00110', '00100', '01000'],
  "'": ['00100', '00100', '01000', '00000', '00000', '00000', '00000'],
  '-': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
  '/': ['00001', '00010', '00010', '00100', '01000', '01000', '10000'],
  '!': ['00100', '00100', '00100', '00100', '00100', '00000', '00100'],
  '?': ['01110', '10001', '00001', '00110', '00100', '00000', '00100'],
  '&': ['01100', '10010', '10100', '01000', '10101', '10010', '01101'],
  '+': ['00000', '00100', '00100', '11111', '00100', '00100', '00000'],
  '=': ['00000', '00000', '11111', '00000', '11111', '00000', '00000'],
  '>': ['00000', '00100', '00010', '11111', '00010', '00100', '00000'],
  '<': ['00000', '00100', '01000', '11111', '01000', '00100', '00000'],
  ' ': ['00000', '00000', '00000', '00000', '00000', '00000', '00000'],
};

type Dot = { x: number; y: number; red: boolean; col: number };

/** Dots of one line; "^" before a character paints it red. */
const layout = (text: string) => {
  const dots: Dot[] = [];
  let i = 0;
  let red = false;
  for (const ch of text.toUpperCase()) {
    if (ch === '^') {
      red = true;
      continue;
    }
    const g = G[ch] ?? G[' '];
    for (let y = 0; y < 7; y++) for (let x = 0; x < 5; x++) if (g[y][x] === '1') dots.push({ x: i * 6 + x, y, red, col: i * 6 + x });
    i++;
    red = false;
  }
  return { dots, cols: Math.max(0, i * 6 - 1) };
};

export const dotWidth = (text: string, dot: number) => layout(text).cols * dot;

const hash = (n: number) => {
  const s = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return s - Math.floor(s);
};

/**
 * Lines of dot-matrix text. The dots light up in a sweep from the left
 * starting at [start] (over [sweep] s), each popping a little; from [out]
 * they go out in the same sweep. [lineGap] in dots.
 */
export const DotText: React.FC<{
  t: number;
  lines: string[];
  dot: number;
  start?: number;
  sweep?: number;
  stagger?: number;
  out?: number;
  color?: string;
  accent?: string;
  align?: 'left' | 'center' | 'right';
  lineGap?: number;
  style?: React.CSSProperties;
}> = ({ t, lines, dot, start = 0, sweep = 0.32, stagger = 0.1, out = 1e9, color = PAPER, accent = RED, align = 'left', lineGap = 3, style }) => {
  const laid = lines.map(layout);
  const cols = Math.max(...laid.map((l) => l.cols), 1);
  const w = cols * dot;
  const h = (lines.length * 7 + (lines.length - 1) * lineGap) * dot;
  const circles: React.ReactNode[] = [];
  laid.forEach((l, li) => {
    const off = align === 'center' ? ((cols - l.cols) / 2) * dot : align === 'right' ? (cols - l.cols) * dot : 0;
    const t0 = start + li * stagger;
    l.dots.forEach((d, k) => {
      const at = t0 + (d.col / Math.max(cols, 1)) * sweep + hash(k + li * 97) * 0.06;
      const u = prog(t, at, 0.16);
      const v = prog(t, out + (d.col / Math.max(cols, 1)) * sweep * 0.6 + hash(k * 3 + li) * 0.05, 0.14);
      const s = u <= 0 ? 0 : clamp(back(u, 2.4), 0, 1.4) * (1 - easeOut(v));
      if (s <= 0.01) return;
      circles.push(
        <circle
          key={`${li}-${k}`}
          cx={off + (d.x + 0.5) * dot}
          cy={(li * (7 + lineGap) + d.y + 0.5) * dot}
          r={dot * 0.42 * s}
          fill={d.red ? accent : color}
        />,
      );
    });
  });
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ position: 'absolute', overflow: 'visible', ...style }}>
      {circles}
    </svg>
  );
};

/** The biggest dot size (a whole number of px) that fits [lines] in [width]. */
export const fitDot = (lines: string[], width: number, max = 40) => {
  const cols = Math.max(...lines.map((l) => layout(l).cols), 1);
  return Math.min(max, Math.floor(width / cols));
};

// "sk." in dots: the Nothing look's logo (app/lib/ui/nothing.dart).
const SK = ['......X...', '......X...', '.XXXX.X..X', 'X.....X.X.', '.XXX..XX..', '....X.X.X.', 'XXXX..X..X'];

/** The dotted "sk." logo; dots arrive from scattered spots from [start]. */
export const DotLogo: React.FC<{ t: number; h: number; start?: number; color?: string; out?: number; style?: React.CSSProperties }> = ({
  t,
  h,
  start = 0,
  color = PAPER,
  out = 1e9,
  style,
}) => {
  const step = h / 7;
  const dots: React.ReactNode[] = [];
  let k = 0;
  for (let y = 0; y < 7; y++)
    for (let x = 0; x < 10; x++)
      if (SK[y][x] === 'X') {
        const i = k++;
        const u = easeOut(prog(t, start + hash(i) * 0.25, 0.55));
        const fx = (hash(i + 50) - 0.5) * step * 30;
        const fy = (hash(i + 90) - 0.5) * step * 20;
        const o = easeOut(prog(t, out + hash(i + 7) * 0.15, 0.3));
        dots.push(
          <circle
            key={i}
            cx={(x + 0.5) * step + fx * (1 - u)}
            cy={(y + 0.5) * step + fy * (1 - u)}
            r={step * 0.44 * clamp(u * 1.5) * (1 - o)}
            fill={color}
            opacity={clamp(u * 2)}
          />,
        );
      }
  const r = easeOut(prog(t, start + 0.45, 0.35));
  const o = easeOut(prog(t, out + 0.1, 0.3));
  dots.push(<circle key="dot" cx={11.5 * step} cy={6.5 * step} r={step * 0.5 * back(r, 3) * (1 - o)} fill={RED} />);
  return (
    <svg width={step * 12} height={h} style={{ position: 'absolute', overflow: 'visible', ...style }}>
      {dots}
    </svg>
  );
};

/** A small uppercase mono label, spaced out (the app's NothingLabel). */
export const Label: React.FC<{ children: React.ReactNode; size: number; color?: string; style?: React.CSSProperties }> = ({
  children,
  size,
  color = GREY,
  style,
}) => (
  <div
    style={{
      position: 'absolute',
      fontFamily: MONO,
      fontWeight: 500,
      fontSize: size,
      letterSpacing: size * 0.14,
      textTransform: 'uppercase',
      color,
      whiteSpace: 'nowrap',
      ...style,
    }}
  >
    {children}
  </div>
);

/** Mono text typed out character by character from [start]. */
export const Typed: React.FC<{ t: number; text: string; start: number; cps?: number; cursor?: boolean }> = ({ t, text, start, cps = 28, cursor }) => {
  const n = Math.max(0, Math.min(text.length, Math.floor((t - start) * cps)));
  const blink = cursor && (n < text.length || Math.floor(t * 3) % 2 === 0);
  return (
    <>
      {t >= start ? text.slice(0, n) : ''}
      {cursor && t >= start ? <span style={{ opacity: blink ? 1 : 0, color: RED }}>▌</span> : null}
    </>
  );
};

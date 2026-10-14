import React from 'react';
import { Img, staticFile, useVideoConfig } from 'remotion';
import { back, clamp, easeOut, lerp, prog } from './beat';

export const VIOLET = '#a78bfa';
export const GREEN = '#4ade80';
export const INK = '#1d1530';
export const HI = 'linear-gradient(95deg, #a78bfa 0%, #e879f9 55%, #fb7185 100%)';

export const useVertical = () => {
  const { width, height } = useVideoConfig();
  return height > width;
};

/** Pick by orientation. */
export const useO = () => {
  const v = useVertical();
  return <T,>(h: T, vv: T) => (v ? vv : h);
};

export const Icon: React.FC<{ code: number; size: number; color?: string; style?: React.CSSProperties }> = ({
  code,
  size,
  color = 'white',
  style,
}) => (
  <span style={{ fontFamily: 'MaterialIcons', fontSize: size, lineHeight: 1, color, display: 'inline-block', ...style }}>
    {String.fromCodePoint(code)}
  </span>
);

export type Word = [string, 'w' | 'hi'];

/**
 * Bold words that rise in one by one; highlighted ones in the pink-to-gold
 * gradient pop in a touch bigger. Everything lifts away at [out].
 */
export const Headline: React.FC<{
  t: number;
  lines: Word[][];
  size: number;
  y: number;
  start?: number;
  out?: number;
  align?: 'center' | 'left';
  x?: number;
}> = ({ t, lines, size, y, start = 0, out = 99, align = 'center', x }) => {
  const { width } = useVideoConfig();
  const o = easeOut(prog(t, out, 0.28));
  let k = 0;
  return (
    <div
      style={{
        position: 'absolute',
        left: x ?? 0,
        width: x !== undefined ? undefined : width,
        top: y,
        textAlign: align,
        opacity: 1 - o,
        transform: `translateY(${-50 * o}px)`,
      }}
    >
      {lines.map((line, li) => (
        <div key={li} style={{ whiteSpace: 'nowrap', lineHeight: 1.08 }}>
          {line.map(([text, kind], wi) => {
            const d = start + 0.07 * k++ + li * 0.05;
            const u = prog(t, d, 0.45);
            const s = 1;
            return (
              <span
                key={wi}
                style={{
                  display: 'inline-block',
                  marginRight: size * 0.24,
                  fontFamily: 'InterDisplay',
                  fontWeight: 800,
                  fontSize: size,
                  letterSpacing: -size * 0.035,
                  opacity: clamp(u * 3),
                  transform: `translateY(${lerp(size * 0.35, 0, easeOut(u))}px) scale(${s})`,
                  ...(kind === 'hi'
                    ? {
                        background: HI,
                        WebkitBackgroundClip: 'text',
                        backgroundClip: 'text',
                        color: 'transparent',
                        textShadow: 'none',
                        filter: `blur(${(1 - easeOut(u)) * 6}px)`,
                      }
                    : { color: '#f5f5f7', filter: `blur(${(1 - easeOut(u)) * 6}px)` }),
                }}
              >
                {text}
              </span>
            );
          })}
        </div>
      ))}
    </div>
  );
};

/** A small glass pill with an icon, like Sidekick's own buttons. */
export const Pill: React.FC<{ icon: number; text: string; size?: number; style?: React.CSSProperties }> = ({
  icon,
  text,
  size = 30,
  style,
}) => (
  <div
    style={{
      display: 'inline-flex',
      alignItems: 'center',
      gap: size * 0.4,
      height: size * 2,
      padding: `0 ${size * 0.9}px 0 ${size * 0.7}px`,
      borderRadius: size,
      background: 'rgba(255,255,255,.08)',
      boxShadow: 'inset 0 0 0 1px rgba(255,255,255,.16)',
      backdropFilter: 'blur(20px)',
      color: '#f5f5f7',
      fontFamily: 'Inter',
      fontWeight: 600,
      fontSize: size,
      whiteSpace: 'nowrap',
      ...style,
    }}
  >
    <Icon code={icon} size={size * 1.1} color={VIOLET} />
    {text}
  </div>
);

/** A ring that grows and fades from (x, y), starting at t0. */
export const Ring: React.FC<{ t: number; t0: number; x: number; y: number; r0?: number; r1?: number; dur?: number; color?: string; width?: number }> = ({
  t,
  t0,
  x,
  y,
  r0 = 40,
  r1 = 300,
  dur = 0.8,
  color = 'rgba(255,255,255,.6)',
  width = 2,
}) => {
  const u = (t - t0) / dur;
  if (u < 0 || u > 1) return null;
  const r = lerp(r0, r1, easeOut(u));
  return (
    <div
      style={{
        position: 'absolute',
        left: x - r,
        top: y - r,
        width: 2 * r,
        height: 2 * r,
        borderRadius: '50%',
        border: `${width * (1 - u) + 1}px solid ${color}`,
        opacity: (1 - u) * 0.9,
      }}
    />
  );
};

/** An iPhone 17 Pro-ish front: titanium edge, black bezel, Dynamic Island. */
export const Phone: React.FC<{
  w: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ w, children, style }) => {
  const h = w * 2.17;
  const r = w * 0.16;
  return (
    <div
      style={{
        position: 'absolute',
        width: w,
        height: h,
        borderRadius: r,
        padding: w * 0.035,
        background: 'linear-gradient(135deg, #8e8e93, #3a3a3c 45%, #6e6e73)',
        boxShadow: '0 40px 90px rgba(10,0,30,.55), 0 0 0 2px rgba(255,255,255,.15) inset',
        ...style,
      }}
    >
      <div style={{ position: 'relative', width: '100%', height: '100%', borderRadius: r * 0.82, background: '#000', padding: w * 0.028 }}>
        <div style={{ position: 'relative', width: '100%', height: '100%', borderRadius: r * 0.72, overflow: 'hidden', background: '#fff' }}>
          {children}
          <div
            style={{
              position: 'absolute',
              left: '50%',
              top: w * 0.035,
              width: w * 0.3,
              height: w * 0.085,
              marginLeft: -w * 0.15,
              borderRadius: w,
              background: '#000',
            }}
          />
        </div>
      </div>
    </div>
  );
};

/** A MacBook: the lid with its screen, and a thin base under it. */
export const Mac: React.FC<{ w: number; children: React.ReactNode; style?: React.CSSProperties }> = ({ w, children, style }) => {
  const h = w * 0.66;
  return (
    <div style={{ position: 'absolute', width: w * 1.16, height: h + w * 0.05, ...style }}>
      <div
        style={{
          position: 'absolute',
          left: w * 0.08,
          width: w,
          height: h,
          borderRadius: w * 0.03,
          background: '#0b0b0e',
          padding: w * 0.018,
          boxShadow: '0 40px 100px rgba(10,0,30,.55), 0 0 0 2px #2c2c33 inset',
        }}
      >
        <div style={{ position: 'relative', width: '100%', height: '100%', borderRadius: w * 0.012, overflow: 'hidden', background: '#e9e4f6' }}>
          {children}
          <div style={{ position: 'absolute', left: '50%', top: 0, width: w * 0.11, height: w * 0.018, marginLeft: -w * 0.055, background: '#0b0b0e', borderRadius: `0 0 ${w * 0.01}px ${w * 0.01}px` }} />
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: h - 2,
          width: w * 1.16,
          height: w * 0.045,
          borderRadius: `${w * 0.005}px ${w * 0.005}px ${w * 0.04}px ${w * 0.04}px`,
          background: 'linear-gradient(180deg, #e7e7ec, #a9a9b3)',
          boxShadow: '0 20px 40px rgba(0,0,0,.35)',
        }}
      >
        <div style={{ position: 'absolute', left: '50%', top: 0, width: w * 0.16, height: w * 0.012, marginLeft: -w * 0.08, background: '#c3c3cb', borderRadius: `0 0 ${w * 0.01}px ${w * 0.01}px` }} />
      </div>
    </div>
  );
};

/** A desktop window (rounded, shadowed, traffic lights) around a screenshot. */
export const Window: React.FC<{ src: string; w: number; style?: React.CSSProperties }> = ({ src, w, style }) => (
  <div
    style={{
      position: 'absolute',
      width: w,
      borderRadius: w * 0.022,
      overflow: 'hidden',
      background: '#fff',
      boxShadow: '0 50px 120px rgba(10,0,30,.6), 0 0 0 1px rgba(255,255,255,.2)',
      ...style,
    }}
  >
    <div style={{ height: w * 0.032, background: '#efeaf8', display: 'flex', alignItems: 'center', gap: w * 0.008, paddingLeft: w * 0.014 }}>
      {['#ff5f57', '#febc2e', '#28c840'].map((c) => (
        <div key={c} style={{ width: w * 0.011, height: w * 0.011, borderRadius: '50%', background: c }} />
      ))}
    </div>
    <Img src={staticFile(src)} style={{ display: 'block', width: '100%' }} />
  </div>
);

/** A screenshot that fills its parent. */
export const Fill: React.FC<{ src: string; style?: React.CSSProperties }> = ({ src, style }) => (
  <Img src={staticFile(src)} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', objectPosition: 'top', ...style }} />
);

/** A glass "sk" tile (the app icon). */
export const SkTile: React.FC<{ size: number; style?: React.CSSProperties }> = ({ size, style }) => (
  <div style={{ position: 'absolute', width: size, height: size, ...style }}>
    <div style={{ position: 'absolute', inset: -size * 0.3, borderRadius: '50%', background: 'radial-gradient(circle, rgba(150,110,255,.55), transparent 65%)' }} />
    <Img src={staticFile('shots/sk-icon.png')} style={{ position: 'relative', width: size, height: size, borderRadius: size * 0.225, boxShadow: '0 30px 80px rgba(60,20,140,.6)' }} />
  </div>
);

/** Fades a scene in at its start and out at its end. */
export const sceneAlpha = (t: number, dur: number, fin = 0.18, fout = 0.22) =>
  clamp(Math.min(t / fin, (dur - t) / fout));

export const appear = (t: number, t0: number, dur = 0.55) => easeOut(prog(t, t0, dur));

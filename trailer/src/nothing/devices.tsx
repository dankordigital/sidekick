import React from 'react';
import { Img, staticFile } from 'remotion';
import { clamp, easeOut, lerp, prog } from './beat';
import { MONO, PAPER, RED } from './dots';

/** iPhone 17 Pro proportions (mm) and its screen (pt). */
const PHONE_W = 71.9;
const PHONE_H = 150.0;
const PHONE_D = 8.75;
export const SCREEN_ASPECT = 402 / 874;

/** Where the screen sits inside a phone [h] tall: inset and size. */
export const phoneScreen = (h: number) => {
  const w = (h * PHONE_W) / PHONE_H;
  const inset = w * 0.047;
  const sw = w - 2 * inset;
  const sh = sw / SCREEN_ASPECT;
  return { w, inset, sw, sh, top: (h - sh) / 2 };
};

/** One app screen (a JPEG under public/nothing/app). */
export const Shot: React.FC<{ src: string; style?: React.CSSProperties }> = ({ src, style }) => (
  <Img
    src={staticFile(`nothing/app/${src}.jpg`)}
    style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', objectPosition: 'top', ...style }}
  />
);

/** Frame [i] of a rendered app animation (30 fps, clamped to [count]). */
export const Seq: React.FC<{ dir: string; i: number; count: number; style?: React.CSSProperties }> = ({ dir, i, count, style }) => (
  <Shot src={`${dir}/${String(Math.round(clamp(i, 0, count - 1))).padStart(3, '0')}`} style={style} />
);

/** The iPhone status bar (9:41, signal, Wi-Fi, battery) for a screen [sw] wide. */
const StatusBar: React.FC<{ sw: number; color: string }> = ({ sw, color }) => {
  const u = sw / 402;
  return (
    <div style={{ position: 'absolute', left: 0, top: 0, width: sw, height: 54 * u, color }}>
      <div
        style={{
          position: 'absolute',
          left: 0,
          width: 150 * u,
          top: 17 * u,
          textAlign: 'center',
          fontFamily: 'Inter',
          fontWeight: 600,
          fontSize: 17 * u,
          letterSpacing: -0.2 * u,
        }}
      >
        9:41
      </div>
      <svg style={{ position: 'absolute', left: 290 * u, top: 20 * u }} width={90 * u} height={14 * u} viewBox="0 0 90 14">
        {[0, 1, 2, 3].map((i) => (
          <rect key={i} x={i * 5} y={9 - i * 2.6} width={3.4} height={3.4 + i * 2.6} rx={0.8} fill={color} />
        ))}
        <path d="M29 4.2a10.5 10.5 0 0 1 14.6 0l-1.5 1.5a8.4 8.4 0 0 0-11.6 0z M31.8 7a6.6 6.6 0 0 1 9 0l-1.6 1.6a4.3 4.3 0 0 0-5.8 0z M34.6 9.8a2.5 2.5 0 0 1 3.4 0l-1.7 1.8z" fill={color} />
        <rect x={50} y={1.5} width={24} height={11.5} rx={3.6} fill="none" stroke={color} strokeOpacity={0.4} strokeWidth={1} />
        <rect x={52} y={3.5} width={18} height={7.5} rx={2} fill={color} />
        <path d="M75.5 5.5v3.6a1.9 1.9 0 0 0 0-3.6z" fill={color} fillOpacity={0.45} />
      </svg>
    </div>
  );
};

const lens = (cx: number, cy: number, r: number) => (
  <g key={`${cx}-${cy}`}>
    <circle cx={cx} cy={cy} r={r} fill="#b9bcc3" />
    <circle cx={cx} cy={cy} r={r * 0.86} fill="#26272b" />
    <circle cx={cx} cy={cy} r={r * 0.62} fill="#0b0b0e" />
    <circle cx={cx} cy={cy} r={r * 0.36} fill="#151a2c" />
    <circle cx={cx - r * 0.2} cy={cy - r * 0.22} r={r * 0.12} fill="#8fa3ff" opacity={0.55} />
  </g>
);

/**
 * An iPhone 17 Pro in silver, built in 3D: the screen side, the aluminium
 * band (stacked layers), the back with its camera plateau and the buttons.
 * Turn it with [ry] / [rx] / [rz] (degrees). [press] pushes the side
 * buttons in (0..1), for a screenshot.
 */
export const IPhone: React.FC<{
  h: number;
  ry?: number;
  rx?: number;
  rz?: number;
  press?: number;
  darkStatus?: boolean;
  status?: boolean;
  glare?: number;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ h, ry = 0, rx = 0, rz = 0, press = 0, status = true, darkStatus = false, glare = 1, children, style }) => {
  const { w, inset, sw, sh, top } = phoneScreen(h);
  const d = (h * PHONE_D) / PHONE_H;
  const r = w * 0.185;
  const layers = 18;
  const band: React.ReactNode[] = [];
  for (let i = 0; i <= layers; i++) {
    const k = i / layers;
    const shade = 0.62 + 0.38 * Math.sin(Math.PI * k);
    const c = (v: number) => Math.round(v * shade);
    band.push(
      <div
        key={i}
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: r,
          background: `rgb(${c(214)},${c(216)},${c(222)})`,
          transform: `translateZ(${-d / 2 + k * d}px)`,
        }}
      />,
    );
  }
  // Side buttons: planes standing on the band (left: Action, volume; right: side button, Camera Control).
  const button = (side: 'l' | 'r', y0: number, y1: number, pressed = 0) => (
    <div
      key={`${side}${y0}`}
      style={{
        position: 'absolute',
        left: side === 'l' ? -d / 2 : w - d / 2,
        top: h * y0,
        width: d,
        height: h * (y1 - y0),
        borderRadius: d * 0.3,
        background: 'linear-gradient(90deg, #8d9097, #e4e6eb 50%, #8d9097)',
        transform: `rotateY(90deg) translateZ(${(side === 'l' ? 1 : -1) * (h * 0.0045 * (1 - pressed))}px) scaleX(0.55)`,
      }}
    />
  );
  const facing = Math.cos((ry * Math.PI) / 180) * Math.cos((rx * Math.PI) / 180);
  return (
    <div style={{ position: 'absolute', width: w, height: h, perspective: h * 3.2, ...style }}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          transformStyle: 'preserve-3d',
          transform: `rotateZ(${rz}deg) rotateX(${rx}deg) rotateY(${ry}deg)`,
        }}
      >
        {band}
        {button('l', 0.205, 0.238)}
        {button('l', 0.275, 0.335, press)}
        {button('l', 0.355, 0.415)}
        {button('r', 0.29, 0.4, press)}
        {button('r', 0.56, 0.625)}
        {/* The back: aluminium, the camera plateau across the top. */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: r,
            transform: `translateZ(${-d / 2 - 0.5}px) rotateY(180deg)`,
            backfaceVisibility: 'hidden',
            background: 'linear-gradient(160deg, #e9eaee, #c7c9cf 55%, #dcdde2)',
            overflow: 'hidden',
          }}
        >
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: 0,
              height: h * 0.25,
              borderRadius: `${r}px ${r}px ${w * 0.08}px ${w * 0.08}px`,
              background: 'linear-gradient(180deg, #f2f3f6, #d2d4da)',
              boxShadow: `0 ${h * 0.004}px ${h * 0.01}px rgba(0,0,0,.25)`,
            }}
          >
            <svg width={w} height={h * 0.25} viewBox={`0 0 ${w} ${h * 0.25}`}>
              {lens(w * 0.22, h * 0.07, w * 0.115)}
              {lens(w * 0.22, h * 0.178, w * 0.115)}
              {lens(w * 0.43, h * 0.124, w * 0.115)}
              <circle cx={w * 0.8} cy={h * 0.07} r={w * 0.045} fill="#f5edd8" stroke="#a7a9ae" strokeWidth={1.5} />
              <circle cx={w * 0.8} cy={h * 0.178} r={w * 0.04} fill="#1b1b1f" />
            </svg>
          </div>
          <div style={{ position: 'absolute', left: w * 0.12, right: w * 0.12, top: h * 0.43, height: h * 0.32, borderRadius: w * 0.05, background: 'rgba(255,255,255,.18)' }} />
        </div>
        {/* The front: band edge, black glass, the screen. */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: r,
            transform: `translateZ(${d / 2 + 0.5}px)`,
            backfaceVisibility: 'hidden',
            background: 'linear-gradient(135deg, #f4f5f8, #a9acb3 40%, #eceef2 60%, #9da0a7)',
            padding: w * 0.011,
          }}
        >
          <div style={{ position: 'relative', width: '100%', height: '100%', borderRadius: r - w * 0.011, background: '#050506' }}>
            <div
              style={{
                position: 'absolute',
                left: inset - w * 0.011,
                top: top - w * 0.011,
                width: sw,
                height: sh,
                borderRadius: sw * 0.137,
                overflow: 'hidden',
                background: '#0A0A0A',
              }}
            >
              {children}
              {status ? <StatusBar sw={sw} color={darkStatus ? '#0D0D0D' : '#F5F5F2'} /> : null}
              <div
                style={{
                  position: 'absolute',
                  left: sw * (0.5 - 0.313 / 2),
                  top: sw * 0.027,
                  width: sw * 0.313,
                  height: sw * 0.092,
                  borderRadius: sw,
                  background: '#000',
                }}
              />
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  opacity: glare * clamp(facing),
                  background: `linear-gradient(${115 + ry * 0.6}deg, rgba(255,255,255,0) 30%, rgba(255,255,255,.07) 46%, rgba(255,255,255,0) 60%)`,
                }}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

/** A MacBook Pro 14" in space black, [w] wide (the lid). The screen is 16:10. */
export const macScreen = (w: number) => {
  const bezel = w * 0.016;
  const sw = w - 2 * bezel;
  const sh = sw / 1.6;
  return { bezel, sw, sh, lidH: sh + bezel * 1.6, baseW: w * 1.13, baseH: w * 0.032 };
};

export const MacBook: React.FC<{ w: number; children?: React.ReactNode; menu?: boolean; style?: React.CSSProperties }> = ({ w, children, menu = true, style }) => {
  const { bezel, sw, sh, lidH, baseW, baseH } = macScreen(w);
  const mb = sh * 0.034;
  return (
    <div style={{ position: 'absolute', width: w, height: lidH + baseH, ...style }}>
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          width: w,
          height: lidH,
          borderRadius: `${w * 0.022}px ${w * 0.022}px ${w * 0.006}px ${w * 0.006}px`,
          background: '#050506',
          boxShadow: `0 0 0 ${Math.max(1, w * 0.0018)}px #3a3b40, 0 ${w * 0.04}px ${w * 0.09}px rgba(0,0,0,.6)`,
        }}
      >
        <div style={{ position: 'absolute', left: bezel, top: bezel, width: sw, height: sh, borderRadius: w * 0.008, overflow: 'hidden', background: '#0A0A0A' }}>
          <div style={{ position: 'absolute', left: 0, right: 0, top: menu ? mb : 0, bottom: 0, overflow: 'hidden' }}>{children}</div>
          {menu ? <MenuBar w={sw} h={mb} /> : null}
          <div style={{ position: 'absolute', left: sw / 2 - sw * 0.06, top: 0, width: sw * 0.12, height: mb * 1.05, background: '#050506', borderRadius: `0 0 ${mb * 0.4}px ${mb * 0.4}px` }} />
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(120deg, rgba(255,255,255,0) 40%, rgba(255,255,255,.035) 55%, rgba(255,255,255,0) 70%)' }} />
        </div>
      </div>
      {/* The base: a thin slab, the thumb notch in the middle. */}
      <div
        style={{
          position: 'absolute',
          left: (w - baseW) / 2,
          top: lidH - 1,
          width: baseW,
          height: baseH,
          borderRadius: `${w * 0.004}px ${w * 0.004}px ${w * 0.03}px ${w * 0.03}px`,
          background: 'linear-gradient(180deg, #4a4b51 0%, #2b2c31 22%, #1a1b1f 70%, #0d0d10 100%)',
          boxShadow: `0 ${w * 0.03}px ${w * 0.05}px rgba(0,0,0,.7)`,
        }}
      >
        <div style={{ position: 'absolute', left: baseW / 2 - w * 0.075, top: 0, width: w * 0.15, height: baseH * 0.32, background: '#141418', borderRadius: `0 0 ${w * 0.012}px ${w * 0.012}px` }} />
      </div>
    </div>
  );
};

const MenuBar: React.FC<{ w: number; h: number }> = ({ w, h }) => (
  <div
    style={{
      position: 'absolute',
      left: 0,
      top: 0,
      width: w,
      height: h,
      background: '#000',
      display: 'flex',
      alignItems: 'center',
      fontFamily: 'Inter',
      fontWeight: 500,
      fontSize: h * 0.56,
      color: '#e9e9e6',
      gap: h * 0.8,
      paddingLeft: h * 0.8,
      boxSizing: 'border-box',
    }}
  >
    <span style={{ fontWeight: 700 }}>Sidekick</span>
    {['File', 'Edit', 'View', 'Window', 'Help'].map((m) => (
      <span key={m}>{m}</span>
    ))}
    <span style={{ marginLeft: 'auto', marginRight: h * 0.8, display: 'flex', gap: h * 0.8, alignItems: 'center' }}>
      <svg width={h * 0.6} height={h * 0.6} viewBox="0 0 10 10">
        {[
          [1, 1],
          [4, 1],
          [7, 1],
          [1, 4],
          [4, 4],
          [7, 4],
          [1, 7],
          [4, 7],
        ].map(([x, y]) => (
          <circle key={`${x}${y}`} cx={x + 1} cy={y + 1} r={1} fill="#e9e9e6" />
        ))}
        <circle cx={8} cy={8} r={1.2} fill={RED} />
      </svg>
      <span>Fri 24 Oct 9:41</span>
    </span>
  </div>
);

/** A touch: a soft disc that presses down, with a ring on [tap] times. */
export const Finger: React.FC<{ t: number; x: number; y: number; size: number; show: number; taps?: number[] }> = ({ t, x, y, size, show, taps = [] }) => {
  if (show <= 0.01) return null;
  let press = 0;
  let ring: React.ReactNode = null;
  for (const at of taps) {
    const u = (t - at) / 0.5;
    if (u > -0.15 && u < 1) {
      press = Math.max(press, u < 0 ? 1 + u / 0.15 : 1 - easeOut(clamp(u * 2)));
      if (u >= 0) {
        const rr = size * (0.5 + 1.1 * easeOut(u));
        ring = (
          <div
            style={{
              position: 'absolute',
              left: x - rr,
              top: y - rr,
              width: 2 * rr,
              height: 2 * rr,
              borderRadius: '50%',
              border: `${size * 0.05}px solid rgba(255,255,255,${0.7 * (1 - u)})`,
            }}
          />
        );
      }
    }
  }
  const s = size * (1 - 0.18 * press);
  return (
    <>
      {ring}
      <div
        style={{
          position: 'absolute',
          left: x - s / 2,
          top: y - s / 2,
          width: s,
          height: s,
          borderRadius: '50%',
          background: `rgba(255,255,255,${0.32 + 0.2 * press})`,
          boxShadow: `0 0 0 ${size * 0.03}px rgba(255,255,255,.55), 0 ${size * 0.1}px ${size * 0.3}px rgba(0,0,0,.35)`,
          opacity: show,
        }}
      />
    </>
  );
};

/** The macOS arrow pointer, tip at (x, y); dips on [clicks]. */
export const Cursor: React.FC<{ t: number; x: number; y: number; size: number; clicks?: number[]; show?: number }> = ({ t, x, y, size, clicks = [], show = 1 }) => {
  let press = 0;
  let ring: React.ReactNode = null;
  for (const at of clicks) {
    const u = (t - at) / 0.45;
    if (u > -0.12 && u < 1) {
      press = Math.max(press, u < 0 ? 1 + u / 0.12 : 1 - easeOut(clamp(u * 2.5)));
      if (u >= 0) {
        const rr = size * (0.2 + 0.9 * easeOut(u));
        ring = (
          <div
            style={{
              position: 'absolute',
              left: x - rr,
              top: y - rr,
              width: 2 * rr,
              height: 2 * rr,
              borderRadius: '50%',
              border: `${size * 0.06}px solid rgba(215,25,33,${1 - u})`,
            }}
          />
        );
      }
    }
  }
  if (show <= 0.01) return null;
  const s = size * (1 - 0.15 * press);
  return (
    <>
      {ring}
      <svg style={{ position: 'absolute', left: x - s * 0.08, top: y - s * 0.05, opacity: show, filter: `drop-shadow(0 ${s * 0.06}px ${s * 0.1}px rgba(0,0,0,.5))` }} width={s} height={s * 1.5} viewBox="0 0 20 30">
        <path d="M1.5 1.5 L1.5 23.5 L7 18.5 L10.6 27 L14.2 25.5 L10.7 17.2 L18 17.2 Z" fill="#000" stroke="#fff" strokeWidth={1.6} strokeLinejoin="round" />
      </svg>
    </>
  );
};

/** A file on the move: a photo or a document card. */
export const FileCard: React.FC<{ kind: 'photo' | 'video' | 'doc'; src?: string; name: string; w: number; style?: React.CSSProperties }> = ({ kind, src, name, w, style }) => (
  <div
    style={{
      position: 'absolute',
      width: w,
      height: w * 1.25,
      borderRadius: w * 0.09,
      overflow: 'hidden',
      background: kind === 'doc' ? PAPER : '#111',
      boxShadow: `0 ${w * 0.08}px ${w * 0.2}px rgba(0,0,0,.55), 0 0 0 ${Math.max(1, w * 0.012)}px rgba(255,255,255,.25)`,
      ...style,
    }}
  >
    {kind === 'doc' ? (
      <>
        <svg width={w} height={w * 0.8} viewBox="0 0 10 8" style={{ position: 'absolute', top: w * 0.08 }}>
          {[...Array(5)].map((_, y) =>
            [...Array(7)].map((__, x) => (x + y) % 2 === 0 && y < 4 ? <circle key={`${x}${y}`} cx={2 + x} cy={1.5 + y} r={0.32} fill={y === 0 && x === 0 ? RED : '#0D0D0D'} /> : null),
          )}
        </svg>
        <div style={{ position: 'absolute', left: w * 0.08, right: w * 0.08, bottom: w * 0.1, fontFamily: MONO, fontWeight: 500, fontSize: w * 0.095, color: '#0D0D0D', lineHeight: 1.2, wordBreak: 'break-all' }}>
          {name}
        </div>
      </>
    ) : (
      <>
        <Img src={staticFile(`nothing/photos/${src}`)} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        {kind === 'video' ? (
          <div style={{ position: 'absolute', left: w * 0.07, bottom: w * 0.07, fontFamily: MONO, fontWeight: 700, fontSize: w * 0.1, color: '#fff', letterSpacing: w * 0.01 }}>▶ 0:42</div>
        ) : null}
      </>
    )}
  </div>
);

/** A point along a quadratic curve from a to c, bulging through b. */
export const quad = (a: [number, number], bb: [number, number], c: [number, number], u: number): [number, number] => [
  lerp(lerp(a[0], bb[0], u), lerp(bb[0], c[0], u), u),
  lerp(lerp(a[1], bb[1], u), lerp(bb[1], c[1], u), u),
];

export const appear = (t: number, t0: number, dur = 0.5) => easeOut(prog(t, t0, dur));

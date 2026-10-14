import React from 'react';
import { AbsoluteFill, Audio, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import { B, BAR, BEAT, DROP, END, FINAL, FPS, HIT, LEAD, clamp, easeInOut, lerp, prog, pulse } from './beat';
import * as S from './scenes';

type Scene = [number, number, React.FC<S.SceneProps>];

// Every feature, fast, on the bar lines. The riser's hit (B16) cuts to the
// dark; phone notifications land on the drop (B18); the logo on the last hit.
const SCENES: Scene[] = [
  [0, B(0), S.Intro],
  [B(0), B(2), S.YourDevices],
  [B(2), B(4), S.MeetSidekick],
  [B(4), B(6), S.SendFiles],
  [B(6), B(7), S.Screenshots],
  [B(7), B(8), S.Touchpad],
  [B(8), B(9), S.Keyboard],
  [B(9), B(10), S.Files],
  [B(10), B(11), S.Ping],
  [B(11), B(12), S.Corner],
  [B(12), B(13), S.Tray],
  [B(13), B(14), S.QrPair],
  [B(14), B(15), S.DirectWifi],
  [B(15), HIT, S.Bluetooth],
  [HIT, DROP, S.OneMoreThing],
  [DROP, B(21), S.PhoneNotifications],
  [B(21), B(22), S.LiveActivity],
  [B(22), B(23), S.Gallery],
  [B(23), B(24), S.Background],
  [B(24), B(25), S.Encrypted],
  [B(25), B(26), S.NoAccount],
  [B(26), B(27), S.Themes],
  [B(27), B(29), S.Platforms],
  [B(29), B(31), S.Montage],
  [B(31), FINAL, S.Converge],
  [FINAL, END, S.EndCard],
];

/** Deep purple, with slow glowing blobs that breathe with the beat. */
const Backdrop: React.FC<{ T: number }> = ({ T }) => {
  const { width, height } = useVideoConfig();
  const energy = T < B(4) ? 0.4 : T >= HIT && T < DROP ? 0.1 : 1;
  const p = pulse(T, BEAT, 5) * energy;
  const dim = T < B(0) ? 1 - easeInOut(prog(T, 0, B(0))) * 0.7 : T >= HIT && T < DROP ? 0.55 * easeInOut(prog(T, HIT + 0.1, 1.2)) : 0;
  const blobs = [
    { c: '#7b3cff', x: 0.25, y: 0.3, r: 0.55, s: 0.13 },
    { c: '#ff4fa3', x: 0.78, y: 0.65, r: 0.5, s: 0.1 },
    { c: '#3b5bff', x: 0.6, y: 0.2, r: 0.45, s: 0.16 },
  ];
  const m = Math.max(width, height);
  return (
    <AbsoluteFill style={{ background: 'linear-gradient(160deg, #12062b 0%, #1d0b45 45%, #2a0d4a 100%)' }}>
      {blobs.map((b, i) => {
        const a = T * b.s + i * 2.1;
        const x = (b.x + Math.cos(a) * 0.12) * width;
        const y = (b.y + Math.sin(a * 0.8) * 0.12) * height;
        const r = b.r * m * (1 + 0.04 * p);
        return (
          <div key={i} style={{ position: 'absolute', left: x - r / 2, top: y - r / 2, width: r, height: r, borderRadius: '50%', background: `radial-gradient(circle, ${b.c}aa, transparent 62%)`, opacity: 0.55 + 0.25 * p }} />
        );
      })}
      <AbsoluteFill style={{ background: 'radial-gradient(ellipse at center, transparent 55%, rgba(5,0,15,.55))' }} />
      <AbsoluteFill style={{ background: '#04010c', opacity: dim }} />
    </AbsoluteFill>
  );
};

/** Specks of light drifting up. */
const Particles: React.FC<{ T: number }> = ({ T }) => {
  const { width, height } = useVideoConfig();
  const dots = [];
  for (let i = 0; i < 40; i++) {
    const fx = (Math.sin(i * 12.9898) * 43758.5453) % 1;
    const fy = (Math.sin(i * 78.233) * 12345.678) % 1;
    const z = 0.3 + ((Math.sin(i * 4.1) + 1) / 2) * 0.7;
    const y = (((Math.abs(fy) * (height + 200) - T * (20 + 60 * z)) % (height + 200)) + height + 200) % (height + 200) - 100;
    const x = Math.abs(fx) * width + 30 * Math.sin(T * 0.4 + i) * z;
    const r = 1.5 + 4 * z * z;
    dots.push(<div key={i} style={{ position: 'absolute', left: x, top: y, width: r * 2, height: r * 2, borderRadius: r, background: '#d8ccff', opacity: 0.15 + 0.35 * (1 - z), filter: `blur(${z * 1.5}px)` }} />);
  }
  return <>{dots}</>;
};

export const Trailer: React.FC = () => {
  const frame = useCurrentFrame();
  const T = frame / FPS;
  const flashes: [number, number][] = [[B(2), 0.25], [B(4), 0.3], [HIT, 0.55], [DROP, 0.6], [B(27), 0.25], [FINAL, 0.45]];
  let flash = 0;
  for (const [t0, peak] of flashes) {
    const u = (T - t0) / 0.4;
    if (u >= 0 && u <= 1) flash = Math.max(flash, peak * (1 - u) ** 2);
  }
  // A soft flash on every beat after the drop, stronger on the bar.
  if (T >= DROP && T < FINAL) {
    const bt = LEAD + Math.floor((T - LEAD) / BEAT) * BEAT;
    const onBar = Math.abs((bt - LEAD) / BAR - Math.round((bt - LEAD) / BAR)) < 0.01;
    flash = Math.max(flash, (onBar ? 0.08 : 0.035) * Math.exp(-(T - bt) * 9));
  }
  return (
    <AbsoluteFill style={{ overflow: 'hidden' }}>
      {/* The first 62 s of the track, faded out over the last 1.2 s. */}
      <Audio src={staticFile('music.mp3')} volume={(f) => clamp((END - f / FPS) / 1.2)} />
      <Backdrop T={T} />
      <Particles T={T} />
      {SCENES.map(([a, b, C], i) => {
        if (T < a || T >= b) return null;
        const t = T - a;
        const d = b - a;
        // Each scene pushes in a little and fades at its edges.
        const alpha = i === 0 ? 1 : clamp(Math.min(t / 0.12, (d - t) / 0.16));
        const zoom = lerp(1.03, 1, clamp(t / 0.4));
        return (
          <AbsoluteFill key={i} style={{ opacity: alpha, transform: `scale(${zoom})` }}>
            <C t={t} d={d} T={T} />
          </AbsoluteFill>
        );
      })}
      <AbsoluteFill style={{ background: 'white', opacity: flash, pointerEvents: 'none' }} />
      {T < 0.5 && <AbsoluteFill style={{ background: 'black', opacity: 1 - T / 0.5 }} />}
    </AbsoluteFill>
  );
};

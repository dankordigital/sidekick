import React from 'react';
import { AbsoluteFill, Audio, spring, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import { B, BAR, BEAT, DROP, END, FINAL, FPS, HIT, LEAD, clamp, easeIn, easeInOut, easeOut, lerp, prog, pulse } from './beat';
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
  [B(31), FINAL, S.Words],
  [FINAL, END, S.EndCard],
];

/** Black, with one soft light that breathes with the music. */
const Backdrop: React.FC<{ T: number }> = ({ T }) => {
  const { width, height } = useVideoConfig();
  const m = Math.max(width, height);
  const glow = (T >= HIT && T < DROP ? 0.25 : 1) * (0.55 + 0.15 * pulse(T, BAR, 3));
  return (
    <AbsoluteFill style={{ background: '#000' }}>
      <div style={{ position: 'absolute', left: width / 2 - m * 0.5, top: height * 0.62 - m * 0.5, width: m, height: m, borderRadius: '50%', background: 'radial-gradient(circle, rgba(124,92,255,.32), rgba(124,92,255,0) 60%)', opacity: glow }} />
    </AbsoluteFill>
  );
};

const WHIP = 0.05;

/** The camera: a slow push-in, and a small kick on each bar once the music is going. */
const camera = (T: number, _width: number) => {
  const going = (T >= B(4) && T < HIT) || (T >= DROP && T < FINAL);
  const kick = going ? pulse(T, BAR, 7) * 0.012 : 0;
  return `scale(${1 + kick})`;
};

export const Trailer: React.FC = () => {
  const { width } = useVideoConfig();
  const frame = useCurrentFrame();
  const T = frame / FPS;
  const flashes: [number, number][] = [[HIT, 0.9], [DROP, 0.9], [FINAL, 0.9]];
  let flash = 0;
  for (const [t0, peak] of flashes) {
    const u = (T - t0) / 0.4;
    if (u >= 0 && u <= 1) flash = Math.max(flash, peak * (1 - u) ** 2);
  }
  // A soft flash on every beat after the drop, stronger on the bar.
  if (T >= DROP && T < FINAL) {
    const bt = LEAD + Math.floor((T - LEAD) / BEAT) * BEAT;
    const onBar = Math.abs((bt - LEAD) / BAR - Math.round((bt - LEAD) / BAR)) < 0.01;
    void onBar;
  }
  return (
    <AbsoluteFill style={{ overflow: 'hidden' }}>
      {/* The first 62 s of the track, faded out over the last 1.2 s. */}
      <Audio src={staticFile('music.mp3')} volume={(f) => clamp((END - f / FPS) / 1.2)} />
      <Backdrop T={T} />
      
      <AbsoluteFill style={{ transform: camera(T, width), perspective: 2000 }}>
        {SCENES.map(([a, b, C], i) => {
          if (T < a - WHIP || T >= b + WHIP) return null;
          const t = T - a;
          const d = b - a;
          // Whip pans: each scene flies in from the right with a motion blur
          // and leaves to the left, overlapping its neighbours by WHIP.
          const dir = i % 2 ? -1 : 1;
          const inU = i === 0 ? 1 : clamp((t + WHIP) / (2 * WHIP));
          const outU = i === SCENES.length - 1 ? 0 : clamp((t - d + WHIP) / (2 * WHIP));
          const sIn = spring({ frame: Math.max(0, (t + WHIP) * FPS), fps: FPS, config: { damping: 14, stiffness: 160, mass: 0.6 } });
          const x = 0 * dir;
          const blur = (1 - inU) * 10;
          const zoom = lerp(1.06, 1, sIn) + 0.02 * clamp(t / d);
          const tilt = 0;
          return (
            <AbsoluteFill key={i} style={{ opacity: clamp(inU * 2.5) * (1 - clamp(outU * 2 - 1)), transform: `translateX(${x}px) scale(${zoom}) rotateY(${tilt}deg)`, filter: blur > 0.5 ? `blur(${blur}px)` : undefined }}>
              <C t={clamp(t, 0, d - 1e-3)} d={d} T={T} />
            </AbsoluteFill>
          );
        })}
      </AbsoluteFill>
      <AbsoluteFill style={{ background: 'black', opacity: flash, pointerEvents: 'none' }} />
      {T < 0.5 && <AbsoluteFill style={{ background: 'black', opacity: 1 - T / 0.5 }} />}
    </AbsoluteFill>
  );
};

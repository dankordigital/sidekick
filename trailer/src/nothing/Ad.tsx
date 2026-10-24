import React from 'react';
import { AbsoluteFill, Audio, Sequence, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import { END, FPS, STABS, b, back, clamp, easeOut, prog, pulse } from './beat';
import { DotLogo, DotText, GREEN, GREY, INK, Label, MONO, PAPER, RED, fitDot } from './dots';
import { Stage } from './stage';

/**
 * Sidekick's Nothing-style ad (42 s, on "Funky Funky Music"): the app's
 * Nothing look on a silver iPhone 17 Pro and a MacBook Pro, every scene on
 * the beat. One timeline for both shapes (9:16 and 16:9).
 */
export const NothingAd: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const v = height > width;
  const t = frame / FPS;
  return (
    <AbsoluteFill style={{ background: INK, overflow: 'hidden' }}>
      <Grid t={t} v={v} />
      <Stage t={t} v={v} />
      <Titles t={t} v={v} w={width} h={height} />
      <Hud t={t} v={v} w={width} h={height} />
      <Audio src={staticFile('nothing/music.mp3')} volume={(f) => clamp((END - f / FPS) / 0.6) * (1 - 0.4 * duck(f / FPS))} />
      {SFX.map(([at, src, volume, dur]) => (
        <Sfx key={at} at={at} src={src} volume={volume} dur={dur} />
      ))}
    </AbsoluteFill>
  );
};

/** The app's own sounds, where they happen: [time, sound, volume, length]. */
const SFX: [number, string, number, number][] = [
  [b(18), 'request', 1, 1.6],
  [b(20), 'accept', 1, 1.3],
  [b(25.3), 'request', 1, 1.6],
  [b(27), 'accept', 1, 1.3],
  [b(56.2), 'ping', 0.7, b(60) - b(56.2)],
];

/** How much to dip the music for a sound (0..1): in fast, out slowly. */
const duck = (t: number) =>
  Math.max(0, ...SFX.map(([at, , , dur]) => clamp((t - at + 0.05) / 0.05) * clamp((at + Math.min(dur, 0.9) - t) / 0.35)));

const Sfx: React.FC<{ at: number; src: string; volume: number; dur?: number }> = ({ at, src, volume, dur = 2 }) => (
  <Sequence from={Math.round(at * FPS)} durationInFrames={Math.round(dur * FPS)}>
    <Audio src={staticFile(`nothing/sounds/${src}.mp3`)} volume={(f) => volume * clamp((dur - f / FPS) / 0.25)} />
  </Sequence>
);

/** The dot grid behind everything; it breathes with the beat once the groove starts. */
const Grid: React.FC<{ t: number; v: boolean }> = ({ t, v }) => {
  const gap = v ? 36 : 32;
  const beat = pulse(t, b(16), 7);
  return (
    <AbsoluteFill
      style={{
        backgroundImage: `radial-gradient(circle, rgba(240,240,236,${0.07 + 0.05 * beat}) 1.6px, transparent 2px)`,
        backgroundSize: `${gap}px ${gap}px`,
        backgroundPosition: `${gap / 2}px ${(gap / 2 - t * 6) % gap}px`,
      }}
    />
  );
};

type Scene = { at: number; until: number; label?: string; lines: string[]; sub?: string };

const SCENES: Scene[] = [
  { at: b(8.6), until: b(16), lines: ['ALL YOUR', 'DEVICES^.'], sub: 'ONE APP. CONNECTED.' },
  { at: b(16), until: b(24), label: '01 — SEND FILES', lines: ['PHONE', 'TO MAC^.'], sub: 'ONE TAP. FULL QUALITY.' },
  { at: b(24), until: b(32), label: '02 — BOTH WAYS', lines: ['MAC', 'TO PHONE^.'], sub: 'DOCS, PHOTOS, ANYTHING.' },
  { at: b(32), until: b(40), label: '03 — SCREENSHOTS', lines: ['SNAP^.', "IT'S ON", 'YOUR MAC.'], sub: 'AUTOMATICALLY.' },
  { at: b(40), until: b(48), label: '04 — BROWSE FILES', lines: ['YOUR MAC', 'IN YOUR', 'POCKET^.'] },
  { at: b(48), until: b(56), label: '05 — REMOTE', lines: ['PHONE =', 'TOUCHPAD^.'], sub: 'POINT. CLICK. TYPE.' },
  { at: b(56), until: b(60), label: '06 — PING', lines: ['LOST IT?', 'PING IT^.'], sub: 'RINGS UNTIL YOU FIND IT.' },
  { at: b(60), until: b(64), label: '07 — NO WI-FI', lines: ['NO WI-FI?', 'NO PROBLEM^.'], sub: 'DIRECT LINK. ENCRYPTED.' },
];

const Titles: React.FC<{ t: number; v: boolean; w: number; h: number }> = ({ t, v, w, h }) => {
  const x = v ? 80 : 110;
  const top = v ? 245 : 300;
  const width = v ? w - 160 : 660;
  return (
    <>
      <Hook t={t} v={v} w={w} h={h} />
      {SCENES.map((s) => {
        if (t < s.at - 0.1 || t > s.until + 0.2) return null;
        const dot = fitDot(s.lines, width, v ? 15 : 15);
        const out = s.until - 0.28;
        const lh = (s.lines.length * 7 + (s.lines.length - 1) * 3) * dot;
        const lu = easeOut(prog(t, s.at, 0.35)) * (1 - easeOut(prog(t, out, 0.2)));
        const su = easeOut(prog(t, s.at + 0.35, 0.35)) * (1 - easeOut(prog(t, out, 0.2)));
        return (
          <React.Fragment key={s.at}>
            {s.label ? (
              <Label size={v ? 24 : 19} color={PAPER} style={{ left: x, top: top - (v ? 52 : 44), opacity: lu, transform: `translateX(${(1 - lu) * -20}px)` }}>
                <span style={{ color: RED }}>●</span> {s.label}
              </Label>
            ) : null}
            <DotText t={t} lines={s.lines} dot={dot} start={s.at + 0.05} out={out} style={{ left: x, top }} />
            {s.sub ? (
              <Label size={v ? 26 : 21} style={{ left: x, top: top + lh + (v ? 26 : 22), opacity: su, transform: `translateY(${(1 - su) * 12}px)` }}>
                {s.sub}
              </Label>
            ) : null}
          </React.Fragment>
        );
      })}
      <Chips t={t} v={v} x={x} y={top + (2 * 7 + 3) * fitDot(SCENES[0].lines, width, 15) + (v ? 90 : 76)} />
      <Platforms t={t} v={v} w={w} h={h} />
      <EndCard t={t} v={v} w={w} h={h} />
    </>
  );
};

/** The opening: PHONE + COMPUTER = ONE, then the logo. */
const Hook: React.FC<{ t: number; v: boolean; w: number; h: number }> = ({ t, v, w, h }) => {
  if (t > b(68)) return null;
  const lines = ['PHONE', '+ COMPUTER', '= ONE^.'];
  const dot = fitDot(lines, v ? w - 140 : 1100, v ? 17 : 22);
  const tw = Math.max(...lines.map((l) => l.replace('^', '').length)) * 6 * dot - dot;
  const th = (3 * 7 + 2 * 4) * dot;
  const out = b(6) - 0.15;
  const logoH = v ? 190 : 170;
  // At b(8) the logo shrinks into the corner, where it stays.
  const m = easeOut(prog(t, b(8), 0.5));
  const lx = (w - (logoH / 7) * 12) / 2;
  const ly = (h - logoH) / 2 - (v ? 60 : 40);
  const hx = v ? 80 : 110;
  const hy = v ? 130 : 66;
  const hh = v ? 40 : 34;
  const s = 1 + (hh / logoH - 1) * m;
  return (
    <>
      {t < b(7)
        ? [0, 1, 2].map((i) => (
        <DotText
          key={i}
          t={t}
          lines={[lines[i]]}
          dot={dot}
          start={[0.02, b(2), b(4)][i]}
          sweep={0.26}
          out={out}
          style={{ left: (w - tw) / 2, top: (h - th) / 2 + i * 11 * dot }}
        />
      ))
        : null}
      {t > b(6) - 0.2 ? (
        <>
          <DotLogo t={t} h={logoH} start={b(6) - 0.1} out={b(67.4)} style={{ left: 0, top: 0, transformOrigin: '0 0', transform: `translate(${lx + (hx - lx) * m}px, ${ly + (hy - ly) * m}px) scale(${s})` }} />
          <Label
            size={v ? 34 : 30}
            color={PAPER}
            style={{ left: 0, width: w, textAlign: 'center', top: ly + logoH + (v ? 60 : 44), letterSpacing: v ? 16 : 14, opacity: easeOut(prog(t, b(6.6), 0.3)) * (1 - m) }}
          >
            SIDEKICK
          </Label>
        </>
      ) : null}
    </>
  );
};

/** The four promises, one on each funky stab before the groove. */
const Chips: React.FC<{ t: number; v: boolean; x: number; y: number }> = ({ t, v, x, y }) => {
  const items: [string, string][] = [
    ['NO CABLE', PAPER],
    ['NO CLOUD', PAPER],
    ['NO ACCOUNT', PAPER],
    ['ENCRYPTED', GREEN],
  ];
  const out = b(15.6);
  if (t < STABS[0] - 0.1 || t > out + 0.4) return null;
  const size = v ? 22 : 18;
  return (
    <div style={{ position: 'absolute', left: x, top: y, width: v ? 940 : 640, display: 'flex', flexWrap: 'wrap', gap: v ? 14 : 12 }}>
      {items.map(([text, dot], i) => {
        const u = prog(t, STABS[i] - 0.03, 0.22);
        const o = easeOut(prog(t, out + i * 0.04, 0.2));
        return (
          <div
            key={text}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: size * 0.6,
              height: size * 2.3,
              padding: `0 ${size * 0.9}px`,
              borderRadius: size * 2,
              border: `${v ? 2 : 1.5}px solid rgba(240,240,236,.35)`,
              fontFamily: MONO,
              fontWeight: 500,
              fontSize: size,
              letterSpacing: size * 0.12,
              color: PAPER,
              opacity: u > 0 ? 1 - o : 0,
              transform: `scale(${u > 0 ? back(clamp(u), 2.2) : 0.6}) translateY(${o * -20}px)`,
              background: u > 0 && u < 0.6 ? 'rgba(240,240,236,.12)' : 'transparent',
            }}
          >
            <span style={{ width: size * 0.45, height: size * 0.45, borderRadius: '50%', background: dot === GREEN ? GREEN : RED }} />
            {text}
          </div>
        );
      })}
    </div>
  );
};

/** Works on: one word a beat. */
const Platforms: React.FC<{ t: number; v: boolean; w: number; h: number }> = ({ t, v, w, h }) => {
  if (t < b(64) - 0.1 || t > b(68) + 0.2) return null;
  const words = ['IPHONE', 'ANDROID', 'MAC', 'WINDOWS^.'];
  const dot = v ? 20 : 26;
  const i = Math.min(3, Math.floor((t - b(64)) / (b(65) - b(64))));
  const all = easeOut(prog(t, b(64), 0.25)) * (1 - easeOut(prog(t, b(68) - 0.2, 0.2)));
  return (
    <>
      <Label size={v ? 26 : 22} color={GREY} style={{ left: 0, width: w, textAlign: 'center', top: h / 2 - 7 * dot / 2 - (v ? 90 : 80), opacity: all }}>
        WORKS ON
      </Label>
      {words.map((word, k) => {
        if (k !== i) return null;
        const tw = word.replace('^', '').length * 6 * dot - dot;
        return <DotText key={k} t={t} lines={[word]} dot={dot} start={b(64 + k)} sweep={0.14} out={k === 3 ? b(68) - 0.25 : b(65 + k) - 0.08} style={{ left: (w - tw) / 2, top: h / 2 - (7 * dot) / 2 }} />;
      })}
      <div style={{ position: 'absolute', left: 0, width: w, top: h / 2 + 7 * dot / 2 + (v ? 70 : 60), display: 'flex', justifyContent: 'center', gap: v ? 26 : 30, opacity: all }}>
        {['iOS', 'Android', 'macOS', 'Windows'].map((p, k) => (
          <div key={p} style={{ fontFamily: MONO, fontSize: v ? 24 : 22, letterSpacing: 3, color: k <= i ? PAPER : '#3e3e3a', display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ width: 9, height: 9, borderRadius: '50%', background: k === i ? RED : k < i ? PAPER : '#3e3e3a' }} />
            {p.toUpperCase()}
          </div>
        ))}
      </div>
    </>
  );
};

/** The end: the logo, the name, the wishlist and the address. */
const EndCard: React.FC<{ t: number; v: boolean; w: number; h: number }> = ({ t, v, w, h }) => {
  const at = b(68);
  if (t < at - 0.1) return null;
  const logoH = v ? 210 : 180;
  const lw = (logoH / 7) * 12;
  const ly = v ? h / 2 - 340 : h / 2 - 290;
  const hit = b(73);
  const kick = t > hit ? Math.exp(-(t - hit) * 4) : 0;
  const url = 'GETSIDEKICK.APP';
  const ud = v ? 9 : 10;
  const uw = url.length * 6 * ud - ud;
  const pill = easeOut(prog(t, at + 1.0, 0.4));
  const fade = (d: number) => easeOut(prog(t, at + d, 0.4));
  return (
    <>
      <div style={{ position: 'absolute', left: (w - lw) / 2, top: ly, transform: `scale(${1 + kick * 0.06})`, transformOrigin: '50% 50%', width: lw, height: logoH }}>
        <DotLogo t={t} h={logoH} start={at} />
      </div>
      {kick > 0.02 ? (
        <div
          style={{
            position: 'absolute',
            left: (w - lw) / 2 + (11.5 / 12) * lw - (1 - kick) * 500,
            top: ly + (6.5 / 7) * logoH - (1 - kick) * 500,
            width: (1 - kick) * 1000,
            height: (1 - kick) * 1000,
            borderRadius: '50%',
            border: `${4 * kick}px solid ${RED}`,
            opacity: kick,
          }}
        />
      ) : null}
      <Label size={v ? 40 : 34} color={PAPER} style={{ left: 0, width: w, textAlign: 'center', top: ly + logoH + (v ? 56 : 40), letterSpacing: v ? 18 : 16, opacity: fade(0.35) }}>
        SIDEKICK
      </Label>
      <Label size={v ? 24 : 21} color={GREY} style={{ left: 0, width: w, textAlign: 'center', top: ly + logoH + (v ? 130 : 102), opacity: fade(0.6) }}>
        YOUR PHONE AND COMPUTER, AS ONE.
      </Label>
      <div
        style={{
          position: 'absolute',
          left: (w - (v ? 600 : 520)) / 2,
          top: ly + logoH + (v ? 230 : 180),
          width: v ? 600 : 520,
          height: v ? 104 : 86,
          borderRadius: 60,
          background: RED,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 18,
          fontFamily: 'Inter',
          fontWeight: 600,
          fontSize: v ? 38 : 32,
          color: '#fff',
          opacity: pill,
          transform: `scale(${(0.85 + 0.15 * back(pill)) * (1 + kick * 0.05)})`,
        }}
      >
        Join the wishlist
      </div>
      <DotText t={t} lines={[url]} dot={ud} start={at + 1.4} sweep={0.4} style={{ left: (w - uw) / 2, top: ly + logoH + (v ? 390 : 310) }} />
      <Label size={v ? 22 : 19} color={GREY} style={{ left: 0, width: w, textAlign: 'center', top: ly + logoH + (v ? 520 : 412), opacity: fade(1.8) }}>
        IPHONE · ANDROID · MAC · WINDOWS
      </Label>
    </>
  );
};

/** The corners: the logo (from the opening), the scene count, the time line. */
const Hud: React.FC<{ t: number; v: boolean; w: number; h: number }> = ({ t, v, w, h }) => {
  const on = easeOut(prog(t, b(8.4), 0.4)) * (1 - easeOut(prog(t, b(67.6), 0.3)));
  if (on <= 0) return null;
  const scene = t < b(16) ? 0 : t < b(24) ? 1 : t < b(32) ? 2 : t < b(40) ? 3 : t < b(48) ? 4 : t < b(56) ? 5 : t < b(60) ? 6 : 7;
  const blink = 0.35 + 0.65 * pulse(t, 0, 5);
  const pad = v ? 80 : 110;
  const top = v ? 136 : 70;
  const p = clamp((t - b(8)) / (b(68) - b(8)));
  return (
    <div style={{ position: 'absolute', inset: 0, opacity: on }}>
      <Label size={v ? 22 : 18} color={PAPER} style={{ right: pad, top: top + 6, display: 'flex', alignItems: 'center', gap: 12, opacity: easeOut(prog(t, b(16), 0.3)) }}>
        <span style={{ width: 11, height: 11, borderRadius: '50%', background: RED, opacity: blink }} />
        {String(scene).padStart(2, '0')} / 07
      </Label>
      <div style={{ position: 'absolute', left: pad, right: pad, bottom: v ? 70 : 40, height: 2, background: '#242422' }}>
        <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${p * 100}%`, background: PAPER }} />
        <div style={{ position: 'absolute', left: `calc(${p * 100}% - 5px)`, top: -4, width: 10, height: 10, borderRadius: '50%', background: RED }} />
      </div>
    </div>
  );
};

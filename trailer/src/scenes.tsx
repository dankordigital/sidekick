import React from 'react';
import { Img, staticFile, useVideoConfig } from 'remotion';
import { BAR, BEAT, back, clamp, easeIn, easeInOut, easeOut, lerp, prog, pulse } from './beat';
import { Fill, GREEN, Headline, HI, INK, Icon, Mac, Phone, Pill, Ring, SkTile, VIOLET, Window, Word, appear, useO, useVertical } from './ui';

export type SceneProps = { t: number; d: number; T: number };

const ICON = {
  send: 0xf0147, check: 0xf636, paste: 0xf66f, mouse: 0xf8e3, cast: 0xf622, qr: 0xf00cb, wifi: 0xf02bf,
  lock: 0xf889, devices: 0xf6a8, folder: 0xf77e, touch: 0xf0245, bell: 0xf0026, laptop: 0xf841,
  windows: 0xf69f, iphone: 0xf007f, android: 0xf0078, bluetooth: 0xf5c4, keyboard: 0xf833,
  photos: 0xf008f, palette: 0xf0041, cloudOff: 0xf64e, noAccount: 0xf0009, block: 0xf5be,
  heart: 0xf738, copy: 0xf66c, link: 0xf85a, image: 0xf80d, verified: 0xf026f, done: 0xf6dd,
};

/** Headline placement for the orientation. */
const useHead = () => {
  const O = useO();
  return { y: O(64, 250), size: O(96, 100) };
};

const Title: React.FC<{ t: number; d: number; lines: Word[][]; start?: number }> = ({ t, d, lines, start = 0.05 }) => {
  const h = useHead();
  return <Headline t={t} lines={lines} size={h.size} y={h.y} start={start} out={d - 0.26} />;
};

/** The two devices' places for a scene with both. */
const useSlots = () => {
  const O = useO();
  return {
    phone: { w: O(300, 270), x: O(330, 720), y: O(330, 940) },
    mac: { w: O(900, 820), x: O(760, 72), y: O(330, 560) },
  };
};

/** Rises in from below at t0 (a spring-ish ease), with an optional bob. */
const rise = (t: number, t0: number, dist = 400) => {
  const u = prog(t, t0, 0.65);
  return { y: lerp(dist, 0, back(u, 1.2)), a: clamp(u * 3) };
};

// ------------------------------------------------------------------ intro

export const Intro: React.FC<SceneProps> = ({ t }) => {
  const { width, height } = useVideoConfig();
  const g = easeInOut(prog(t, 0.2, 1.6));
  return (
    <div
      style={{
        position: 'absolute',
        left: width / 2 - 200,
        top: height / 2 - 200,
        width: 400,
        height: 400,
        borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(190,160,255,.9), rgba(120,80,255,.25) 35%, transparent 70%)',
        transform: `scale(${lerp(0.05, 1, g)})`,
        opacity: g,
      }}
    />
  );
};

export const YourDevices: React.FC<SceneProps> = ({ t, d }) => {
  const O = useO();
  const s = useSlots();
  const p = rise(t, 0.1);
  const m = rise(t, BAR, 300);
  return (
    <>
      <Headline t={t} lines={[[['Your', 'w'], ['phone.', 'hi']]]} size={useHead().size} y={useHead().y} start={0.05} out={BAR - 0.25} />
      <Headline t={t} lines={[[['Your', 'w'], ['computer.', 'hi']]]} size={useHead().size} y={useHead().y} start={BAR + 0.05} out={d - 0.25} />
      <div style={{ opacity: m.a, transform: `translateY(${m.y}px)` }}>
        <Mac w={s.mac.w} style={{ left: s.mac.x, top: s.mac.y }}>
          <Fill src="shots/mac-devices.png" />
        </Mac>
      </div>
      <div style={{ opacity: p.a, transform: `translateY(${p.y}px) rotate(${lerp(-8, -3, prog(t, 0, d))}deg)` }}>
        <Phone w={s.phone.w} style={{ left: s.phone.x + O(0, 0), top: s.phone.y }}>
          <Fill src="shots/iphone-devices.png" />
        </Phone>
      </div>
    </>
  );
};

export const MeetSidekick: React.FC<SceneProps> = ({ t, d }) => {
  const { width, height } = useVideoConfig();
  const O = useO();
  const v = prog(t, 0.05, 0.7);
  const size = O(300, 340);
  const cx = width / 2, cy = height / 2 - O(40, 80);
  return (
    <>
      <Headline t={t} lines={[[['One', 'w'], ['app.', 'hi']]]} size={useHead().size} y={useHead().y} start={0.05} out={BAR - 0.2} />
      {[0, 1, 2, 3].map((k) => (
        <Ring key={k} t={t} t0={k * BEAT} x={cx} y={cy} r0={size * 0.4} r1={size * 1.6} dur={0.9} />
      ))}
      <div style={{ transform: `scale(${lerp(0.2, 1, back(v))}) rotate(${lerp(-25, 0, easeOut(v))}deg)`, opacity: clamp(v * 3), position: 'absolute', left: cx - size / 2, top: cy - size / 2, width: size, height: size }}>
        <SkTile size={size} />
      </div>
      <Headline t={t} lines={[[['Meet', 'w'], ['Sidekick.', 'hi']]]} size={O(110, 112)} y={cy + size / 2 + O(40, 60)} start={BAR + 0.05} out={d - 0.25} />
    </>
  );
};

// ------------------------------------------------------------------ features

const seq = (dir: string, n: number, i: number) => `seq/${dir}/${String(Math.max(0, Math.min(n - 1, Math.floor(i)))).padStart(3, '0')}.jpg`;

export const SendFiles: React.FC<SceneProps> = ({ t, d }) => {
  const s = useSlots();
  const O = useO();
  const u = clamp(t / d);
  // The phone sends (141 frames), the Mac asks and receives (116 frames).
  const pf = seq('send', 141, u * 141);
  const mf = seq('receive', 116, u * 116);
  const p = rise(t, 0, 300);
  return (
    <>
      <Title t={t} d={d} lines={[[['Send', 'w'], ['anything.', 'hi']], [['Both ways.', 'w']]]} />
      <div style={{ opacity: p.a, transform: `translateY(${p.y * 0.5}px)` }}>
        <Mac w={s.mac.w} style={{ left: s.mac.x, top: s.mac.y }}>
          <Img src={staticFile(mf)} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
        </Mac>
        <Phone w={s.phone.w} style={{ left: s.phone.x, top: s.phone.y }}>
          <Img src={staticFile(pf)} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
        </Phone>
      </div>
      {['IMG_2041.HEIC', 'Trip.mov', 'Notes.pdf'].map((name, k) => {
        const v = prog(t, 0.55 + k * 0.12, 0.8);
        if (v <= 0 || v >= 1) return null;
        const e = easeInOut(v);
        const x0 = s.phone.x + s.phone.w / 2, y0 = s.phone.y + O(300, 260);
        const x1 = s.mac.x + s.mac.w * 0.6, y1 = s.mac.y + s.mac.w * 0.3;
        const x = (1 - e) ** 2 * x0 + 2 * (1 - e) * e * ((x0 + x1) / 2) + e * e * x1;
        const y = (1 - e) ** 2 * y0 + 2 * (1 - e) * e * (Math.min(y0, y1) - 200) + e * e * y1;
        return (
          <div key={name} style={{ position: 'absolute', left: x, top: y + k * 18, transform: `translate(-50%,-50%) scale(${lerp(1, 0.6, e)})`, opacity: clamp((1 - v) * 6) }}>
            <Pill icon={k === 1 ? 0xf8e7 : k === 2 ? 0xf69b : ICON.image} text={name} size={26} />
          </div>
        );
      })}
    </>
  );
};

/** A Mac notification banner (top right of its screen), sliding in. */
const Banner: React.FC<{ w: number; u: number; app: string; color: string; icon: number; title: string; text: string; style?: React.CSSProperties }> = ({ w, u, app, color, icon, title, text, style }) => (
  <div style={{ position: 'absolute', width: w, borderRadius: w * 0.06, background: 'rgba(246,244,250,.93)', boxShadow: '0 12px 40px rgba(0,0,0,.35)', padding: w * 0.04, display: 'flex', gap: w * 0.035, alignItems: 'center', fontFamily: 'Inter', color: INK, opacity: clamp(u * 3), transform: `translateX(${lerp(w * 0.6, 0, easeOut(u))}px)`, ...style }}>
    <div style={{ width: w * 0.12, height: w * 0.12, borderRadius: w * 0.03, background: color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
      <Icon code={icon} size={w * 0.075} color="white" />
    </div>
    <div style={{ minWidth: 0, flex: 1 }}>
      <div style={{ fontSize: w * 0.036, fontWeight: 600, opacity: 0.55 }}>{app}</div>
      <div style={{ fontSize: w * 0.045, fontWeight: 600 }}>{title}</div>
      <div style={{ fontSize: w * 0.04, fontWeight: 500, opacity: 0.75, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{text}</div>
    </div>
  </div>
);

export const Screenshots: React.FC<SceneProps> = ({ t, d }) => {
  const s = useSlots();
  const O = useO();
  const flash = t > 0.2 ? Math.exp(-(t - 0.2) * 9) : 0;
  const v = easeInOut(prog(t, 0.35, 0.6));
  const pw = s.phone.w * 0.874;
  const x0 = s.phone.x + s.phone.w / 2, y0 = s.phone.y + s.phone.w * 1.08;
  const x1 = s.mac.x + s.mac.w * 0.72, y1 = s.mac.y + s.mac.w * 0.16;
  const sc = lerp(1, 0.22, v);
  const bw = s.mac.w * 0.36;
  return (
    <>
      <Title t={t} d={d} lines={[[['Screenshot.', 'w']], [["It's on your computer.", 'hi']]]} />
      <Mac w={s.mac.w} style={{ left: s.mac.x, top: s.mac.y }}>
        <Fill src="shots/mac-devices.png" />
        <Banner w={bw} u={prog(t, 0.95, 0.4)} app="SIDEKICK" color="linear-gradient(135deg,#7b5cff,#c04fd8)" icon={0xe562} title="Screenshot from iPhone" text="Saved to Downloads/Sidekick" style={{ right: s.mac.w * 0.025, top: s.mac.w * 0.025 }} />
      </Mac>
      <Phone w={s.phone.w} style={{ left: s.phone.x, top: s.phone.y }}>
        <Fill src="shots/iphone-devices.png" />
        <div style={{ position: 'absolute', inset: 0, background: 'white', opacity: flash }} />
      </Phone>
      {t > 0.3 && v < 1 && (
        <div style={{ position: 'absolute', left: lerp(x0, x1, v), top: lerp(y0, y1, v) - Math.sin(Math.PI * v) * 160, width: pw, height: pw * 2.17, transform: `translate(-50%,-50%) scale(${sc})`, borderRadius: 30, overflow: 'hidden', border: '6px solid white', boxShadow: '0 20px 60px rgba(0,0,0,.5)' }}>
          <Img src={staticFile('shots/iphone-devices.png')} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        </div>
      )}
      {t > 0.95 && <Ring t={t} t0={0.95} x={x1} y={y1} color={GREEN} r1={240} />}
    </>
  );
};

export const Touchpad: React.FC<SceneProps> = ({ t, d }) => {
  const s = useSlots();
  const O = useO();
  // The phone on the right, the Mac on the left, for this one.
  const px = O(1450, 720), py = O(330, 940);
  const mx = O(170, 72), my = O(330, 560);
  const path = (g: number) => [Math.sin(g * 3), Math.sin(g * 6)];
  const dots = [];
  for (let k = 14; k >= 0; k--) {
    const g = Math.max(0, t - 0.25 - k * 0.025);
    const [a, b] = path(g);
    const f = (1 - k / 15) * clamp((t - 0.25) * 4);
    dots.push(
      <React.Fragment key={k}>
        <div style={{ position: 'absolute', left: px + s.phone.w / 2 + a * s.phone.w * 0.3 - 9, top: py + s.phone.w * 1.35 + b * s.phone.w * 0.2 - 9, width: 18, height: 18, borderRadius: 9, background: VIOLET, opacity: f * 0.8, boxShadow: `0 0 20px ${VIOLET}` }} />
        <div style={{ position: 'absolute', left: mx + s.mac.w * 0.58 + a * s.mac.w * 0.3 - 6, top: my + s.mac.w * 0.32 + b * s.mac.w * 0.14 - 6, width: 12, height: 12, borderRadius: 6, background: VIOLET, opacity: f * 0.7 }} />
      </React.Fragment>,
    );
  }
  const [a, b] = path(Math.max(0, t - 0.25));
  return (
    <>
      <Title t={t} d={d} lines={[[['Your phone.', 'w']], [['A touchpad.', 'hi']]]} />
      <Mac w={s.mac.w} style={{ left: mx, top: my }}>
        <Fill src="shots/mac-devices.png" />
      </Mac>
      <Phone w={s.phone.w} style={{ left: px, top: py }}>
        <Fill src="shots/iphone-remote.png" />
      </Phone>
      {dots}
      <svg style={{ position: 'absolute', left: mx + s.mac.w * 0.58 + a * s.mac.w * 0.3, top: my + s.mac.w * 0.32 + b * s.mac.w * 0.14 }} width="34" height="46" viewBox="0 0 34 46">
        <path d="M4 2 L4 36 L12 28 L18 42 L23 40 L17 26 L28 26 Z" fill="black" stroke="white" strokeWidth="2.5" />
      </svg>
    </>
  );
};

export const Keyboard: React.FC<SceneProps> = ({ t, d, T }) => {
  const { width } = useVideoConfig();
  const O = useO();
  const keys = [['⌘', 'C'], ['⌘', 'V'], ['⌘', 'Tab']];
  const k = Math.min(2, Math.floor(t / BEAT / 1.3));
  const press = pulse(T, BEAT, 10);
  return (
    <>
      <Title t={t} d={d} lines={[[['Keyboard.', 'w'], ['Shortcuts.', 'hi']]]} />
      <div style={{ opacity: appear(t, 0, 0.4), transform: `translateY(${lerp(80, 0, appear(t, 0, 0.5))}px) rotate(-4deg)` }}>
        <Phone w={O(300, 330)} style={{ left: O(width / 2 - 520, width / 2 - 165), top: O(260, 520) }}>
          <Fill src="shots/iphone-remote.png" />
        </Phone>
      </div>
      <div style={{ position: 'absolute', left: O(width / 2 - 120, 0), width: O(760, width), top: O(520, 1300), display: 'flex', justifyContent: 'center', gap: 22 }}>
        {keys[k].map((key) => (
          <div
            key={key + k}
            style={{
              minWidth: 120,
              height: 120,
              padding: '0 30px',
              borderRadius: 26,
              background: 'linear-gradient(180deg,#ffffff,#e6defa)',
              boxShadow: `0 ${14 - 10 * press}px 0 #9d8bd6, 0 30px 60px rgba(0,0,0,.4)`,
              transform: `translateY(${10 * press}px)`,
              display: 'grid',
              placeItems: 'center',
              fontFamily: 'InterDisplay',
              fontWeight: 900,
              fontSize: 56,
              color: INK,
            }}
          >
            {key}
          </div>
        ))}
      </div>
    </>
  );
};

export const Files: React.FC<SceneProps> = ({ t, d }) => {
  const { width } = useVideoConfig();
  const O = useO();
  const w = O(1060, 980);
  const z = lerp(1.0, 1.06, prog(t, 0, d));
  return (
    <>
      <Title t={t} d={d} lines={[[['Browse files.', 'w']], [['On any device.', 'hi']]]} />
      <div style={{ opacity: appear(t, 0, 0.4), transform: `translateY(${lerp(80, 0, appear(t, 0, 0.5))}px) scale(${z})`, transformOrigin: 'center top' }}>
        <Window src="shots/2b-files-folder.png" w={w} style={{ left: (width - w) / 2, top: O(260, 600) }} />
      </div>
    </>
  );
};

export const Ping: React.FC<SceneProps> = ({ t, d, T }) => {
  const { width, height } = useVideoConfig();
  const O = useO();
  const w = O(330, 360);
  const x = width / 2 - w / 2, y = O(260, 560);
  const shake = Math.sin(t * 70) * 6 * pulse(T, BEAT / 2, 6);
  const cx = width / 2, cy = y + w * O(1.2, 1.08);
  const rings = [];
  for (let k = 0.15; k < d; k += BEAT / 2) rings.push(<Ring key={k} t={t} t0={k} x={cx} y={cy} r0={w * 0.4} r1={w * 1.5} dur={0.8} />);
  return (
    <>
      <Title t={t} d={d} lines={[[['Lost it?', 'w'], ['Ping it.', 'hi']]]} />
      {rings}
      <div style={{ transform: `translateX(${shake}px) rotate(${shake * 0.6}deg)` }}>
        <Phone w={w} style={{ left: x, top: y }}>
          <Fill src="shots/ping.png" />
        </Phone>
      </div>
      <div style={{ position: 'absolute', left: cx, top: O(height - 120, 1500), transform: `translate(-50%,-50%) scale(${back(prog(t, 0.3, 0.4))})` }}>
        <Pill icon={ICON.bell} text="Rings until you find it" size={28} />
      </div>
    </>
  );
};

export const Corner: React.FC<SceneProps> = ({ t, d }) => {
  const { width, height } = useVideoConfig();
  const O = useO();
  const state = t < d * 0.4 ? 'corner_asking' : t < d * 0.75 ? 'corner_receiving' : 'corner_done';
  const w = O(700, 840);
  const u = appear(t, 0.05, 0.5);
  return (
    <>
      <Title t={t} d={d} lines={[[['Requests pop up', 'w']], [['in the corner.', 'hi']]]} />
      <div style={{ position: 'absolute', left: O(250, 60), top: O(250, 560), width: O(1420, 960), height: O(760, 900), borderRadius: 30, background: 'linear-gradient(135deg, rgba(255,255,255,.14), rgba(255,255,255,.04))', border: '1px solid rgba(255,255,255,.18)' }}>
        <div style={{ position: 'absolute', right: 30, bottom: 30, width: w, transform: `translateY(${lerp(120, 0, u)}px)`, opacity: u }}>
          <Img src={staticFile(`shots/${state}.png`)} style={{ width: '100%', borderRadius: 24, boxShadow: '0 30px 80px rgba(0,0,0,.5)' }} />
        </div>
      </div>
      {state === 'corner_done' && <Ring t={t} t0={d * 0.75} x={O(250 + 1420 - 30 - w / 2, 60 + 960 - 30 - w / 2)} y={O(250 + 760 - 30 - w * 0.226, 560 + 900 - 30 - w * 0.226)} color={GREEN} r1={300} />}
    </>
  );
};

export const Tray: React.FC<SceneProps> = ({ t, d, T }) => {
  const { width } = useVideoConfig();
  const O = useO();
  const w = O(380, 470);
  const u = appear(t, 0.05, 0.5);
  return (
    <>
      <Title t={t} d={d} lines={[[['Always', 'w']], [['one click away.', 'hi']]]} />
      <div style={{ position: 'absolute', left: 0, top: O(260, 560), width, height: 54, background: 'rgba(255,255,255,.14)', backdropFilter: 'blur(10px)', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 26, paddingRight: O(260, 80), color: 'white', fontFamily: 'Inter', fontWeight: 600, fontSize: 24 }}>
        <Icon code={ICON.wifi} size={28} />
        <div style={{ width: 34, height: 34, borderRadius: 9, background: 'white', display: 'grid', placeItems: 'center', boxShadow: `0 0 ${30 * pulse(T, BEAT, 4)}px ${VIOLET}` }}>
          <Img src={staticFile('shots/sk-icon.png')} style={{ width: 30, borderRadius: 7 }} />
        </div>
        <span>Tue 9:41</span>
      </div>
      <div style={{ position: 'absolute', right: O(220, (width - w) / 2), top: O(330, 640), width: w, opacity: u, transform: `translateY(${lerp(-40, 0, u)}px) scale(${lerp(0.94, 1, u)})`, transformOrigin: 'top right' }}>
        <Img src={staticFile('shots/tray-panel.png')} style={{ width: '100%', borderRadius: 28, boxShadow: '0 40px 100px rgba(0,0,0,.55)' }} />
      </div>
    </>
  );
};

export const QrPair: React.FC<SceneProps> = ({ t, d }) => {
  const s = useSlots();
  const O = useO();
  const paired = t > d * 0.62;
  return (
    <>
      <Title t={t} d={d} lines={[[['Pair in', 'w']], [['one scan.', 'hi']]]} />
      <Mac w={s.mac.w} style={{ left: O(170, 72), top: s.mac.y }}>
        <Fill src="shots/ad-mac-qr.png" />
      </Mac>
      <div style={{ transform: `rotate(${lerp(-10, -4, prog(t, 0, d))}deg)` }}>
        <Phone w={s.phone.w} style={{ left: O(1450, 720), top: s.phone.y }}>
          <Fill src="shots/ad-iphone-scan.png" />
        </Phone>
      </div>
      {paired && (
        <div style={{ position: 'absolute', left: O(170, 72) + s.mac.w * 0.6, top: s.mac.y + s.mac.w * 0.3, transform: `translate(-50%,-50%) scale(${back(prog(t, d * 0.62, 0.35))})` }}>
          <Pill icon={ICON.check} text="Paired" size={40} />
        </div>
      )}
    </>
  );
};

const Arc: React.FC<{ t: number; x0: number; x1: number; y: number; icon: number; label: string; color?: string }> = ({ t, x0, x1, y, icon, label, color = VIOLET }) => {
  const dots = [];
  for (let i = 0; i < 22; i++) {
    const q = ((i + (t / BEAT) * 2) % 22) / 22;
    const x = lerp(x0, x1, q);
    const yy = y - Math.sin(Math.PI * q) * 160;
    dots.push(<div key={i} style={{ position: 'absolute', left: x - 6, top: yy - 6, width: 12, height: 12, borderRadius: 6, background: '#e6dcff', opacity: Math.sin(Math.PI * q) * clamp(t * 3), boxShadow: `0 0 14px ${color}` }} />);
  }
  const mid = (x0 + x1) / 2;
  return (
    <>
      {dots}
      <div style={{ position: 'absolute', left: mid - 70, top: y - 160 - 160, width: 140, height: 140, borderRadius: 36, background: 'linear-gradient(180deg,#fff,#e2d8ff)', display: 'grid', placeItems: 'center', transform: `scale(${back(prog(t, 0.15, 0.5))})`, boxShadow: `0 20px 60px rgba(120,80,255,.5)` }}>
        <Icon code={icon} size={84} color="#6a4cff" />
      </div>
      <div style={{ position: 'absolute', left: mid - 300, width: 600, top: y - 140, textAlign: 'center', color: 'white', fontFamily: 'Inter', fontWeight: 600, fontSize: 30, opacity: prog(t, 0.4, 0.3) }}>
        {label}
      </div>
    </>
  );
};

const DeviceTile: React.FC<{ icon: number; x: number; y: number; size: number; t: number; t0: number; label?: string }> = ({ icon, x, y, size, t, t0, label }) => (
  <div style={{ position: 'absolute', left: x - size / 2, top: y - size / 2, width: size, transform: `scale(${back(prog(t, t0, 0.5))})`, opacity: clamp(prog(t, t0, 0.2) * 3) }}>
    <div style={{ width: size, height: size, borderRadius: size * 0.24, background: 'linear-gradient(160deg, rgba(255,255,255,.95), rgba(214,200,255,.9))', display: 'grid', placeItems: 'center', boxShadow: '0 30px 70px rgba(80,40,200,.5)' }}>
      <Icon code={icon} size={size * 0.56} color="#5b3df0" />
    </div>
    {label && <div style={{ marginTop: 18, textAlign: 'center', color: 'white', fontFamily: 'InterDisplay', fontWeight: 800, fontSize: size * 0.2 }}>{label}</div>}
  </div>
);

export const DirectWifi: React.FC<SceneProps> = ({ t, d }) => {
  const { width } = useVideoConfig();
  const O = useO();
  const y = O(720, 1150);
  const x0 = O(560, 250), x1 = O(1360, 830);
  return (
    <>
      <Title t={t} d={d} lines={[[['No router?', 'w']], [['Direct Wi-Fi.', 'hi']]]} />
      <DeviceTile icon={ICON.android} x={x0} y={y} size={O(200, 210)} t={t} t0={0} label="Phone" />
      <DeviceTile icon={ICON.windows} x={x1} y={y} size={O(200, 210)} t={t} t0={0.08} label="PC" />
      <Arc t={t} x0={x0 + 110} x1={x1 - 110} y={y} icon={ICON.wifi} label="Its own private network" />
      <div style={{ position: 'absolute', left: 0, width, top: O(960, 1420), textAlign: 'center' }} />
    </>
  );
};

export const Bluetooth: React.FC<SceneProps> = ({ t, d }) => {
  const O = useO();
  const y = O(720, 1150);
  const x0 = O(560, 250), x1 = O(1360, 830);
  // The riser: everything quickens toward the hit.
  const z = 1 + 0.06 * easeIn(prog(t, 0, d));
  return (
    <div style={{ position: 'absolute', inset: 0, transform: `scale(${z})` }}>
      <Title t={t} d={d} lines={[[['No Wi-Fi at all?', 'w']], [['Bluetooth.', 'hi']]]} />
      <DeviceTile icon={ICON.iphone} x={x0} y={y} size={O(200, 210)} t={t} t0={0} label="iPhone" />
      <DeviceTile icon={ICON.laptop} x={x1} y={y} size={O(200, 210)} t={t} t0={0.08} label="Mac" />
      <Arc t={t * 1.8} x0={x0 + 110} x1={x1 - 110} y={y} icon={ICON.bluetooth} label="Finds each other anywhere" />
    </div>
  );
};

// ------------------------------------------------------------------ the breakdown and the drop

export const OneMoreThing: React.FC<SceneProps> = ({ t, d }) => {
  const { height } = useVideoConfig();
  const O = useO();
  return <Headline t={t} lines={[[['One more', 'w'], ['thing…', 'hi']]]} size={O(110, 104)} y={height / 2 - 70} start={0.75} out={d - 0.3} />;
};

const NOTES: [string, string, number, string, string][] = [
  ['MESSAGES', '#34c759', 0xe154, 'Mom', 'Dinner at 7? Bring the charger 🙂'],
  ['WHATSAPP', '#25d366', 0xe154, 'Alex', 'Sent you the photos from today'],
  ['GMAIL', '#ea4335', 0xe3c3, 'Your order has shipped', 'Arriving tomorrow by 9 pm'],
  ['CALENDAR', '#4285f4', 0xe450, 'Stand-up in 5 minutes', 'Room 3 · Join call'],
];

export const PhoneNotifications: React.FC<SceneProps> = ({ t, d }) => {
  const { width, height } = useVideoConfig();
  const O = useO();
  // First the name, huge, on the drop; then the Mac filling with banners.
  const titleOut = BAR * 0.9;
  const big = prog(t, 0, 0.5);
  const dev = rise(t, BAR * 0.75, 250);
  const macW = O(1080, 900);
  const macX = (width - macW * O(1.16, 1)) / 2 + O(0, 0), macY = O(290, 600);
  const bw = macW * 0.4;
  const captions: [number, Word[][]][] = [
    [BAR * 0.75, [[['Your phone,', 'w'], ['on your computer.', 'hi']]]],
    [BAR * 1.75, [[['Never miss', 'w'], ['a thing.', 'hi']]]],
  ];
  return (
    <>
      {t < titleOut + 0.3 && (
        <div style={{ position: 'absolute', left: 0, width, top: height / 2 - O(110, 170), textAlign: 'center', opacity: 1 - prog(t, titleOut, 0.3), transform: `scale(${lerp(1.25, 1, easeOut(big)) + 0.08 * prog(t, 0, titleOut)})` }}>
          <div style={{ fontFamily: 'InterDisplay', fontWeight: 900, fontSize: O(150, 130), lineHeight: 1.02, letterSpacing: -5, background: HI, WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent', filter: 'drop-shadow(0 10px 40px rgba(255,120,190,.5))' }}>
            Phone
            {V_BREAK(O)}
            notifications
          </div>
          <div style={{ marginTop: 30, color: 'white', fontFamily: 'Inter', fontWeight: 600, fontSize: O(38, 40), opacity: prog(t, 0.25, 0.3) }}>On your Mac or PC · New in Sidekick 2.15</div>
        </div>
      )}
      {captions.map(([t0, lines], i) => (
        <Headline key={i} t={t} lines={lines} size={useHead().size} y={useHead().y} start={t0} out={i === 0 ? captions[1][0] - 0.25 : d - 0.25} />
      ))}
      <div style={{ opacity: dev.a, transform: `translateY(${dev.y}px)` }}>
        <Mac w={macW} style={{ left: macX, top: macY }}>
          <Fill src="shots/mac-devices.png" />
          {NOTES.map(([app, color, icon, title, text], i) => {
            const t0 = BAR * 1.0 + i * 2 * BEAT;
            const u = prog(t, t0, 0.45);
            // Newer banners push the older ones down.
            const below = NOTES.filter((_, j) => j > i && t > BAR + j * 2 * BEAT).length;
            const shift = NOTES.reduce((acc, _, j) => acc + (j > i ? easeOut(prog(t, BAR + j * 2 * BEAT, 0.35)) : 0), 0);
            void below;
            return u > 0 ? <Banner key={app} w={bw} u={u} app={app} color={color} icon={icon} title={title} text={text} style={{ right: macW * 0.02, top: macW * 0.02 + shift * bw * 0.27 }} /> : null;
          })}
        </Mac>
      </div>
    </>
  );
};
const V_BREAK = (O: <T>(h: T, v: T) => T) => O<React.ReactNode>(' ', <br />);

export const LiveActivity: React.FC<SceneProps> = ({ t, d }) => {
  const { width } = useVideoConfig();
  const O = useO();
  const w = O(360, 400);
  const x = width / 2 - w / 2, y = O(250, 560);
  const p = clamp((t - 0.3) / (d - 0.6));
  return (
    <>
      <Title t={t} d={d} lines={[[['On your', 'w']], [['Lock Screen.', 'hi']]]} />
      <Phone w={w} style={{ left: x, top: y }}>
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg,#3b2a8a,#c2569e 70%,#f39a6b)' }} />
        <div style={{ position: 'absolute', top: '12%', width: '100%', textAlign: 'center', color: 'white', fontFamily: 'InterDisplay', fontWeight: 700, fontSize: w * 0.22, letterSpacing: -2 }}>9:41</div>
        <div style={{ position: 'absolute', left: '5%', right: '5%', top: '55%', borderRadius: w * 0.07, background: 'rgba(20,14,30,.75)', backdropFilter: 'blur(14px)', padding: w * 0.05, color: 'white', fontFamily: 'Inter', fontWeight: 600, fontSize: w * 0.045 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: w * 0.03 }}>
            <Img src={staticFile('shots/sk-icon.png')} style={{ width: w * 0.09, borderRadius: w * 0.02 }} />
            <div style={{ flex: 1 }}>Receiving from MacBook Pro</div>
            <div>{Math.round(p * 100)}%</div>
          </div>
          <div style={{ marginTop: w * 0.035, height: w * 0.022, borderRadius: w, background: 'rgba(255,255,255,.2)' }}>
            <div style={{ width: `${p * 100}%`, height: '100%', borderRadius: w, background: p >= 1 ? GREEN : 'linear-gradient(90deg,#9b7bff,#ff7ac6)' }} />
          </div>
          <div style={{ marginTop: w * 0.025, opacity: 0.7, fontSize: w * 0.038 }}>{p >= 1 ? 'Received · 12 photos' : 'IMG_2041.HEIC and 11 more'}</div>
        </div>
      </Phone>
    </>
  );
};

export const Gallery: React.FC<SceneProps> = ({ t, d }) => {
  const { width } = useVideoConfig();
  const O = useO();
  const w = O(330, 380);
  const x = width / 2 - w / 2, y = O(250, 560);
  const v = prog(t, 0.15, 0.7);
  return (
    <>
      <Title t={t} d={d} lines={[[['Photos land in', 'w']], [['your gallery.', 'hi']]]} />
      <Phone w={w} style={{ left: x, top: y }}>
        <Img src={staticFile('shots/gallery.jpg')} style={{ width: '100%', transform: `translateY(${lerp(-60, 0, easeOut(v))}px)` }} />
      </Phone>
      <div style={{ position: 'absolute', left: x + w * 0.18, top: lerp(y - 300, y + w * 0.62, easeInOut(v)), width: w * 0.3, height: w * 0.3, borderRadius: 14, background: 'linear-gradient(135deg,#ff9a62,#ff5e87)', boxShadow: '0 20px 50px rgba(0,0,0,.4)', opacity: 1 - prog(t, 0.85, 0.2), transform: `rotate(${lerp(-14, 0, v)}deg)` }} />
      <Ring t={t} t0={0.85} x={x + w * 0.33} y={y + w * 0.77} color={GREEN} r1={220} />
    </>
  );
};

export const Background: React.FC<SceneProps> = ({ t, d }) => {
  const { width } = useVideoConfig();
  const O = useO();
  const w = O(1000, 960);
  const typed = 'getsidekick.app'.slice(0, Math.floor(clamp((t - 0.6) / 0.5) * 15));
  return (
    <>
      <Title t={t} d={d} lines={[[['Copy on your Mac.', 'w']], [['Paste in any app.', 'hi']]]} />
      <div style={{ position: 'absolute', left: (width - w) / 2, top: O(330, 640), width: w, borderRadius: 30, background: 'white', padding: 30, boxShadow: '0 40px 100px rgba(0,0,0,.5)', opacity: appear(t, 0, 0.4) }}>
        <div style={{ height: 80, borderRadius: 40, background: '#f1edf8', display: 'flex', alignItems: 'center', gap: 16, padding: '0 30px', fontFamily: 'Inter', fontWeight: 600, fontSize: 34, color: INK }}>
          <span style={{ opacity: typed ? 1 : 0.35 }}>{typed || 'Search or type URL'}</span>
          <span style={{ width: 3, height: 40, background: '#6a4cff', opacity: Math.floor(t * 3) % 2 }} />
        </div>
        {t < 0.6 && (
          <div style={{ marginTop: 16, display: 'inline-block', padding: '14px 26px', borderRadius: 16, background: INK, color: 'white', fontFamily: 'Inter', fontWeight: 600, fontSize: 28, transform: `scale(${back(prog(t, 0.1, 0.3))})` }}>Paste</div>
        )}
      </div>
    </>
  );
};

export const Encrypted: React.FC<SceneProps> = ({ t, d }) => {
  const { width } = useVideoConfig();
  const O = useO();
  const cx = width / 2, cy = O(560, 960);
  const size = O(260, 300);
  const chips = ['TLS', 'AES-256-GCM', 'SPAKE2 pairing'];
  return (
    <>
      <Title t={t} d={d} lines={[[['Encrypted.', 'w'], ['Always.', 'hi']]]} />
      {[0, 1, 2].map((k) => <Ring key={k} t={t} t0={k * BEAT} x={cx} y={cy} r0={size * 0.5} r1={size * 1.6} />)}
      <div style={{ position: 'absolute', left: cx - size / 2, top: cy - size / 2, width: size, height: size, borderRadius: size * 0.24, background: 'linear-gradient(160deg,#fff,#d8ccff)', display: 'grid', placeItems: 'center', boxShadow: '0 40px 100px rgba(80,40,200,.6)', transform: `scale(${back(prog(t, 0.05, 0.5))}) rotate(${lerp(-20, 0, easeOut(prog(t, 0.05, 0.6)))}deg)` }}>
        <Icon code={ICON.lock} size={size * 0.56} color="#5b3df0" />
      </div>
      <div style={{ position: 'absolute', left: 0, width, top: cy + size * 0.75, display: 'flex', justifyContent: 'center', gap: 18, flexWrap: 'wrap', padding: '0 60px' }}>
        {chips.map((c, i) => (
          <div key={c} style={{ transform: `scale(${back(prog(t, 0.35 + i * 0.12, 0.35))})` }}>
            <Pill icon={ICON.verified} text={c} size={28} />
          </div>
        ))}
      </div>
    </>
  );
};

export const NoAccount: React.FC<SceneProps> = ({ t, d }) => {
  const { width, height } = useVideoConfig();
  const O = useO();
  const items: [number, string][] = [[ICON.noAccount, 'No account.'], [ICON.cloudOff, 'No cloud.'], [ICON.block, 'No ads.']];
  return (
    <div style={{ position: 'absolute', left: 0, width, top: height / 2 - O(220, 330), display: 'flex', flexDirection: 'column', alignItems: 'center', gap: O(26, 40), opacity: 1 - prog(t, d - 0.22, 0.2) }}>
      {items.map(([icon, text], i) => {
        const u = prog(t, 0.05 + i * BEAT, 0.4);
        return (
          <div key={text} style={{ display: 'flex', alignItems: 'center', gap: 30, opacity: clamp(u * 3), transform: `translateX(${lerp(-80, 0, easeOut(u))}px)` }}>
            <Icon code={icon} size={O(96, 100)} color="#ffb98a" />
            <span style={{ fontFamily: 'InterDisplay', fontWeight: 900, fontSize: O(110, 108), color: 'white', letterSpacing: -3 }}>{text}</span>
          </div>
        );
      })}
    </div>
  );
};

export const Themes: React.FC<SceneProps> = ({ t, d }) => {
  const { width } = useVideoConfig();
  const O = useO();
  const w = O(330, 380);
  const x = width / 2 - w / 2, y = O(250, 560);
  const colors = ['#7c5cff', '#3d63c9', '#0f8b7a', '#3d8b3d', '#c9762c', '#c24d4d', '#c2557d', '#222'];
  const cx = width / 2, cy = y + w * O(1.2, 1.08);
  return (
    <>
      <Title t={t} d={d} lines={[[['Liquid Glass.', 'w']], [['Or your colors.', 'hi']]]} />
      {colors.map((c, i) => {
        const a = (i / colors.length) * Math.PI * 2 + t * 0.8;
        const r = O(300, 330) * easeOut(prog(t, 0.05 + i * 0.04, 0.5));
        return <div key={c} style={{ position: 'absolute', left: cx + Math.cos(a) * r - 40, top: cy + Math.sin(a) * r - 40, width: 80, height: 80, borderRadius: 40, background: c, border: '4px solid rgba(255,255,255,.8)', boxShadow: '0 10px 30px rgba(0,0,0,.4)' }} />;
      })}
      <Phone w={w} style={{ left: x, top: y }}>
        <Fill src="shots/glass-iphone-devices.png" />
      </Phone>
    </>
  );
};

export const Platforms: React.FC<SceneProps> = ({ t, d }) => {
  const { width } = useVideoConfig();
  const O = useO();
  const items: [number, string][] = [[ICON.laptop, 'Mac'], [ICON.windows, 'Windows'], [ICON.iphone, 'iPhone'], [ICON.android, 'Android']];
  const size = O(220, 250);
  return (
    <>
      <Title t={t} d={d} lines={[[['Every', 'w'], ['device.', 'hi']]]} />
      {items.map(([icon, label], i) => {
        const x = O(width / 2 + (i - 1.5) * 360, width / 2 + (i % 2 === 0 ? -210 : 210));
        const y = O(560, i < 2 ? 820 : 1220);
        return <DeviceTile key={label} icon={icon} x={x} y={y} size={size} t={t} t0={0.1 + i * BEAT} label={label} />;
      })}
    </>
  );
};

const WALL = ['shots/1-devices.png', 'shots/2b-files-folder.png', 'shots/glass-mac-devices.png', 'shots/tray-panel.png', 'shots/iphone-remote.png', 'shots/ping.png', 'shots/ad-mac-qr.png', 'shots/iphone-devices.png', 'shots/corner_asking.png', 'shots/iphone-settings-theme.png', 'shots/mac-devices.png'];

export const Montage: React.FC<SceneProps> = ({ t, d }) => {
  const { width, height } = useVideoConfig();
  const O = useO();
  const cols = O(4, 3);
  const cw = O(420, 320);
  return (
    <>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.85, transform: `perspective(1600px) rotateX(18deg) rotateZ(-8deg) translateY(${lerp(120, -260, prog(t, 0, d))}px) scale(1.25)` }}>
        {WALL.concat(WALL).map((src, i) => {
          const c = i % cols, r = Math.floor(i / cols);
          const u = prog(t, (i % 12) * 0.035, 0.4);
          return (
            <Img key={i} src={staticFile(src)} style={{ position: 'absolute', left: width / 2 + (c - (cols - 1) / 2) * (cw + 30) - cw / 2, top: r * (cw * 0.72 + 30) - 100, width: cw, height: cw * 0.68, objectFit: 'cover', objectPosition: 'top', borderRadius: 20, opacity: u, transform: `scale(${lerp(0.7, 1, easeOut(u))})`, boxShadow: '0 20px 50px rgba(0,0,0,.45)' }} />
          );
        })}
      </div>
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at center, rgba(16,6,40,.35), rgba(16,6,40,.85) 75%)' }} />
      <Headline t={t} lines={[[['Everything.', 'w']], [['One app.', 'hi']]]} size={O(130, 120)} y={height / 2 - O(140, 150)} start={0.1} out={d - 0.25} />
    </>
  );
};

const PILLS: [number, string][] = [
  [ICON.send, 'Send files'], [0xe450, 'Notifications'], [ICON.touch, 'Touchpad'], [ICON.keyboard, 'Keyboard'],
  [ICON.folder, 'Files'], [ICON.bell, 'Ping'], [0xe562, 'Screenshots'], [ICON.qr, 'Scan to pair'],
  [ICON.wifi, 'Direct Wi-Fi'], [ICON.bluetooth, 'Bluetooth'], [ICON.lock, 'Encrypted'], [ICON.photos, 'Gallery'],
];

export const Converge: React.FC<SceneProps> = ({ t, d }) => {
  const { width, height } = useVideoConfig();
  const O = useO();
  const cx = width / 2, cy = height / 2;
  return (
    <>
      {PILLS.map(([icon, text], i) => {
        const a = (i / PILLS.length) * Math.PI * 2 + t * (1 + 2 * prog(t, 0, d));
        const r = lerp(O(560, 420), 0, easeIn(prog(t, 0.25, d - 0.25)));
        const u = prog(t, i * 0.03, 0.3);
        return (
          <div key={text} style={{ position: 'absolute', left: cx + Math.cos(a) * r, top: cy + Math.sin(a) * r * O(0.55, 1.1), transform: `translate(-50%,-50%) scale(${lerp(0.4, 1, back(u)) * lerp(1, 0.2, easeIn(prog(t, 0.6, d - 0.6)))})`, opacity: clamp(u * 3) }}>
            <Pill icon={icon} text={text} size={O(28, 30)} />
          </div>
        );
      })}
    </>
  );
};

// ------------------------------------------------------------------ end card

export const EndCard: React.FC<SceneProps> = ({ t, d }) => {
  const { width, height } = useVideoConfig();
  const O = useO();
  const size = O(250, 300);
  const cx = width / 2, cy = O(330, 700);
  const v = prog(t, 0, 0.6);
  const fade = prog(t, d - 0.35, 0.35);
  return (
    <div style={{ position: 'absolute', inset: 0, opacity: 1 - fade }}>
      {[0, 1, 2].map((k) => <Ring key={k} t={t} t0={k * BEAT} x={cx} y={cy} r0={size * 0.5} r1={size * 2.2} dur={1.1} />)}
      <div style={{ position: 'absolute', left: cx - size / 2, top: cy - size / 2, width: size, height: size, transform: `scale(${lerp(0.3, 1, back(v))})`, opacity: clamp(v * 4) }}>
        <SkTile size={size} />
      </div>
      <Headline t={t} lines={[[['Sidekick', 'w']]]} size={O(130, 140)} y={cy + size / 2 + O(30, 50)} start={0.15} />
      <Headline t={t} lines={[[['Your devices,', 'w'], ['together.', 'hi']]]} size={O(52, 58)} y={cy + size / 2 + O(185, 230)} start={0.3} />
      <div style={{ position: 'absolute', left: cx, top: cy + size / 2 + O(300, 360), transform: `translate(-50%,0) scale(${back(prog(t, 0.5, 0.4))})` }}>
        <Pill icon={ICON.heart} text="Join the wishlist" size={O(36, 42)} />
      </div>
      <div style={{ position: 'absolute', left: 0, width, top: cy + size / 2 + O(410, 490), textAlign: 'center', color: '#d7ccff', fontFamily: 'Inter', fontWeight: 600, fontSize: O(30, 34), opacity: prog(t, 0.7, 0.3) }}>
        Coming soon · Mac · Windows · iPhone · Android
      </div>
      <div style={{ position: 'absolute', left: 0, width, top: cy + size / 2 + O(460, 550), textAlign: 'center', color: 'white', fontFamily: 'InterDisplay', fontWeight: 800, fontSize: O(40, 46), opacity: prog(t, 0.85, 0.3) }}>
        getsidekick.app
      </div>
    </div>
  );
};

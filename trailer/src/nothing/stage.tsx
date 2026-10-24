import React from 'react';
import { Img, staticFile } from 'remotion';
import { b, back, clamp, easeInOut, easeOut, keys, lerp, prog } from './beat';
import { Cursor, FileCard, Finger, IPhone, MacBook, Seq, Shot, macScreen, phoneScreen, quad } from './devices';
import { GREY, INK, MONO, PAPER, RED, Typed } from './dots';

export type PhonePose = { cx: number; cy: number; h: number; ry: number; rx: number; rz: number; o: number };
export type MacPose = { cx: number; cy: number; w: number; o: number };

type Key<P> = [number, P];

/** Eases from key to key (each key: reach this pose at this time). */
const posed = <P extends Record<string, number>>(t: number, ks: Key<P>[]): P => {
  if (t <= ks[0][0]) return ks[0][1];
  for (let i = 1; i < ks.length; i++) {
    if (t <= ks[i][0]) {
      const [t0, a] = ks[i - 1];
      const [t1, c] = ks[i];
      const u = easeInOut((t - t0) / (t1 - t0));
      const out = {} as Record<string, number>;
      for (const k of Object.keys(a)) out[k] = lerp(a[k], c[k as keyof P] as number, u);
      return out as P;
    }
  }
  return ks[ks.length - 1][1];
};

const P = (cx: number, cy: number, h: number, ry = 0, rx = 0, rz = 0, o = 1): PhonePose => ({ cx, cy, h, ry, rx, rz, o });
const M = (cx: number, cy: number, w: number, o = 1): MacPose => ({ cx, cy, w, o });

/** Where the devices are, scene by scene, for each shape of video. */
export const poses = (v: boolean) => {
  const T = 0.55; // how long a move takes
  if (v) {
    const send = { p: P(300, 1430, 800, 9, 2, -1.5), m: M(640, 960, 860) };
    const shots = { p: P(320, 1420, 860, 8, 2, -1), m: M(720, 1000, 680) };
    const browse = { p: P(540, 1300, 1020, 0, 0, 0), m: M(540, 900, 640, 0.22) };
    const remote = { p: P(790, 1500, 740, -10, 4, 2), m: M(540, 950, 960) };
    const ping = { p: P(540, 1280, 1000, 0, 0, 0), m: M(540, 900, 600, 0.18) };
    const wifi = { p: P(250, 1330, 640, 10, 0, 0), m: M(720, 1280, 600) };
    return {
      phone: [
        [b(8), P(540, 2500, 820, 200, 20, 10, 1)],
        [b(10.4), P(540, 1420, 820, -14, 5, 0)],
        [b(15.6), P(540, 1420, 820, -6, 3, 0)],
        [b(15.6) + T, send.p],
        [b(31.6), send.p],
        [b(31.6) + T, shots.p],
        [b(39.6), shots.p],
        [b(39.6) + T, browse.p],
        [b(47.6), browse.p],
        [b(47.6) + T, remote.p],
        [b(55.6), remote.p],
        [b(55.6) + T, ping.p],
        [b(59.6), ping.p],
        [b(59.6) + T, wifi.p],
        [b(63.5), wifi.p],
        [b(64.4), P(250, 2600, 640, 60, 20, -20)],
      ] as Key<PhonePose>[],
      mac: [
        [b(8), M(540, 2300, 880)],
        [b(9.8), M(540, 1020, 880)],
        [b(15.6), M(540, 1020, 880)],
        [b(15.6) + T, send.m],
        [b(31.6), send.m],
        [b(31.6) + T, shots.m],
        [b(39.6), shots.m],
        [b(39.6) + T, browse.m],
        [b(47.6), browse.m],
        [b(47.6) + T, remote.m],
        [b(55.6), remote.m],
        [b(55.6) + T, ping.m],
        [b(59.6), ping.m],
        [b(59.6) + T, wifi.m],
        [b(63.6), wifi.m],
        [b(64.5), M(720, 2400, 600)],
      ] as Key<MacPose>[],
    };
  }
  const send = { p: P(965, 650, 660, 9, 2, -1.5), m: M(1400, 470, 900) };
  const shots = { p: P(1000, 590, 740, 8, 2, -1), m: M(1500, 490, 760) };
  const browse = { p: P(1300, 560, 900, 0, 0, 0), m: M(1300, 420, 700, 0.2) };
  const remote = { p: P(1690, 700, 580, -10, 4, 2), m: M(1290, 480, 960) };
  const ping = { p: P(1300, 560, 880, 0, 0, 0), m: M(1300, 420, 700, 0.16) };
  const wifi = { p: P(1010, 600, 600, 10, 0, 0), m: M(1500, 560, 640) };
  return {
    phone: [
      [b(8), P(1300, 1700, 700, 200, 20, 10)],
      [b(10.4), P(1300, 630, 700, -14, 5, 0)],
      [b(15.6), P(1300, 630, 700, -6, 3, 0)],
      [b(15.6) + T, send.p],
      [b(31.6), send.p],
      [b(31.6) + T, shots.p],
      [b(39.6), shots.p],
      [b(39.6) + T, browse.p],
      [b(47.6), browse.p],
      [b(47.6) + T, remote.p],
      [b(55.6), remote.p],
      [b(55.6) + T, ping.p],
      [b(59.6), ping.p],
      [b(59.6) + T, wifi.p],
      [b(63.5), wifi.p],
      [b(64.4), P(1010, 1700, 600, 60, 20, -20)],
    ] as Key<PhonePose>[],
    mac: [
      [b(8), M(1300, 1500, 940)],
      [b(9.8), M(1300, 470, 940)],
      [b(15.6), M(1300, 470, 940)],
      [b(15.6) + T, send.m],
      [b(31.6), send.m],
      [b(31.6) + T, shots.m],
      [b(39.6), shots.m],
      [b(39.6) + T, browse.m],
      [b(47.6), browse.m],
      [b(47.6) + T, remote.m],
      [b(55.6), remote.m],
      [b(55.6) + T, ping.m],
      [b(59.6), ping.m],
      [b(59.6) + T, wifi.m],
      [b(63.6), wifi.m],
      [b(64.5), M(1500, 1600, 640)],
    ] as Key<MacPose>[],
  };
};

// ------------------------------------------------------------------ geometry

/** A point on the phone's screen (in pt, 402 × 874) in video pixels (flat). */
export const onPhone = (p: PhonePose, x: number, y: number): [number, number] => {
  const s = phoneScreen(p.h);
  return [p.cx - s.w / 2 + s.inset + (x / 402) * s.sw, p.cy - p.h / 2 + s.top + (y / 874) * s.sh];
};

/** A point in the Mac app's shot (1280 × 800) in video pixels. */
export const onMac = (m: MacPose, x: number, y: number): [number, number] => {
  const s = macScreen(m.w);
  const lidTop = m.cy - (s.lidH + s.baseH) / 2;
  const mb = s.sh * 0.034;
  return [m.cx - m.w / 2 + s.bezel + (x / 1280) * s.sw, lidTop + s.bezel + mb + (y / 1280) * s.sw];
};

/** Times the sending screens play to (the app's 30 fps frames, re-timed). */
const ACCEPT_MAC = b(20);
const ACCEPT_PHONE = b(27);

const phoneContent = (t: number): React.ReactNode => {
  if (t < b(16)) return <Shot src="iphone-devices" />;
  if (t < b(17.25)) return <Shot src="iphone-send" />;
  if (t < b(24.2)) {
    const i = t < b(20) ? keys(t, [[b(17.25), 12], [b(20), 29]]) : t < b(22.3) ? keys(t, [[b(20.15), 30], [b(22.3), 74]]) : keys(t, [[b(22.3), 75], [b(23.6), 104]]);
    return (
      <>
        <Shot src="iphone-send" />
        <Seq dir="iphone-sending" i={i} count={105} style={{ opacity: easeOut(prog(t, b(17.25), 0.25)) }} />
      </>
    );
  }
  if (t < b(25.3)) return <Shot src="iphone-devices" />;
  if (t < b(32)) {
    const i =
      t < ACCEPT_PHONE ? keys(t, [[b(25.3), 0], [b(26.6), 39]]) : t < b(28.8) ? keys(t, [[ACCEPT_PHONE + 0.03, 40], [b(28.8), 78]]) : keys(t, [[b(28.8), 79], [b(30.2), 108]]);
    return <Seq dir="iphone-incoming" i={i} count={109} />;
  }
  if (t < b(40)) return <Photo src={t < b(36) ? 'p1.jpg' : 'p3.jpg'} />;
  if (t < b(48)) {
    const u = easeOut(prog(t, b(42.1), 0.4));
    return (
      <>
        <Shot src="iphone-browse" style={{ transform: `translateX(${-30 * u}%)`, filter: `brightness(${1 - 0.5 * u})` }} />
        {u > 0 ? <Shot src="iphone-browse-home" style={{ transform: `translateX(${100 * (1 - u)}%)`, boxShadow: '0 0 40px rgba(0,0,0,.6)' }} /> : null}
      </>
    );
  }
  if (t < b(56)) return <Shot src="iphone-remote" />;
  if (t < b(60)) return <Seq dir="iphone-ping" i={keys(t, [[b(56), 0], [b(60), 59]])} count={60} />;
  return <Shot src="iphone-devices" />;
};

/** A photo as the Photos app shows it, full screen. */
const Photo: React.FC<{ src: string }> = ({ src }) => (
  <Img src={staticFile(`nothing/photos/${src}`)} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
);

const macContent = (t: number, k: number): React.ReactNode => {
  if (t < b(18)) return <Shot src={t < b(16) ? 'mac-devices' : 'mac-home'} />;
  if (t < b(24)) {
    const i = t < ACCEPT_MAC ? keys(t, [[b(18), 0], [b(19.4), 44]]) : t < b(22.3) ? keys(t, [[ACCEPT_MAC + 0.03, 45], [b(22.3), 92]]) : keys(t, [[b(22.3), 93], [b(23.6), 128]]);
    return <Seq dir="mac-incoming" i={i} count={129} />;
  }
  if (t < b(32)) return <Shot src="mac-send" />;
  if (t >= b(48) && t < b(56)) return <Desktop t={t} k={k} />;
  return <Shot src="mac-devices" />;
};

// ------------------------------------------------------------------ the Mac's desktop (Remote)

/** Where the pointer is on the Mac's desktop (fractions of the screen). */
const pointer = (t: number): [number, number] => {
  const path: [number, number, number][] = [
    [b(48.4), 0.62, 0.62],
    [b(49.3), 0.3, 0.45],
    [b(50.2), 0.55, 0.3],
    [b(51.2), 0.45, 0.42],
    [b(51.8), 0.45, 0.42],
  ];
  const x = keys(t, path.map(([tt, xx]) => [tt, xx] as [number, number]), easeInOut);
  const y = keys(t, path.map(([tt, , yy]) => [tt, yy] as [number, number]), easeInOut);
  return [x, y];
};
const TYPED = 'hi from my phone :)';
const TYPE_AT = b(52.6);

const Desktop: React.FC<{ t: number; k: number }> = ({ t, k }) => (
  <div style={{ position: 'absolute', inset: 0, background: INK, containerType: 'size' }}>
    <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0 }}>
      <defs>
        <pattern id="grid" width="2.2%" height="3.52%" patternUnits="userSpaceOnUse">
          <circle cx="1%" cy="1%" r="1.2" fill="#2a2a27" />
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#grid)" />
    </svg>
    {/* A note window: what the phone types lands here. */}
    <div
      style={{
        position: 'absolute',
        left: '24%',
        top: '18%',
        width: '52%',
        height: '50%',
        borderRadius: '1.2cqw',
        background: '#141413',
        boxShadow: '0 2cqw 5cqw rgba(0,0,0,.6), 0 0 0 1px #2c2c29',
        outline: t > b(52) ? `0.25cqw solid rgba(215,25,33,${0.25 * (1 - prog(t, b(52.2), 0.8))})` : undefined,
      }}
    >
      <div style={{ height: '11%', borderBottom: '1px solid #262624', display: 'flex', alignItems: 'center', gap: '0.8cqw', paddingLeft: '1.6cqw' }}>
        {['#ff5f57', '#febc2e', '#28c840'].map((c) => (
          <div key={c} style={{ width: '1.1cqw', height: '1.1cqw', borderRadius: '50%', background: c }} />
        ))}
        <div style={{ marginLeft: '1.5cqw', fontFamily: MONO, fontSize: '1.3cqw', letterSpacing: '0.2cqw', color: GREY }}>NOTES</div>
      </div>
      <div style={{ padding: '2.4cqw 3cqw', fontFamily: 'Inter', fontWeight: 600, fontSize: '3.4cqw', color: PAPER }}>
        <Typed t={t} text={TYPED} start={TYPE_AT} cps={12} cursor={t > b(52.2)} />
      </div>
    </div>
    {/* The Dock. */}
    <div
      style={{
        position: 'absolute',
        left: '33%',
        width: '34%',
        bottom: '2%',
        height: '9%',
        borderRadius: '2cqw',
        background: 'rgba(40,40,38,.7)',
        boxShadow: '0 0 0 1px rgba(255,255,255,.08)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-around',
        padding: '0 1cqw',
      }}
    >
      {['#e9e9e6', '#3d3d3a', '#3d3d3a', RED, '#3d3d3a', '#3d3d3a'].map((c, i) => (
        <div key={i} style={{ width: '4.2cqw', height: '4.2cqw', borderRadius: '1cqw', background: c, display: 'grid', placeItems: 'center' }}>
          {i === 0 ? <div style={{ fontFamily: MONO, fontWeight: 700, fontSize: '1.7cqw', color: INK }}>sk.</div> : null}
        </div>
      ))}
    </div>
    {(() => {
      const [x, y] = pointer(t);
      return (
        <div style={{ position: 'absolute', left: 0, top: 0, width: '100%', height: '100%' }}>
          <CursorPct t={t} x={x} y={y} size={22 * k * 1.6} />
        </div>
      );
    })()}
  </div>
);

const CursorPct: React.FC<{ t: number; x: number; y: number; size: number }> = ({ t, x, y, size }) => (
  <div style={{ position: 'absolute', left: `${x * 100}%`, top: `${y * 100}%`, width: 0, height: 0 }}>
    <Cursor t={t} x={0} y={0} size={size} clicks={[b(52)]} />
  </div>
);

// ------------------------------------------------------------------ the stage

/** The Mac's notification for a screenshot that just came in. */
const Notice: React.FC<{ t: number; at: number; src: string; s: number; style?: React.CSSProperties }> = ({ t, at, src, s, style }) => {
  const u = easeOut(prog(t, at, 0.45)) * (1 - easeOut(prog(t, b(39.7), 0.3)));
  if (u <= 0) return null;
  return (
    <div
      style={{
        position: 'absolute',
        width: 300 * s,
        height: 64 * s,
        borderRadius: 14 * s,
        background: 'rgba(30,30,29,.92)',
        boxShadow: `0 ${8 * s}px ${24 * s}px rgba(0,0,0,.5), 0 0 0 1px rgba(255,255,255,.1)`,
        display: 'flex',
        alignItems: 'center',
        gap: 10 * s,
        padding: `0 ${10 * s}px`,
        boxSizing: 'border-box',
        transform: `translateX(${(1 - u) * 340 * s}px)`,
        ...style,
      }}
    >
      <div style={{ width: 38 * s, height: 38 * s, borderRadius: 9 * s, background: '#000', boxShadow: '0 0 0 1px #333', display: 'grid', placeItems: 'center', fontFamily: MONO, fontWeight: 700, fontSize: 14 * s, color: PAPER }}>
        sk<span style={{ color: RED }}>.</span>
      </div>
      <div style={{ flex: 1, fontFamily: 'Inter', color: PAPER, lineHeight: 1.25 }}>
        <div style={{ fontWeight: 600, fontSize: 12.5 * s }}>Sidekick</div>
        <div style={{ fontSize: 11.5 * s, color: '#c9c9c4' }}>Screenshot from iPhone 17 Pro</div>
      </div>
      <Img src={staticFile(`nothing/photos/${src}`)} style={{ width: 30 * s, height: 46 * s, objectFit: 'cover', borderRadius: 4 * s }} />
    </div>
  );
};

/** A dotted trail behind something flying along [path] (u = where it is now). */
const Trail: React.FC<{ path: (u: number) => [number, number]; u: number; r: number; color?: string }> = ({ path, u, r, color = PAPER }) => (
  <>
    {[...Array(9)].map((_, i) => {
      const uu = u - (i + 1) * 0.035;
      if (uu <= 0 || u >= 1) return null;
      const [x, y] = path(uu);
      const rr = r * (1 - i / 10);
      return <div key={i} style={{ position: 'absolute', left: x - rr, top: y - rr, width: 2 * rr, height: 2 * rr, borderRadius: '50%', background: i === 0 ? RED : color, opacity: 0.8 - i * 0.08 }} />;
    })}
  </>
);

/** Things flying between the devices: files, screenshots. */
const flights = (t: number, phone: PhonePose, mac: MacPose, v: boolean) => {
  const out: React.ReactNode[] = [];
  const size = v ? 120 : 100;
  const fly = (key: string, from: [number, number], to: [number, number], at: number, dur: number, card: (w: number) => React.ReactNode, lift: number, w0 = size, w1 = size * 0.55) => {
    const u = prog(t, at, dur);
    if (u <= 0 || u >= 1) return;
    const e = easeInOut(u);
    const mid: [number, number] = [(from[0] + to[0]) / 2, Math.min(from[1], to[1]) - lift];
    const path = (x: number) => quad(from, mid, to, x);
    const [x, y] = path(e);
    const w = lerp(w0, w1, e) * (u < 0.15 ? back(u / 0.15) : 1);
    out.push(<Trail key={`${key}t`} path={(x2) => path(easeInOut(x2))} u={u} r={v ? 7 : 6} />);
    out.push(
      <div key={key} style={{ position: 'absolute', left: x - w / 2, top: y - w * 0.625, transform: `rotate(${Math.sin(u * Math.PI) * -14}deg)`, opacity: u > 0.9 ? 1 - (u - 0.9) * 10 : 1 }}>
        {card(w)}
      </div>,
    );
  };
  // 01: photos and a video, iPhone → Mac.
  const files: ['photo' | 'video', string][] = [
    ['photo', 'p1.jpg'],
    ['photo', 'p2.jpg'],
    ['photo', 'p3.jpg'],
    ['video', 'p2.jpg'],
  ];
  files.forEach(([kind, src], i) =>
    fly(`f${i}`, onPhone(phone, 200, 430), onMac(mac, 640, 380), b(20.2) + i * 0.33, 0.85, (w) => <FileCard kind={kind} src={src} name="" w={w} />, v ? 260 : 220),
  );
  // 02: documents, Mac → iPhone.
  ['Pitch deck.key', 'Invoice_October.pdf'].forEach((name, i) =>
    fly(`d${i}`, onMac(mac, 840, 410), onPhone(phone, 200, 420), ACCEPT_PHONE + 0.1 + i * 0.4, 0.9, (w) => <FileCard kind="doc" name={name} w={w} />, v ? 200 : 180),
  );
  // 03: screenshots, from the corner thumbnail to the Mac's notification.
  [
    [b(34.4), 'p1.jpg'],
    [b(38.4), 'p3.jpg'],
  ].forEach(([at, src], i) =>
    fly(
      `s${i}`,
      onPhone(phone, 70, 760),
      onMac(mac, 1120, 70 + i * 0),
      at as number,
      0.75,
      (w) => <FileCard kind="photo" src={src as string} name="" w={w} />,
      v ? 160 : 140,
      size * 0.7,
      size * 0.3,
    ),
  );
  return out;
};

export const Stage: React.FC<{ t: number; v: boolean }> = ({ t, v }) => {
  const ps = poses(v);
  const phone = posed(t, ps.phone);
  const mac = posed(t, ps.mac);
  // Ping: the phone buzzes.
  const buzz = t > b(56.2) && t < b(60) ? Math.sin(t * 95) * 1.6 * (0.5 + 0.5 * Math.sin(t * 6)) : 0;
  // A screenshot: the side buttons go in, the screen flashes, a thumbnail sits in the corner.
  const snaps = [b(33), b(37)];
  const press = Math.max(...snaps.map((s) => clamp(1 - Math.abs(t - s) / 0.18)));
  const flash = Math.max(...snaps.map((s) => (t >= s ? Math.exp(-(t - s) * 9) : 0)));
  const thumb = snaps.map((s) => clamp(prog(t, s + 0.05, 0.35)) * (1 - prog(t, s + 1.4, 0.05)));
  const sp = phoneScreen(phone.h);
  const ms = macScreen(mac.w);
  const macLeft = mac.cx - mac.w / 2;
  const macTop = mac.cy - (ms.lidH + ms.baseH) / 2;
  // The finger on the phone, in pt.
  const fingerAt = (): { x: number; y: number; show: number; taps: number[] } => {
    if (t > b(16.3) && t < b(17.8)) return { x: 290, y: 383, show: prog(t, b(16.3), 0.2) * (1 - prog(t, b(17.5), 0.25)), taps: [b(17)] };
    if (t > b(26) && t < b(27.8)) return { x: 292, y: 792, show: prog(t, b(26), 0.2) * (1 - prog(t, b(27.5), 0.25)), taps: [ACCEPT_PHONE] };
    if (t > b(41.2) && t < b(42.6)) return { x: 120, y: 497, show: prog(t, b(41.2), 0.2) * (1 - prog(t, b(42.3), 0.25)), taps: [b(42)] };
    if (t > b(44.2) && t < b(46)) return { x: 368, y: 733, show: prog(t, b(44.2), 0.2) * (1 - prog(t, b(45.7), 0.25)), taps: [b(45)] };
    if (t > b(48.2) && t < b(52.4)) {
      // Dragging on the touchpad: the pointer on the Mac follows.
      const [px, py] = pointer(t);
      return { x: 60 + px * 280, y: 260 + py * 230, show: prog(t, b(48.2), 0.2) * (1 - prog(t, b(52.1), 0.25)), taps: [b(52)] };
    }
    return { x: 0, y: 0, show: 0, taps: [] };
  };
  const f = fingerAt();
  const u = sp.sw / 402;
  // The Mac's pointer while it works the Sidekick window (01, 02).
  const macCursor = (): { x: number; y: number; show: number; clicks: number[] } | null => {
    if (t > b(18.6) && t < b(21)) {
      const x = keys(t, [[b(18.6), 1000], [b(19.6), 744]], easeInOut);
      const y = keys(t, [[b(18.6), 760], [b(19.6), 662]], easeInOut);
      return { x, y, show: prog(t, b(18.6), 0.2) * (1 - prog(t, b(20.7), 0.25)), clicks: [ACCEPT_MAC] };
    }
    if (t > b(24) && t < b(26)) {
      const x = keys(t, [[b(24), 600], [b(24.8), 840]], easeInOut);
      const y = keys(t, [[b(24), 600], [b(24.8), 406]], easeInOut);
      return { x, y, show: prog(t, b(24), 0.2) * (1 - prog(t, b(25.7), 0.25)), clicks: [b(25)] };
    }
    return null;
  };
  const mc = macCursor();
  const k = ms.sw / 1280;
  const typed = t > TYPE_AT && t < b(56) ? TYPED.slice(0, Math.floor((t - TYPE_AT) * 12)) : '';
  return (
    <>
      <PingRings t={t} phone={phone} />
      <MacBook w={mac.w} style={{ left: macLeft, top: macTop, opacity: mac.o }}>
        {macContent(t, k)}
        {mc ? <Cursor t={t} x={mc.x * k} y={mc.y * k} size={22 * k * 1.6} clicks={mc.clicks} show={mc.show} /> : null}
        <Notice t={t} at={b(35.3)} src="p1.jpg" s={k * 1.6} style={{ right: 14 * k, top: 14 * k }} />
        <Notice t={t} at={b(39.3)} src="p3.jpg" s={k * 1.6} style={{ right: 14 * k, top: 14 * k + 72 * k * 1.6 }} />
      </MacBook>
      <IPhone
        h={phone.h}
        ry={phone.ry}
        rx={phone.rx}
        rz={phone.rz + buzz}
        press={press}
        style={{ left: phone.cx - sp.w / 2 + buzz * 3, top: phone.cy - phone.h / 2, opacity: phone.o }}
      >
        {phoneContent(t)}
        {typed ? (
          <div style={{ position: 'absolute', left: 92 * u, top: 712 * u, width: 280 * u, height: 30 * u, background: '#121211', fontFamily: 'Inter', fontSize: 15 * u, color: PAPER, display: 'flex', alignItems: 'center' }}>
            {typed}
            <span style={{ color: RED }}>▌</span>
          </div>
        ) : null}
        <Toast t={t} u={u} />
        <Finger t={t} x={f.x * u} y={f.y * u} size={46 * u} show={f.show} taps={f.taps} />
        {thumb.map((s, i) =>
          s > 0 ? (
            <div
              key={i}
              style={{
                position: 'absolute',
                left: lerp(0, 18 * u, easeOut(s)),
                top: lerp(0, 640 * u, easeOut(s)),
                width: lerp(sp.sw, 104 * u, easeOut(s)),
                height: lerp(sp.sh, 226 * u, easeOut(s)),
                borderRadius: lerp(sp.sw * 0.137, 12 * u, easeOut(s)),
                overflow: 'hidden',
                border: `${3 * u}px solid #fff`,
                boxShadow: '0 10px 30px rgba(0,0,0,.5)',
                opacity: s > 0.98 && t > snaps[i] + 1.2 ? 0 : 1,
              }}
            >
              <Img src={staticFile(`nothing/photos/${i === 0 ? 'p1.jpg' : 'p3.jpg'}`)} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            </div>
          ) : null,
        )}
        {flash > 0.01 ? <div style={{ position: 'absolute', inset: 0, background: '#fff', opacity: flash }} /> : null}
      </IPhone>
      {flights(t, phone, mac, v)}
      <WifiLink t={t} phone={phone} mac={mac} v={v} />
    </>
  );
};

/** 07: the two devices talk straight to each other, no router. */
const WifiLink: React.FC<{ t: number; phone: PhonePose; mac: MacPose; v: boolean }> = ({ t, phone, mac, v }) => {
  const on = prog(t, b(60.4), 0.4) * (1 - prog(t, b(63.6), 0.3));
  if (on <= 0) return null;
  const sp = phoneScreen(phone.h);
  const ms = macScreen(mac.w);
  const a: [number, number] = [phone.cx + sp.w * 0.1, phone.cy - phone.h / 2 - 30];
  const c: [number, number] = [mac.cx - mac.w * 0.1, mac.cy - (ms.lidH + ms.baseH) / 2 - 30];
  const mid: [number, number] = [(a[0] + c[0]) / 2, Math.min(a[1], c[1]) - (v ? 150 : 120)];
  const n = 26;
  const dots: React.ReactNode[] = [];
  for (let i = 0; i <= n; i++) {
    const uu = i / n;
    if (uu > on * 1.02) break;
    const [x, y] = quad(a, mid, c, uu);
    const wave = Math.exp(-Math.pow(((uu - ((t * 0.9) % 1.4) + 0.2) * 7), 2));
    const r = (v ? 5 : 4) * (1 + wave * 0.9);
    dots.push(<div key={i} style={{ position: 'absolute', left: x - r, top: y - r, width: 2 * r, height: 2 * r, borderRadius: '50%', background: wave > 0.5 ? RED : PAPER, opacity: 0.85 }} />);
  }
  const [lx, ly] = quad(a, mid, c, 0.5);
  return (
    <>
      {dots}
      <div
        style={{
          position: 'absolute',
          left: lx - 200,
          width: 400,
          top: ly - (v ? 70 : 60),
          textAlign: 'center',
          fontFamily: MONO,
          fontWeight: 500,
          fontSize: v ? 22 : 18,
          letterSpacing: 3,
          color: PAPER,
          opacity: on,
        }}
      >
        DIRECT WI-FI
      </div>
    </>
  );
};

/** 06: red rings of dots spreading from the ringing phone. */
const PingRings: React.FC<{ t: number; phone: PhonePose }> = ({ t, phone }) => {
  if (t < b(56.2) || t > b(60.2)) return null;
  const fade = 1 - prog(t, b(59.6), 0.4);
  const rings: React.ReactNode[] = [];
  for (let k = 0; k < 4; k++) {
    const age = (t - b(56.2) - k * 0.45) % 1.8;
    if (t - b(56.2) - k * 0.45 < 0) continue;
    const u = age / 1.8;
    const r = phone.h * (0.35 + 0.5 * easeOut(u));
    const n = 40;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2;
      const x = phone.cx + Math.cos(a) * r * 0.75;
      const y = phone.cy + Math.sin(a) * r;
      const d = 7 * (1 - u * 0.6);
      rings.push(<div key={`${k}-${i}`} style={{ position: 'absolute', left: x - d, top: y - d, width: 2 * d, height: 2 * d, borderRadius: '50%', background: RED, opacity: (1 - u) * 0.9 * fade }} />);
    }
  }
  return <>{rings}</>;
};

/** 04: the file the phone just downloaded from the Mac. */
const Toast: React.FC<{ t: number; u: number }> = ({ t, u }) => {
  const at = b(45.2);
  const k = easeOut(prog(t, at, 0.3)) * (1 - easeOut(prog(t, b(47.4), 0.25)));
  if (k <= 0) return null;
  return (
    <div
      style={{
        position: 'absolute',
        left: 24 * u,
        right: 24 * u,
        bottom: 104 * u,
        height: 52 * u,
        borderRadius: 26 * u,
        background: PAPER,
        display: 'flex',
        alignItems: 'center',
        gap: 10 * u,
        padding: `0 ${18 * u}px`,
        fontFamily: MONO,
        fontWeight: 500,
        fontSize: 12.5 * u,
        letterSpacing: 1.2 * u,
        color: INK,
        opacity: k,
        transform: `translateY(${(1 - k) * 30 * u}px)`,
      }}
    >
      <span style={{ width: 9 * u, height: 9 * u, borderRadius: '50%', background: '#22C55E' }} />
      PITCH DECK.KEY · ON YOUR IPHONE
    </div>
  );
};

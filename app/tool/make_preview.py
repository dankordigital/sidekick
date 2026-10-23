#!/usr/bin/env python3
"""Turns the frames from tool/preview_shots_test.dart into the website's
live preview images (website/preview/):

  * each tab as a still (WebP),
  * each animation as an animated WebP (15 fps; the "asking" one loops,
    the rest play once and stay on their last frame),
  * preview.json: where the buttons are, image sizes and how long each
    animation runs, for preview.html.

Run from app/, after both renders:

  flutter test tool/preview_shots_test.dart --dart-define=DEVICE=iphone
  flutter test tool/preview_shots_test.dart --dart-define=DEVICE=mac
  python3 tool/make_preview.py

The Inter font the renders use stands in for San Francisco: put Inter's
release in build/fonts/x/ first (https://github.com/rsms/inter/releases,
unzipped), or they fall back to Roboto.
"""

import json
from pathlib import Path

from PIL import Image

SRC = Path('build/preview')
OUT = Path('../website/preview')
FPS = 15
# Pixels per point in the page's images: sharp on retina screens, small
# enough for a web page.
SCALE = {'mac': 1.5, 'iphone': 2}
LOOPING = {'send-wait'}


def load(path: Path, device: str, size) -> Image.Image:
    im = Image.open(path).convert('RGB')
    w, h = round(size[0] * SCALE[device]), round(size[1] * SCALE[device])
    return im if im.size == (w, h) else im.resize((w, h), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob('*.webp'):
        old.unlink()
    manifest = {}
    for device in ('mac', 'iphone'):
        info = json.loads((SRC / f'{device}.json').read_text())
        size = info['size']
        screens = {}
        for png in sorted((SRC / device).glob('*.png')):
            name = f'{device}-{png.stem}.webp'
            load(png, device, size).save(OUT / name, 'WEBP', quality=82, method=6)
            screens[png.stem] = name
        sequences = {}
        for key, count in info.items():
            if not key.startswith('seq:'):
                continue
            seq = key[4:]
            frames = [load(SRC / device / seq / f'{i:03d}.png', device, size) for i in range(count)]
            name = f'{device}-{seq}.webp'
            frames[0].save(
                OUT / name,
                'WEBP',
                save_all=True,
                append_images=frames[1:],
                duration=round(1000 / FPS),
                loop=0 if seq in LOOPING else 1,
                quality=80,
                method=4,
            )
            sequences[seq] = {'src': name, 'ms': round(count * 1000 / FPS), 'loop': seq in LOOPING}
        manifest[device] = {
            'size': size,
            'screens': screens,
            'sequences': sequences,
            **{k: v for k, v in info.items() if not k.startswith('seq:') and k not in ('size', 'dpr')},
        }
    (OUT / 'preview.json').write_text(json.dumps(manifest, indent=1))
    total = sum(f.stat().st_size for f in OUT.iterdir())
    print(f'{len(list(OUT.iterdir()))} files, {total / 1e6:.1f} MB in {OUT}')


if __name__ == '__main__':
    main()

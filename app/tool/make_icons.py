"""Builds every app icon from the logo artwork in website/.

    pip install pillow numpy
    python app/tool/make_icons.py        # from the repo root

Source:
  website/3.png  the "sk" monogram: every app icon (dock, desktop, taskbar,
                 home screens) at every size, and the logo inside the app.
                 (The website uses the SIDEKICK wordmark, website/2.png,
                 embedded in index.html.)

Writes the Windows .ico, Android launcher icons, macOS and iOS app icon sets,
and the in-app logo. Re-run it whenever the artwork changes.

Mac and iPhone get the Liquid Glass look:
  * AppIcon.icon (Icon Composer format) in ios/Runner and macos/Runner: a
    lavender gradient with the "sk" as a glass layer. On macOS/iOS 26 and
    later the system renders it as real Liquid Glass (live highlights,
    depth, and the Dark, Clear and Tinted looks). Xcode 26 builds it.
  * The AppIcon.appiconset images are a pre-rendered glass version of the
    same, for older macOS and iOS.
"""

import io
import json
import shutil
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"
BG = (204, 197, 255)  # lavender background of the artwork
INK = (42, 28, 86)  # dark purple lettering
# How much of the tile the monogram's longer side covers: enough to read at
# 16 px, with room to breathe so it doesn't look crammed edge to edge.
MONOGRAM_FRAC = 0.56


def load_mask(path: Path) -> Image.Image:
    """Artwork → tightly cropped alpha mask (L mode), anti-aliasing kept."""
    a = np.asarray(Image.open(path).convert("RGB"), float)
    bg, ink = np.array(BG, float), np.array(INK, float)
    t = ((a - bg) @ (ink - bg)) / ((ink - bg) @ (ink - bg))
    alpha = (np.clip(t, 0, 1) * 255).astype(np.uint8)
    ys, xs = np.nonzero(alpha > 8)
    return Image.fromarray(alpha, "L").crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


MONOGRAM = load_mask(ROOT / "website" / "3.png")


def paste_logo(canvas: Image.Image, box: tuple, *, frac: float = MONOGRAM_FRAC, color=INK) -> None:
    """Centres the "sk" monogram inside `box` (x, y, w, h)."""
    x, y, w, h = box
    mask = MONOGRAM
    scale = min(w * frac / mask.width, h * frac / mask.height)
    m = mask.resize((max(1, round(mask.width * scale)), max(1, round(mask.height * scale))), Image.LANCZOS)
    layer = Image.new("RGBA", m.size, color + (255,))
    layer.putalpha(m)
    canvas.alpha_composite(layer, (x + (w - m.width) // 2, y + (h - m.height) // 2))


def tile(size: int, *, radius_frac: float = 0.0, inset_frac: float = 0.0) -> Image.Image:
    """Lavender (rounded) square with the logo, drawn at 4x then downscaled."""
    s = size * 4
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    inset = round(s * inset_frac)
    box = (inset, inset, s - 2 * inset, s - 2 * inset)
    shape = Image.new("L", (s, s), 0)
    ImageDraw.Draw(shape).rounded_rectangle(
        (box[0], box[1], box[0] + box[2] - 1, box[1] + box[3] - 1), radius=round(box[2] * radius_frac), fill=255
    )
    fill = Image.new("RGBA", (s, s), BG + (255,))
    canvas.paste(fill, (0, 0), shape)
    paste_logo(canvas, box)
    return canvas.resize((size, size), Image.LANCZOS)


# ------------------------------------------------------------ Liquid Glass

GLASS_TOP = (222, 216, 255)  # light lavender at the top of the tile
GLASS_BOTTOM = (160, 145, 250)  # deeper at the bottom
INK_TOP = (78, 60, 150)  # the glyph is lighter where light hits it
INK_BOTTOM = (34, 22, 74)


def _vertical(size: int, top: tuple, bottom: tuple) -> Image.Image:
    t = np.linspace(0, 1, size)[:, None, None]
    rows = np.array(top, float) * (1 - t) + np.array(bottom, float) * t
    return Image.fromarray(np.repeat(rows, size, axis=1).astype(np.uint8), "RGB").convert("RGBA")


def _glyph_mask(s: int, frac: float) -> Image.Image:
    """The monogram's alpha, centred on an s×s canvas."""
    scale = min(s * frac / MONOGRAM.width, s * frac / MONOGRAM.height)
    m = MONOGRAM.resize((round(MONOGRAM.width * scale), round(MONOGRAM.height * scale)), Image.LANCZOS)
    out = Image.new("L", (s, s), 0)
    out.paste(m, ((s - m.width) // 2, (s - m.height) // 2))
    return out


def glass_tile(size: int, *, radius_frac: float = 0.0, inset_frac: float = 0.0, full_bleed: bool = False) -> Image.Image:
    """A pre-rendered Liquid Glass icon: frosted lavender, a soft sheen and
    rim light, and a crisp "sk" (no shadow). Drawn at 4x, then downscaled."""
    s = size * 4
    inset = round(s * inset_frac)
    w = s - 2 * inset
    shape = Image.new("L", (s, s), 0)
    ImageDraw.Draw(shape).rounded_rectangle((inset, inset, inset + w - 1, inset + w - 1), radius=round(w * radius_frac), fill=255)

    tile = _vertical(s, GLASS_TOP, GLASS_BOTTOM)
    # A broad sheen from the top left, like light through glass.
    sheen = Image.new("L", (s, s), 0)
    ImageDraw.Draw(sheen).ellipse((inset - w * 0.35, inset - w * 0.6, inset + w * 0.95, inset + w * 0.45), fill=120)
    sheen = sheen.filter(ImageFilter.GaussianBlur(w * 0.08))
    tile = Image.composite(Image.new("RGBA", (s, s), (255, 255, 255, 255)), tile, sheen)

    # The glyph: crisp, with a vertical gradient in it. No shadow and no
    # highlight along its edges: they blurred the letters (the owner's call).
    glyph = _glyph_mask(s, MONOGRAM_FRAC * (w / s))
    ink = _vertical(s, INK_TOP, INK_BOTTOM)
    tile = Image.composite(ink, tile, glyph)
    # A faint gloss inside the upper half of the glyph.
    upper = Image.new("L", (s, s), 0)
    ImageDraw.Draw(upper).rectangle((0, 0, s, s * 0.47), fill=40)
    upper = upper.filter(ImageFilter.GaussianBlur(w * 0.03))
    tile = Image.composite(Image.new("RGBA", (s, s), (255, 255, 255, 255)), tile, ImageChops.multiply(glyph, upper))

    # Rim light: a thin bright line around the tile, strongest at the top.
    ring = ImageChops.subtract(shape, shape.filter(ImageFilter.MinFilter(max(3, (round(w * 0.012) // 2) * 2 + 1))))
    fade = _vertical(s, (255, 255, 255), (90, 90, 90)).convert("L")
    tile = Image.composite(Image.new("RGBA", (s, s), (255, 255, 255, 255)), tile, ImageChops.multiply(ring, fade).point(lambda v: v * 0.7))

    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    if full_bleed:
        out = tile
    else:
        out.paste(tile, (0, 0), shape)
    return out.resize((size, size), Image.LANCZOS)


def icon_composer() -> None:
    """AppIcon.icon for Xcode 26: the system turns it into Liquid Glass."""
    canvas = 1024
    glyph = _glyph_mask(canvas * 4, MONOGRAM_FRAC).resize((canvas, canvas), Image.LANCZOS)
    layer = Image.new("RGBA", (canvas, canvas), INK + (255,))
    layer.putalpha(glyph)

    def srgb(c: tuple) -> str:
        return "srgb:" + ",".join(f"{v / 255:.5f}" for v in c) + ",1.00000"

    spec = {
        "fill": {"linear-gradient": [srgb(GLASS_TOP), srgb(GLASS_BOTTOM)]},
        "groups": [
            {
                "layers": [{"glass": True, "image-name": "sk.png", "name": "sk"}],
                # No shadow under the letters: it blurred them.
                "shadow": {"kind": "none", "opacity": 0.5},
                "translucency": {"enabled": True, "value": 0.4},
            }
        ],
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }
    for platform in ("ios", "macos"):
        folder = APP / platform / "Runner/AppIcon.icon"
        shutil.rmtree(folder, ignore_errors=True)
        (folder / "Assets").mkdir(parents=True)
        layer.save(folder / "Assets/sk.png", optimize=True)
        (folder / "icon.json").write_text(json.dumps(spec, indent=2) + "\n")


def png_bytes(im: Image.Image) -> bytes:
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def write_ico(path: Path, images: list) -> None:
    """ICO with PNG-compressed entries, so each size can have its own art."""
    blobs = [png_bytes(im) for im in images]
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries = b""
    for im, blob in zip(images, blobs):
        w = im.width if im.width < 256 else 0
        entries += struct.pack("<BBBBHHII", w, w, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    path.write_bytes(header + entries + b"".join(blobs))


def windows() -> None:
    sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    write_ico(APP / "windows/runner/resources/app_icon.ico", [tile(s, radius_frac=0.2) for s in sizes])


def android() -> None:
    res = APP / "android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, k in densities.items():
        folder = res / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        # Legacy launchers: a rounded square.
        tile(round(48 * k), radius_frac=0.22).save(folder / "ic_launcher.png", optimize=True)
        # Adaptive icon foreground: 108dp canvas; launchers mask it to a
        # 72dp shape and only the 66dp circle is safe. The monogram's corners
        # stay inside it (about the same size as on the other icons).
        px = round(108 * k)
        fg = Image.new("RGBA", (px * 4, px * 4), (0, 0, 0, 0))
        paste_logo(fg, (0, 0, px * 4, px * 4), frac=MONOGRAM_FRAC * 72 / 108)
        fg.resize((px, px), Image.LANCZOS).save(folder / "ic_launcher_foreground.png", optimize=True)
    (res / "values/colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">#FF{BG[0]:02X}{BG[1]:02X}{BG[2]:02X}</color>\n'
        '    <color name="ic_launcher_nothing_background">#FF000000</color>\n'
        "</resources>\n"
    )
    (res / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "    <!-- Android 13+ themed icons -->\n"
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n"
    )


def appiconset(folder: Path, make) -> None:
    contents = json.loads((folder / "Contents.json").read_text())
    done = set()
    for entry in contents["images"]:
        name = entry.get("filename")
        if not name or name in done:
            continue
        points = float(entry["size"].split("x")[0])
        px = round(points * int(entry["scale"].rstrip("x")))
        make(px).save(folder / name, optimize=True)
        done.add(name)


def macos() -> None:
    # Before macOS 26: a rounded square with a margin, on a transparent canvas.
    appiconset(
        APP / "macos/Runner/Assets.xcassets/AppIcon.appiconset",
        lambda px: glass_tile(px, radius_frac=0.225, inset_frac=0.1),
    )


def ios() -> None:
    # Before iOS 26. iOS rounds the corners itself and rejects transparency:
    # full-bleed, RGB.
    appiconset(
        APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset",
        lambda px: glass_tile(px, full_bleed=True).convert("RGB"),
    )


def website() -> None:
    """The browser-tab icon (favicon) and the home-screen icon for the site."""
    web = ROOT / "website"
    glass_tile(64, radius_frac=0.24).save(web / "favicon.png", optimize=True)
    glass_tile(180, full_bleed=True).convert("RGB").save(web / "apple-touch-icon.png", optimize=True)


def in_app() -> None:
    """White-on-transparent "sk"; the app tints it with the theme colour."""
    out = APP / "assets/logo"
    out.mkdir(parents=True, exist_ok=True)
    h = 192  # sharp at 3x on a 64 px logo
    m = MONOGRAM.resize((round(MONOGRAM.width * h / MONOGRAM.height), h), Image.LANCZOS)
    im = Image.new("RGBA", m.size, (255, 255, 255, 255))
    im.putalpha(m)
    im.save(out / "logo.png", optimize=True)
    (out / "wordmark.png").unlink(missing_ok=True)


def tray() -> None:
    """The tray icon (Windows), the menu-bar icon (Mac: a black template the
    system tints) and Android's small notification icon (white)."""
    out = APP / "assets/tray"
    out.mkdir(parents=True, exist_ok=True)
    write_ico(out / "tray.ico", [tile(s, radius_frac=0.2) for s in (16, 20, 24, 32, 40, 48)])
    template = Image.new("RGBA", (44, 44), (0, 0, 0, 255))  # 22 pt at 2x
    template.putalpha(_glyph_mask(44, 0.92))
    template.save(out / "tray_mac.png", optimize=True)
    res = APP / "android/app/src/main/res"
    for density, scale in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        s = round(24 * scale)
        im = Image.new("RGBA", (s, s), (255, 255, 255, 255))
        im.putalpha(_glyph_mask(s, 0.86))
        folder = res / f"drawable-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        im.save(folder / "ic_stat_sidekick.png", optimize=True)


# ---------------------------------------------------------------- Nothing look
# Settings → Theme → Nothing switches the app icon (iPhone: an alternate
# icon; Android: a launcher alias; Mac: the Dock icon while running;
# Windows: the window and tray icons). The icon is "sk." in dots, white on
# black, the full stop in Nothing red (the same drawing as DotLogo in
# lib/ui/nothing.dart).

SK_DOTS = ["......X...", "......X...", ".XXXX.X..X", "X.....X.X.", ".XXX..XX..", "....X.X.X.", "XXXX..X..X"]
NOTHING_RED = (215, 25, 33)


def dot_logo(canvas: Image.Image, box: tuple, *, color=(255, 255, 255), red=True, frac=0.64) -> None:
    """Draws "sk." (12 dots wide, 7 high) centred in `box` (x, y, w, h)."""
    x, y, w, h = box
    cols = 12 if red else 10
    step = min(w * frac / cols, h * frac / 7)
    left = x + (w - step * cols) / 2
    top = y + (h - step * 7) / 2
    d = ImageDraw.Draw(canvas)
    for r, row in enumerate(SK_DOTS):
        for c, ch in enumerate(row):
            if ch == "X":
                cx, cy, rad = left + (c + 0.5) * step, top + (r + 0.5) * step, step * 0.44
                d.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=color + (255,))
    if red:
        cx, cy, rad = left + 11.5 * step, top + 6.5 * step, step * 0.5
        d.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=NOTHING_RED + (255,))


def dot_tile(size: int, *, radius_frac: float = 0.0, inset_frac: float = 0.0, full_bleed: bool = False) -> Image.Image:
    """White "sk." on a black tile, drawn at 4x and scaled down smoothly."""
    s = size * 4
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    inset = round(s * inset_frac)
    box = (inset, inset, s - 2 * inset, s - 2 * inset)
    d = ImageDraw.Draw(canvas)
    if full_bleed:
        d.rectangle((0, 0, s, s), fill=(0, 0, 0, 255))
    else:
        r = round(box[2] * radius_frac)
        d.rounded_rectangle((box[0], box[1], box[0] + box[2] - 1, box[1] + box[3] - 1), r, fill=(0, 0, 0, 255))
    dot_logo(canvas, box)
    return canvas.resize((size, size), Image.LANCZOS)


def nothing() -> None:
    # iPhone: the alternate icon (ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES).
    folder = APP / "ios/Runner/Assets.xcassets/AppIcon-Nothing.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    dot_tile(1024, full_bleed=True).convert("RGB").save(folder / "icon-1024.png", optimize=True)
    (folder / "Contents.json").write_text(
        json.dumps(
            {
                "images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
                "info": {"author": "xcode", "version": 1},
            },
            indent=2,
        )
        + "\n"
    )
    # Android: the launcher alias's icons (legacy and adaptive).
    res = APP / "android/app/src/main/res"
    for name, k in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        out = res / f"mipmap-{name}"
        out.mkdir(parents=True, exist_ok=True)
        dot_tile(round(48 * k), radius_frac=0.22).save(out / "ic_launcher_nothing.png", optimize=True)
        px = round(108 * k)
        fg = Image.new("RGBA", (px * 4, px * 4), (0, 0, 0, 0))
        dot_logo(fg, (0, 0, px * 4, px * 4), frac=0.64 * 66 / 108)
        fg.resize((px, px), Image.LANCZOS).save(out / "ic_launcher_nothing_foreground.png", optimize=True)
    (res / "mipmap-anydpi-v26/ic_launcher_nothing.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_nothing_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_nothing_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_nothing_foreground" />\n'
        "</adaptive-icon>\n"
    )
    # Mac (the Dock, while running) and Windows (window and taskbar), as
    # app assets; plus the default Windows icon, to switch back.
    icons = APP / "assets/icons"
    icons.mkdir(parents=True, exist_ok=True)
    dot_tile(512, radius_frac=0.225, inset_frac=0.1).save(icons / "nothing_dock.png", optimize=True)
    write_ico(icons / "nothing.ico", [dot_tile(s, radius_frac=0.2) for s in (16, 20, 24, 32, 40, 48, 64, 128, 256)])
    shutil.copyfile(APP / "windows/runner/resources/app_icon.ico", icons / "default.ico")
    # The tray (Windows) and the menu bar (Mac: a black template, no red).
    tray = APP / "assets/tray"
    write_ico(tray / "tray_nothing.ico", [dot_tile(s, radius_frac=0.2) for s in (16, 20, 24, 32, 40, 48)])
    template = Image.new("RGBA", (176, 176), (0, 0, 0, 0))
    dot_logo(template, (0, 0, 176, 176), color=(0, 0, 0), red=False, frac=0.95)
    template.resize((44, 44), Image.LANCZOS).save(tray / "tray_mac_nothing.png", optimize=True)


if __name__ == "__main__":
    import sys

    if sys.argv[1:] == ["nothing"]:  # only the Nothing look's icons
        nothing()
        print("Nothing icons written.")
        raise SystemExit
    tray()
    windows()
    android()
    macos()
    ios()
    icon_composer()
    website()
    in_app()
    nothing()  # after windows(): it copies the default .ico
    print("Icons written.")

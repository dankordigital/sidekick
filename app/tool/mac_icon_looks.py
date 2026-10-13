"""The Mac icon in each of macOS 26's icon looks: Default, Dark, Clear and
Tinted (System Settings → Appearance → Icon & widget style), as 1024 px
PNGs in website/mac-icons/, for the website, ads and the App Store.

    python app/tool/mac_icon_looks.py        # from the repo root

The app itself doesn't need these: its AppIcon.icon is rendered live by
macOS in whichever look is chosen. These are pictures of the same.
"""

from pathlib import Path

from PIL import Image, ImageChops

import make_icons as icons

OUT = icons.ROOT / "website" / "mac-icons"
SIZE = 1024


def look(top, bottom, ink_top, ink_bottom) -> Image.Image:
    icons.GLASS_TOP, icons.GLASS_BOTTOM = top, bottom
    icons.INK_TOP, icons.INK_BOTTOM = ink_top, ink_bottom
    return icons.glass_tile(SIZE, radius_frac=0.225, inset_frac=0.1)


def clear() -> Image.Image:
    """Clear: frosted, see-through glass, the "sk" a brighter white."""
    tile = look((250, 250, 255), (225, 228, 238), (255, 255, 255), (240, 242, 248))
    r, g, b, a = tile.split()
    glyph = icons._glyph_mask(SIZE, icons.MONOGRAM_FRAC * 0.8)
    # The glass lets 55% through; the letters stay mostly solid.
    a = ImageChops.lighter(a.point(lambda v: v * 0.45), ImageChops.multiply(a, glyph.point(lambda v: v * 0.9)))
    return Image.merge("RGBA", (r, g, b, a))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    default = (icons.GLASS_TOP, icons.GLASS_BOTTOM, icons.INK_TOP, icons.INK_BOTTOM)
    looks = {
        "default": look(*default),
        # Dark: a near-black tile, the "sk" in light lavender.
        "dark": look((52, 48, 68), (22, 20, 30), (226, 220, 255), (176, 164, 250)),
        "clear": clear(),
        # Tinted: greys only; macOS colours it with the chosen tint.
        "tinted": look((70, 70, 74), (34, 34, 38), (236, 236, 240), (196, 196, 202)),
    }
    icons.GLASS_TOP, icons.GLASS_BOTTOM, icons.INK_TOP, icons.INK_BOTTOM = default
    for name, im in looks.items():
        im.save(OUT / f"sidekick-mac-{name}.png", optimize=True)
        print(OUT / f"sidekick-mac-{name}.png")


if __name__ == "__main__":
    main()

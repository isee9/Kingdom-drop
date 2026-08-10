#!/usr/bin/env python3
"""Build the 1024x500 Google Play feature graphic.

Play requires this image and nothing substitutes for it — it is the banner at
the top of the store listing. It is composed here from art the project already
owns: the home background, the logo lockup and a row of board tiles.

    python3 tool/generate_feature_graphic.py

Writes ``store/feature_graphic.png``.

Two rules the layout obeys, both from Play's own guidance:

* **No text near the edges.** Play crops this image differently across
  surfaces, and on some of them the outer band is simply gone. Everything that
  matters sits inside the middle.
* **No claims, no fake buttons, no store badges.** Play rejects graphics that
  imitate a "Play" control or advertise a rating the app has not earned.

Requires: pillow
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "assets" / "art"
OUT = ROOT / "store"

W, H = 1024, 500


def load(rel: str) -> Image.Image:
    path = ART / rel
    if not path.exists():
        sys.exit(f"Missing {path}. Run tool/slice_art.py first.")
    return Image.open(path)


def cover(im: Image.Image, w: int, h: int) -> Image.Image:
    """Scale to fill w x h and centre-crop — never distort."""
    scale = max(w / im.width, h / im.height)
    resized = im.resize(
        (round(im.width * scale), round(im.height * scale)), Image.LANCZOS
    )
    left = (resized.width - w) // 2
    top = (resized.height - h) // 2
    return resized.crop((left, top, left + w, top + h))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    # Background: the home painting, cropped to a landscape band. The full image
    # is a tall portrait, so this takes the middle where the castle sits.
    bg = load("backgrounds/home.jpg").convert("RGB")
    canvas = cover(bg, W, H)

    # Darken and very slightly blur it. The logo has to be the subject, and a
    # sharp busy painting behind gold lettering fights it.
    canvas = canvas.filter(ImageFilter.GaussianBlur(1.4))
    canvas = Image.blend(canvas, Image.new("RGB", (W, H), (8, 16, 40)), 0.34)
    canvas = canvas.convert("RGBA")

    # A soft dark pool behind the logo so the lettering never sits on a bright
    # cloud. Drawn as a blurred ellipse rather than a hard shape.
    pool = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    from PIL import ImageDraw

    ImageDraw.Draw(pool).ellipse(
        (W * 0.02, H * 0.02, W * 0.66, H * 0.98), fill=(6, 12, 32, 165)
    )
    canvas.alpha_composite(pool.filter(ImageFilter.GaussianBlur(60)))

    # Logo on the left, inside the safe area.
    logo = load("branding/logo.png").convert("RGBA")
    logo_h = round(H * 0.74)
    logo_w = round(logo.width * logo_h / logo.height)
    logo = logo.resize((logo_w, logo_h), Image.LANCZOS)
    canvas.alpha_composite(logo, (round(W * 0.06), (H - logo_h) // 2))

    # Tiles on the right, arranged as a small descending stack so they read as
    # falling pieces rather than a colour swatch.
    tiles = [
        ("tiles/tile_red.png", 0.69, 0.23, 1.00),
        ("tiles/tile_gold.png", 0.78, 0.37, 0.93),
        ("tiles/tile_green.png", 0.69, 0.52, 0.86),
        ("tiles/tile_blue.png", 0.79, 0.65, 0.79),
        ("tiles/tile_purple.png", 0.70, 0.78, 0.72),
    ]
    base = round(H * 0.30)
    for rel, x, y, scale in tiles:
        tile = load(rel).convert("RGBA")
        side = round(base * scale)
        tile = tile.resize((side, side), Image.LANCZOS)

        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        shadow.paste(
            Image.new("RGBA", (side, side), (0, 0, 0, 120)),
            (round(W * x) - side // 2, round(H * y) - side // 2 + 10),
            tile,
        )
        canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(9)))
        canvas.alpha_composite(
            tile, (round(W * x) - side // 2, round(H * y) - side // 2)
        )

    dest = OUT / "feature_graphic.png"
    canvas.convert("RGB").save(dest, optimize=True)
    print(f"{dest.relative_to(ROOT)}  {W}x{H}  "
          f"{dest.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()

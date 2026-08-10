#!/usr/bin/env python3
"""Slice the Kingdom Drop art pack into the individual assets the app loads.

The supplied pack is a set of sprite sheets: tiles, icons, the logo and the
castle progression all share a sheet with a painted background. This script
cuts each element out, removes that background, trims to content and writes
optimised PNGs into ``assets/art/``.

Run it from the project root after replacing anything in ``art_src/``:

    python3 tool/slice_art.py

It is deterministic — running it twice produces the same bytes — so the
generated assets can be committed and regenerated on demand.

Requires: pillow, numpy, scipy   (pip install pillow numpy scipy)
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art_src"
OUT = ROOT / "assets" / "art"


# ---------------------------------------------------------------- utilities
def _flood_background(a: np.ndarray, tol: int) -> np.ndarray:
    """Mark every pixel reachable from the border without crossing an edge.

    The important detail is that each step compares a pixel to its *neighbour*,
    not to the seed. Comparing against the seed cannot follow a gradient, so a
    painted backdrop that shades from gold to black is only partly removed and
    the sprite keeps a halo. Walking neighbour to neighbour follows the shading
    all the way in and stops at the sprite's hard edge, which also strips the
    soft glow the artist painted around each element.
    """
    h, w, _ = a.shape
    seen = np.zeros((h, w), bool)
    stack: list[tuple[int, int]] = []

    for x in range(w):
        for y in (0, h - 1):
            if not seen[y, x]:
                seen[y, x] = True
                stack.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if not seen[y, x]:
                seen[y, x] = True
                stack.append((y, x))

    while stack:
        y, x = stack.pop()
        here = a[y, x]
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx]:
                if int(np.abs(a[ny, nx] - here).sum()) <= tol:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
    return seen


def cutout(im: Image.Image, box, pad: int = 8, tol: int = 16,
           erode: int = 1, keep_fraction: float = 0.04) -> Image.Image:
    """Crop ``box`` out of ``im`` and make the painted background transparent."""
    x0, y0, x1, y1 = box
    crop = im.crop((x0 - pad, y0 - pad, x1 + pad, y1 + pad)).convert("RGB")
    a = np.asarray(crop).astype(np.int16)

    solid = ndimage.binary_fill_holes(~_flood_background(a, tol))

    # Drop stray islands of background the fill could not reach, keeping any
    # component that is a meaningful fraction of the biggest one — some sprites
    # legitimately have detached parts, like the loose coins beside a chest.
    labels, count = ndimage.label(solid)
    if count > 1:
        sizes = ndimage.sum(solid, labels, range(1, count + 1))
        cutoff = sizes.max() * keep_fraction
        solid = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= cutoff])

    if erode:
        # Pull the edge in a pixel to drop the halo of blended background
        # pixels that would otherwise fringe the sprite.
        solid = ndimage.binary_erosion(solid, iterations=erode)

    alpha = solid.astype(np.uint8) * 255
    out = Image.fromarray(
        np.dstack([np.asarray(crop), alpha]).astype(np.uint8), "RGBA"
    )
    bbox = out.getbbox()
    return out.crop(bbox) if bbox else out


def to_square(im: Image.Image, size: int) -> Image.Image:
    """Pad to a square then scale, so nothing is stretched out of proportion."""
    side = max(im.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return canvas.resize((size, size), Image.LANCZOS)


def fit_width(im: Image.Image, width: int) -> Image.Image:
    height = round(im.height * width / im.width)
    return im.resize((width, height), Image.LANCZOS)


def save(im: Image.Image, rel: str) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)
    kb = path.stat().st_size / 1024
    print(f"  {rel:44s} {im.size[0]:>4}x{im.size[1]:<4} {kb:>7.1f} KB")


def sheet(rel: str) -> Image.Image:
    path = SRC / rel
    if not path.exists():
        sys.exit(f"Missing source art: {path}\nPut the art pack in art_src/.")
    return Image.open(path)


# -------------------------------------------------------------------- tiles
# Board block faces, in the order AppArt.tiles and AppColors.blocks expect.
# Boxes were found by locating the dark outlines on the sheet; see the git
# history of this file for the detection snippet.
#
# The sheet holds a sixth block at (816, 930, 961, 1080), a red-orange. It is
# deliberately not cut: its hue sits within a few degrees of the red one, and
# two near-identical colours on a 7x7 board are a legibility problem rather
# than variety. Five well-separated hues is the palette.
TILE_BOXES = {
    "red": (54, 286, 193, 426),
    "gold": (245, 286, 384, 418),
    "green": (438, 286, 577, 430),
    "blue": (630, 286, 770, 418),
    "purple": (822, 286, 963, 418),
}

TILE_PX = 128


def slice_tiles() -> None:
    print("tiles")
    im = sheet("tiles/puzzle_tiles.png")
    for name, box in TILE_BOXES.items():
        save(to_square(cutout(im, box, pad=6, tol=20), TILE_PX),
             f"tiles/tile_{name}.png")


# -------------------------------------------------------------------- icons
# Three columns by three rows, plus the mystery chest centred underneath.
ICON_BOXES = {
    "coins": (60, 110, 340, 300),
    "crown": (395, 95, 640, 305),
    "xp": (700, 95, 950, 310),
    "chest": (55, 405, 350, 665),
    "calendar": (400, 400, 630, 665),
    "hammer": (690, 400, 960, 670),
    "bomb": (75, 745, 320, 1005),
    "shuffle": (390, 760, 660, 990),
    "second_chance": (700, 760, 960, 1000),
    "mystery_chest": (400, 1050, 660, 1320),
}

ICON_PX = 144


def slice_icons() -> None:
    print("icons")
    im = sheet("icons/game_icons.png")
    for name, box in ICON_BOXES.items():
        # Icons sit on a warm gradient with a soft glow, so a wider tolerance
        # is needed than for the hard-edged tiles.
        save(to_square(cutout(im, box, pad=12, tol=14), ICON_PX),
             f"icons/{name}.png")


# ------------------------------------------------------------------ kingdom
# Three castle states on one sheet: ruined, part-restored, fully restored.
CASTLE_BOXES = [
    ("ruined", (40, 330, 520, 690)),
    ("partial", (520, 250, 1010, 700)),
    ("restored", (1030, 240, 1520, 700)),
]

CASTLE_W = 560


def slice_castles() -> None:
    print("kingdoms")
    im = sheet("kingdoms/forgotten_keep_progression_v2.png")
    for name, box in CASTLE_BOXES:
        save(fit_width(cutout(im, box, pad=14, tol=13), CASTLE_W),
             f"kingdoms/keep_{name}.png")


# ----------------------------------------------------------------- branding
def slice_branding() -> None:
    print("branding")
    logo = cutout(sheet("branding/kingdom_drop_logo.png"),
                  (95, 270, 935, 1010), pad=14, tol=16)
    save(fit_width(logo, 720), "branding/logo.png")

    icon = sheet("branding/app_icon_crown.png").convert("RGBA")
    save(icon.resize((1024, 1024), Image.LANCZOS), "branding/app_icon.png")


# -------------------------------------------------------------- backgrounds
# Full-bleed portrait art. Kept large enough for a 3x phone but recompressed,
# because the originals are ~2 MB each and four of them would dominate the
# download.
BACKGROUNDS = {
    "home": "backgrounds/home_castle_sunset.png",
    "game": "backgrounds/gameplay_twilight.png",
    "kingdom": "backgrounds/castle_mountains.png",
    "menu": "backgrounds/night_castle_ui_backdrop.png",
}

BG_W = 828


def slice_backgrounds() -> None:
    print("backgrounds")
    for name, rel in BACKGROUNDS.items():
        im = sheet(rel).convert("RGB")
        im = fit_width(im, BG_W)
        path = OUT / f"backgrounds/{name}.jpg"
        path.parent.mkdir(parents=True, exist_ok=True)
        # JPEG: these are photographic paintings with no transparency, and it
        # is roughly a fifth of the PNG size at quality no one can see.
        im.save(path, "JPEG", quality=86, optimize=True, progressive=True)
        kb = path.stat().st_size / 1024
        print(f"  backgrounds/{name}.jpg{'':27s} {im.size[0]:>4}x{im.size[1]:<4} {kb:>7.1f} KB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    slice_tiles()
    slice_icons()
    slice_castles()
    slice_branding()
    slice_backgrounds()
    total = sum(p.stat().st_size for p in OUT.rglob("*") if p.is_file())
    print(f"\nTotal in assets/art: {total / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()

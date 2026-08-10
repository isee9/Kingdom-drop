#!/usr/bin/env python3
"""Turn raw app captures into Google Play phone screenshots.

Captures come out of the app at 960x1920 — a 1:2 ratio, which sits right on
Play's limit. This pads each one to 1080x1920 (a clean 9:16) using the app's own
background navy, so the border reads as part of the design rather than as bars,
and writes them into ``store/screenshots/``.

    python3 tool/pack_screenshots.py <folder-of-captures>

Requires: pillow
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "store" / "screenshots"

TARGET = (1080, 1920)

# AppColors.background, so the padding is the same navy the app itself draws.
BACKDROP = (10, 20, 46)

# Capture filename -> the store's ordering and a name that says what it shows.
# The order matters more than most people expect: hardly anyone swipes past the
# second one.
ORDER = {
    "05_dragging": "1_drag_drop_clear",
    "02_kingdom": "2_build_your_kingdom",
    "04_board": "3_fill_the_board",
    "06_bomb": "4_powerful_boosters",
    "03_daily": "5_return_every_day",
    "07_summary": "6_how_high_can_you_score",
}


def pack(src: Path, dest: Path) -> None:
    im = Image.open(src).convert("RGB")

    # Fit inside the target without ever distorting.
    scale = min(TARGET[0] / im.width, TARGET[1] / im.height)
    if scale != 1:
        im = im.resize(
            (round(im.width * scale), round(im.height * scale)), Image.LANCZOS
        )

    canvas = Image.new("RGB", TARGET, BACKDROP)
    canvas.paste(im, ((TARGET[0] - im.width) // 2, (TARGET[1] - im.height) // 2))
    canvas.save(dest, optimize=True)
    print(f"  {dest.name:34s} {TARGET[0]}x{TARGET[1]}  "
          f"{dest.stat().st_size / 1024:6.0f} KB")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    source = Path(sys.argv[1])
    if not source.is_dir():
        sys.exit(f"Not a folder: {source}")

    OUT.mkdir(parents=True, exist_ok=True)
    for capture, name in ORDER.items():
        src = source / f"{capture}.png"
        if not src.exists():
            print(f"  MISSING {src.name} — skipped")
            continue
        pack(src, OUT / f"{name}.png")


if __name__ == "__main__":
    main()

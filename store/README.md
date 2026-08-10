# store/ — listing graphics

Everything Google Play needs as an image, ready to upload. The listing *text*
lives in `../STORE_LISTING.md`.

| File | What it is | Where it goes |
| --- | --- | --- |
| `feature_graphic.png` | 1024×500 banner | Play Console → Store listing → Graphics → Feature graphic |
| `app_icon_512.png` | 512×512 icon | Play Console → Store listing → Graphics → App icon |
| `screenshots/*.png` | Six 1080×1920 phone screenshots | Play Console → Store listing → Graphics → Phone screenshots |

Upload the screenshots **in filename order** — they are numbered for it. The
first two do most of the work; hardly anyone swipes past them.

## How these were made

All three are generated from art already in the repository, so they can be
rebuilt after any visual change:

```bash
python3 tool/generate_feature_graphic.py     # feature_graphic.png
python3 tool/pack_screenshots.py <captures>  # screenshots/
```

The screenshots are real captures of the release build — no mockups, no
composited devices, nothing shown that the game does not do. They were taken at
960×1920 and padded to 1080×1920 with the app's own background navy, because
Play's aspect-ratio limit is 2:1 and a 960×1920 capture sits exactly on it.

## What is still missing

**iOS.** The App Store wants its own sizes and they must come off a real device
or the iOS Simulator:

- 6.7" iPhone — 1290×2796. **Required.**
- 6.5" iPhone — 1242×2688. Required if you support older devices.
- 13" iPad — 2064×2752. Required only if you offer the app on iPad.

The App Store takes its icon from the binary, so there is nothing to upload
there.

**Captions.** These screenshots are plain captures with no text burned in.
Games usually convert better with a short caption across the top of each one —
`STORE_LISTING.md` suggests wording. If you add them, keep the text in the top
third: some store placements crop the bottom.

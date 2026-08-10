# Audio

These files are **generated**, not recorded or licensed. `tool/generate_audio.py`
synthesises every one of them from scratch — sine partials, filtered noise and a
Karplus-Strong plucked string — so the project carries no third-party audio
rights, the same way `assets/art/` carries no third-party artwork.

Regenerate after changing anything in that script:

```bash
python3 tool/generate_audio.py     # needs numpy and ffmpeg
```

It is deterministic: the noise is seeded, so running it twice produces the same
sound. The whole set is about 440 KB.

## Effects

| Filename | Plays when |
| --- | --- |
| `block_pickup.mp3` | A piece is lifted out of the tray |
| `block_placed.mp3` | A piece lands on the board |
| `block_invalid.mp3` | A drop is refused |
| `line_cleared.mp3` | One row, column or region clears |
| `combo.mp3` | Two or more clear at once |
| `coin.mp3` | Coins are awarded |
| `crown.mp3` | Crowns are awarded |
| `level_up.mp3` | The player levels up |
| `kingdom_upgrade.mp3` | A kingdom repair completes |
| `chest.mp3` | A chest is opened |
| `game_over.mp3` | No moves remain |
| `button_tap.mp3` | Any button press |

## Music

| Filename | Notes |
| --- | --- |
| `theme_loop.mp3` | 23 s, A minor, looped at 35% volume; stopped when the app backgrounds |

## Design notes

- **Levels are set per sound, not normalised flat.** A combo has to feel bigger
  than a single clear without simply being louder, so it is longer, brighter and
  has more notes. The button tap is the quietest thing in the game because it
  fires constantly.
- **Effects are short** — most are under 400 ms. The game is fast, and a long
  tail overlaps the next placement.
- **MP3, not OGG.** iOS will not play Ogg Vorbis. The cost is that MP3 carries a
  few milliseconds of encoder padding, so the music loop has a very small seam
  at the join. At 35% volume under a 23-second pad piece it is not audible in
  practice; if it ever bothers you, an M4A/AAC re-encode is the fix.
- **The game still runs with this folder emptied.** `AudioService` checks the
  asset manifest at startup and never touches the platform audio plugin when
  there is nothing to play.

## Replacing this with licensed audio

Drop correctly named files in and they are picked up with no code change. To
change a filename, edit the `_assets` map in `lib/audio/audio_service.dart`. If
you buy or licence a pack, record the licence here so the provenance of every
asset in the project stays written down.

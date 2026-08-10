# Audio slots

**This folder is intentionally empty of audio.** The game runs silently and
correctly with no files here — `AudioService` checks the asset manifest at
startup and never touches the platform audio plugin when there is nothing to
play.

To add sound, drop correctly named files into this folder. They are picked up
with no code change.

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
| `theme_loop.mp3` | Looped at 35% volume; stopped when the app backgrounds |

## Guidance

- **Format:** MP3 or OGG. Keep effects short (under ~400 ms) — the game is
  fast and a long tail will overlap the next placement.
- **Loudness:** normalise effects to roughly the same level. `combo.mp3` should
  read as bigger than `line_cleared.mp3` without simply being louder.
- **Licensing:** use audio you have the right to ship. Nothing in this project
  currently carries any third-party licence, and it is worth keeping it that
  way. If you buy or licence a pack, record the licence here.
- **Size:** the whole set should comfortably fit in a couple of megabytes.
  Anything larger is worth compressing.

To change a filename, edit the `_assets` map in `lib/audio/audio_service.dart`.

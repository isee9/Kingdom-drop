# Image assets

Kingdom Drop draws all of its artwork in code, so this folder holds only
generated output rather than source art.

| File | What it is |
| --- | --- |
| `app_icon_1024.png` | 1024×1024 master of the app icon, for store listings. Generated — do not hand-edit. |

Regenerate it, along with every Android and iOS icon size, with:

```bash
flutter run -d <any device> -t tool/generate_icons.dart
```

## Where the art actually lives

| Thing | File |
| --- | --- |
| Palette | `lib/theme/app_colors.dart` |
| Blocks | `lib/game/widgets/block_painter.dart` |
| Crown and coin | `lib/widgets/game_icons.dart` |
| Logo / icon mark | `lib/widgets/kingdom_logo.dart` |
| Kingdom scenes | `lib/screens/kingdom/kingdom_view.dart` |

If you commission finished artwork, put the files here and swap the relevant
painter for an `Image.asset`. Every call site takes a widget, so nothing else
has to change.

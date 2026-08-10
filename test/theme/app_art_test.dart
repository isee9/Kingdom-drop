import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/theme/app_art.dart';
import 'package:kingdom_drop/theme/app_colors.dart';

/// Guards on the painted art layer.
///
/// These are cheap but they cover the failures that are otherwise invisible
/// until someone looks at a screen: a path that no longer points at a file, a
/// tile list that has drifted out of step with the colour palette, or a castle
/// state that never appears because the thresholds overlap.
void main() {
  group('Asset paths', () {
    test('every declared asset exists on disk', () {
      // A typo in a path does not fail the build, does not fail analysis, and
      // does not throw at runtime — Image.asset just quietly renders the
      // fallback. This is the only thing that catches it.
      final List<String> declared = <String>[
        ...AppArt.tiles,
        AppArt.logo,
        AppArt.appIcon,
        AppArt.backgroundHome,
        AppArt.backgroundGame,
        AppArt.backgroundKingdom,
        AppArt.backgroundMenu,
        AppArt.keepRuined,
        AppArt.keepPartial,
        AppArt.keepRestored,
        AppArt.iconCoins,
        AppArt.iconCrown,
        AppArt.iconXp,
        AppArt.iconChest,
        AppArt.iconMysteryChest,
        AppArt.iconCalendar,
        AppArt.iconHammer,
        AppArt.iconBomb,
        AppArt.iconShuffle,
        AppArt.iconSecondChance,
      ];

      final List<String> missing = declared
          .where((String path) => !File(path).existsSync())
          .toList();

      expect(
        missing,
        isEmpty,
        reason:
            'Declared in AppArt but not in the repository. Re-run '
            'tool/slice_art.py, or fix the path.',
      );
    });

    test('every asset lives under assets/art/', () {
      // pubspec.yaml declares the assets/art/ subfolders, so anything outside
      // them would not be bundled even though the file exists in the checkout.
      for (final String path in AppArt.preloadable) {
        expect(path, startsWith('assets/art/'));
      }
    });

    test('the preload list has no duplicates', () {
      expect(AppArt.preloadable.toSet().length, AppArt.preloadable.length);
    });

    test('a background is declared for every scene', () {
      for (final ArtScene scene in ArtScene.values) {
        expect(File(AppArt.background(scene)).existsSync(), isTrue);
      }
      // Four distinct paintings, not the same one four times.
      expect(
        ArtScene.values.map(AppArt.background).toSet().length,
        ArtScene.values.length,
      );
    });
  });

  group('Tiles', () {
    test('are index-aligned with the block palette', () {
      // BlockPainting looks up ArtCache.tile(i) with the same index it uses for
      // AppColors.blocks[i]. If these lengths ever diverge the two wrap at
      // different points and a block's particles stop matching its face.
      expect(AppArt.tiles.length, AppColors.blocks.length);
    });

    test('a colour index wraps instead of throwing', () {
      expect(AppArt.tile(0), AppArt.tiles.first);
      expect(AppArt.tile(AppArt.tiles.length), AppArt.tiles.first);
      expect(AppArt.tile(-1), isNotNull);
    });

    test('each tile is a distinct file', () {
      expect(AppArt.tiles.toSet().length, AppArt.tiles.length);
    });
  });

  group('Castle states', () {
    test('map five upgrades onto three pictures', () {
      expect(AppArt.keepFor(0), AppArt.keepRuined);
      expect(AppArt.keepFor(1), AppArt.keepRuined);
      expect(AppArt.keepFor(2), AppArt.keepPartial);
      expect(AppArt.keepFor(3), AppArt.keepPartial);
      expect(AppArt.keepFor(4), AppArt.keepPartial);
      expect(AppArt.keepFor(5), AppArt.keepRestored);
    });

    test('all three states are reachable', () {
      final Set<String> seen = <String>{
        for (int done = 0; done <= 5; done++) AppArt.keepFor(done),
      };
      expect(seen, hasLength(3));
    });

    test('a completed realm never regresses past restored', () {
      expect(AppArt.keepFor(6), AppArt.keepRestored);
      expect(AppArt.keepFor(99), AppArt.keepRestored);
    });
  });

  group('ArtCache', () {
    setUp(ArtCache.resetForTest);
    tearDown(ArtCache.resetForTest);

    test('hands out nulls before preload, so painters fall back', () {
      expect(ArtCache.ready, isFalse);
      for (int i = 0; i < AppArt.tiles.length; i++) {
        expect(ArtCache.tile(i), isNull);
      }
    });

    test('tile lookup wraps rather than throwing on any index', () {
      expect(() => ArtCache.tile(-7), returnsNormally);
      expect(() => ArtCache.tile(1000), returnsNormally);
    });
  });
}

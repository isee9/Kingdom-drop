import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Every path into `assets/art/`, in one place.
///
/// The art itself is sliced out of the source sheets in `art_src/` by
/// `tool/slice_art.py`. Nothing else in the app spells one of these paths out —
/// swapping in a new pack means re-running the slicer and, at most, editing
/// this file.
///
/// Everything here degrades: each widget that loads a painted asset keeps the
/// code-drawn version as a fallback, so the app still builds and runs with the
/// whole `assets/art/` folder deleted. That is not defensive paranoia — it is
/// what lets the widget tests run without an asset bundle.
abstract final class AppArt {
  static const String _root = 'assets/art';

  // ---------------------------------------------------------------- branding
  /// The full logo lockup: crown, wordmark and the tagline ribbon.
  ///
  /// The tagline is *painted into* this image, so any screen showing the logo
  /// must not also render the tagline as text.
  static const String logo = '$_root/branding/logo.png';

  /// Square store/launcher icon at full resolution.
  static const String appIcon = '$_root/branding/app_icon.png';

  // ------------------------------------------------------------- backgrounds
  static const String backgroundHome = '$_root/backgrounds/home.jpg';
  static const String backgroundGame = '$_root/backgrounds/game.jpg';
  static const String backgroundKingdom = '$_root/backgrounds/kingdom.jpg';
  static const String backgroundMenu = '$_root/backgrounds/menu.jpg';

  static String background(ArtScene scene) => switch (scene) {
    ArtScene.home => backgroundHome,
    ArtScene.game => backgroundGame,
    ArtScene.kingdom => backgroundKingdom,
    ArtScene.menu => backgroundMenu,
  };

  // ------------------------------------------------------------------- tiles
  /// Block faces, index-aligned with [AppColors.blocks].
  ///
  /// The pack supplies five clearly separable hues. It does contain a sixth
  /// block, but it is a red-orange that sits within a few degrees of the red
  /// one — two colours that close together on a 7×7 board are a legibility
  /// problem, not variety, so the palette is five. Block colour is decoration:
  /// the engine never matches on it, so this costs nothing but a rebalanced
  /// [AppColors.blocks].
  static const List<String> tiles = <String>[
    '$_root/tiles/tile_red.png',
    '$_root/tiles/tile_gold.png',
    '$_root/tiles/tile_green.png',
    '$_root/tiles/tile_blue.png',
    '$_root/tiles/tile_purple.png',
  ];

  static String tile(int colorIndex) => tiles[colorIndex.abs() % tiles.length];

  // ------------------------------------------------------------------- icons
  static const String iconCoins = '$_root/icons/coins.png';
  static const String iconCrown = '$_root/icons/crown.png';
  static const String iconXp = '$_root/icons/xp.png';
  static const String iconChest = '$_root/icons/chest.png';
  static const String iconMysteryChest = '$_root/icons/mystery_chest.png';
  static const String iconCalendar = '$_root/icons/calendar.png';
  static const String iconHammer = '$_root/icons/hammer.png';
  static const String iconBomb = '$_root/icons/bomb.png';
  static const String iconShuffle = '$_root/icons/shuffle.png';
  static const String iconSecondChance = '$_root/icons/second_chance.png';

  // ---------------------------------------------------------------- kingdoms
  /// The Forgotten Keep in three states. See [keepFor] for the mapping.
  static const String keepRuined = '$_root/kingdoms/keep_ruined.png';
  static const String keepPartial = '$_root/kingdoms/keep_partial.png';
  static const String keepRestored = '$_root/kingdoms/keep_restored.png';

  /// Which castle to show for a realm with [upgradesDone] of five upgrades
  /// bought.
  ///
  /// Three pieces of art across five upgrades, weighted so the player sees a
  /// change early (the second purchase) and the last one is the payoff for
  /// finishing the realm.
  static String keepFor(int upgradesDone) {
    if (upgradesDone >= 5) return keepRestored;
    if (upgradesDone >= 2) return keepPartial;
    return keepRuined;
  }

  /// Every asset worth having decoded before the first frame.
  static const List<String> preloadable = <String>[
    ...tiles,
    logo,
    backgroundHome,
    backgroundGame,
    backgroundKingdom,
    backgroundMenu,
    keepRuined,
    keepPartial,
    keepRestored,
  ];
}

/// Which painted backdrop a screen sits on.
enum ArtScene {
  /// Castle at sunset — the home screen.
  home,

  /// Twilight, low contrast in the middle where the board goes.
  game,

  /// Castle and mountains — the kingdom and the intro.
  kingdom,

  /// Darkest of the four, for menus, the shop and the run summary.
  menu,
}

/// Decoded images for the things that are painted by a [CustomPainter].
///
/// Widgets can just use `Image.asset`, but a painter needs a `ui.Image` in
/// hand, synchronously, inside `paint`. This decodes the tile faces up front so
/// the board never paints a half-loaded frame, and hands out nulls if anything
/// failed — [BlockPainting] falls back to drawing the block itself.
abstract final class ArtCache {
  static final List<ui.Image?> _tiles = List<ui.Image?>.filled(
    AppArt.tiles.length,
    null,
  );

  static bool _loaded = false;

  /// True once [preload] has finished, whether or not it found any art.
  static bool get ready => _loaded;

  /// The block face for a colour index, or null if it is not available.
  static ui.Image? tile(int colorIndex) =>
      _tiles[colorIndex.abs() % _tiles.length];

  /// Decodes the tiles and warms the image cache for the backgrounds.
  ///
  /// Called once from `main` before `runApp`. A failure here is never fatal:
  /// the whole point of the fallbacks is that a missing pack degrades the look
  /// rather than the app.
  static Future<void> preload() async {
    if (_loaded) return;

    for (int i = 0; i < AppArt.tiles.length; i++) {
      _tiles[i] = await _decode(AppArt.tiles[i]);
    }

    // Backgrounds, the logo and the castles are drawn by ordinary Image
    // widgets, so they only need to be in Flutter's image cache. Resolving the
    // provider is the context-free equivalent of `precacheImage`, and it uses
    // the same cache key `Image.asset` will look up.
    for (final String path in AppArt.preloadable) {
      if (AppArt.tiles.contains(path)) continue;
      AssetImage(path).resolve(ImageConfiguration.empty);
    }

    _loaded = true;
  }

  static Future<ui.Image?> _decode(String path) async {
    try {
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromAsset(
        path,
      );
      final ui.Codec codec = await ui.instantiateImageCodecWithSize(buffer);
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } on Object {
      // Missing or corrupt asset. Painters fall back to drawing the block.
      return null;
    }
  }

  /// Test seam: forget everything so a test can run [preload] against a
  /// different bundle.
  @visibleForTesting
  static void resetForTest() {
    _loaded = false;
    for (int i = 0; i < _tiles.length; i++) {
      _tiles[i] = null;
    }
  }
}

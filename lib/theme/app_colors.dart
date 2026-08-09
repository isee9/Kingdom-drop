import 'package:flutter/material.dart';

/// The single source of truth for every colour in Kingdom Drop.
///
/// Nothing in the app should construct a raw [Color] inline. If a new shade is
/// needed, add it here so the palette stays coherent and can be re-skinned.
///
/// The palette is an original "twilight fantasy" scheme: deep indigo/violet
/// grounds, warm gold for reward moments, and a saturated but not neon set of
/// block colours chosen to stay distinguishable for the most common forms of
/// colour vision deficiency (they differ in lightness as well as hue).
abstract final class AppColors {
  // ---------------------------------------------------------------- brand
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF4B3FC4);
  static const Color primaryLight = Color(0xFF9B8CFF);

  static const Color secondary = Color(0xFF22C3A6);
  static const Color secondaryDark = Color(0xFF14907B);

  // ------------------------------------------------------------ surfaces
  /// Deepest background, used behind everything.
  static const Color background = Color(0xFF15122B);
  static const Color backgroundAlt = Color(0xFF1E1940);

  /// Raised cards and panels.
  static const Color surface = Color(0xFF262048);
  static const Color surfaceHigh = Color(0xFF322A5C);
  static const Color surfaceLow = Color(0xFF1A1636);

  /// Hairline dividers and card borders.
  static const Color border = Color(0x1AFFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);

  // ------------------------------------------------------------------ ink
  static const Color textPrimary = Color(0xFFF6F4FF);
  static const Color textSecondary = Color(0xFFB9B2DC);
  static const Color textMuted = Color(0xFF8078A8);
  static const Color textOnGold = Color(0xFF4A2F00);

  // ------------------------------------------------------------- semantic
  static const Color success = Color(0xFF3DD68C);
  static const Color warning = Color(0xFFFFB443);
  static const Color danger = Color(0xFFFF5C7A);
  static const Color info = Color(0xFF56A9FF);

  // ------------------------------------------------------------ currency
  static const Color gold = Color(0xFFFFC53D);
  static const Color goldDark = Color(0xFFE09B00);
  static const Color crown = Color(0xFFFF9F1C);
  static const Color crownDark = Color(0xFFD97706);

  // --------------------------------------------------------------- board
  /// Empty cell fill.
  static const Color boardCell = Color(0xFF2C2555);

  /// Board backing plate behind the cells.
  static const Color boardBase = Color(0xFF201B42);

  /// Divider drawn between the 3x3 regions.
  static const Color boardRegionLine = Color(0x3DFFFFFF);

  /// Ghost preview for a legal drop.
  static const Color previewValid = Color(0x8859F0B0);

  /// Ghost preview for an illegal drop.
  static const Color previewInvalid = Color(0x99FF5C7A);

  /// Highlight for rows/columns/regions that will clear on this drop.
  static const Color previewClear = Color(0x66FFC53D);

  /// Block palette. Shapes pick one of these by index so a placed block keeps
  /// its colour for the life of the board.
  static const List<Color> blocks = <Color>[
    Color(0xFF7C6BFF), // violet
    Color(0xFF2FC6F5), // sky
    Color(0xFF3DD68C), // mint
    Color(0xFFFFC53D), // gold
    Color(0xFFFF7A5C), // coral
    Color(0xFFFF6BC1), // orchid
  ];

  /// Slightly darker companion used for the bevel under each block face.
  static List<Color> get blockShadows =>
      blocks.map(_darken).toList(growable: false);

  static Color _darken(Color c) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
  }

  // ------------------------------------------------------------ gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF241E4E), AppColors.background],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF8B7BFF), AppColors.primaryDark],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFDE7A), AppColors.goldDark],
  );

  static const LinearGradient playGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF3DD68C), Color(0xFF12A06E)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF7D95), Color(0xFFD32F4E)],
  );
}

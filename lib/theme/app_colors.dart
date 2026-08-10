import 'package:flutter/material.dart';

/// The single source of truth for every colour in Kingdom Drop.
///
/// Nothing in the app should construct a raw [Color] inline. If a new shade is
/// needed, add it here so the palette stays coherent and can be re-skinned.
///
/// The scheme is "royal night": deep navy grounds, warm gold for anything the
/// player earns or presses, and a saturated block set. Golds are used sparingly
/// — on frames, currency and calls to action — because gold everywhere reads as
/// cheap rather than premium.
///
/// Block colours differ in lightness as well as hue, so they stay tellable
/// apart for the most common forms of colour vision deficiency.
abstract final class AppColors {
  // ---------------------------------------------------------------- brand
  static const Color primary = Color(0xFF3D6FD4);
  static const Color primaryDark = Color(0xFF23448F);
  static const Color primaryLight = Color(0xFF6E9BFF);

  static const Color secondary = Color(0xFF22C3A6);
  static const Color secondaryDark = Color(0xFF12907B);

  // ------------------------------------------------------------ surfaces
  /// Deepest background, behind everything.
  static const Color background = Color(0xFF0A142E);
  static const Color backgroundAlt = Color(0xFF122246);

  /// Raised panels.
  static const Color surface = Color(0xFF16294F);
  static const Color surfaceHigh = Color(0xFF1F3868);
  static const Color surfaceLow = Color(0xFF0F1D3C);

  /// Recessed wells: board backing, inset rows.
  static const Color surfaceSunken = Color(0xFF091531);

  static const Color border = Color(0x1FFFFFFF);
  static const Color borderStrong = Color(0x3DFFFFFF);

  // ------------------------------------------------------------------ ink
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB6C6E8);
  static const Color textMuted = Color(0xFF7B8DB8);
  static const Color textOnGold = Color(0xFF5A3606);

  /// Outline drawn around display text, which is what gives casual-game
  /// lettering its punch against a busy background.
  static const Color textOutline = Color(0xFF06102A);

  // ------------------------------------------------------------- semantic
  static const Color success = Color(0xFF43D17A);
  static const Color successDark = Color(0xFF1E9B4F);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFF2534D);
  static const Color dangerDark = Color(0xFFB32A28);
  static const Color info = Color(0xFF3FA9F5);

  // ------------------------------------------------------------ currency
  static const Color gold = Color(0xFFFFC33A);
  static const Color goldLight = Color(0xFFFFE9A0);
  static const Color goldDark = Color(0xFFC9820A);

  /// Deep bronze used for the outline under gold, so gold reads as metal
  /// rather than as flat yellow.
  static const Color goldEdge = Color(0xFF7A4B05);

  static const Color crown = Color(0xFFFFC33A);
  static const Color crownDark = Color(0xFFC9820A);

  // --------------------------------------------------------------- board
  /// Empty cell fill.
  static const Color boardCell = Color(0xFF1B2F58);

  /// Board backing plate behind the cells.
  static const Color boardBase = Color(0xFF0C1937);

  /// Frame around the board.
  static const Color boardFrame = Color(0xFF2B4880);

  /// Ghost preview for a legal drop.
  static const Color previewValid = Color(0x8843D17A);

  /// Ghost preview for an illegal drop.
  static const Color previewInvalid = Color(0x99F2534D);

  /// Highlight for lines that will clear on this drop.
  static const Color previewClear = Color(0x70FFC33A);

  /// Block palette. A shape keeps its colour for the life of the board.
  ///
  /// These are sampled from the painted tile faces in `assets/art/tiles/` and
  /// are index-aligned with [AppArt.tiles], so the clear-burst particles, the
  /// tray and the board all agree on what "colour 2" is even though the board
  /// draws the painting and the particles draw the colour.
  static const List<Color> blocks = <Color>[
    Color(0xFFE02A20), // red
    Color(0xFFF5A800), // gold
    Color(0xFF55A310), // green
    Color(0xFF1478E0), // blue
    Color(0xFF9C3ECB), // purple
  ];

  static Color _shift(Color c, double amount) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Lighter face used for the top of a block's bevel.
  static Color blockTop(int index) =>
      _shift(blocks[index % blocks.length], 0.14);

  /// Darker face used for the bottom lip of a block.
  static Color blockEdge(int index) =>
      _shift(blocks[index % blocks.length], -0.20);

  // ------------------------------------------------------------ gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF17305F), Color(0xFF0A142E)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF5C8DEE), AppColors.primaryDark],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFFE07A), Color(0xFFF0A81B)],
  );

  static const LinearGradient playGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF6BE895), Color(0xFF1E9B4F)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFF8A72), Color(0xFFB32A28)],
  );

  /// Panel interior: a subtle vertical lift so a card is not a flat rectangle.
  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF1E3767), Color(0xFF13254A)],
  );
}

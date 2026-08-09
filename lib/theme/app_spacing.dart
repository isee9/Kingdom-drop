/// Spacing and radius scale. Using a fixed scale everywhere is what keeps the
/// layout from drifting into inconsistent margins.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Minimum tap target. Anything interactive should meet this.
  static const double minTapTarget = 48;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  /// Corner radius of an individual board block, as a fraction of cell size.
  static const double blockFraction = 0.22;
}

abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);

  /// How long a line-clear takes end to end. Deliberately short — the clear has
  /// to read as punchy, not as a cutscene.
  static const Duration clear = Duration(milliseconds: 300);

  static const Duration screenTransition = Duration(milliseconds: 320);
}

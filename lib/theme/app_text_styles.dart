import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale.
///
/// [displayFontFamily] is null so the app uses the platform's own UI font,
/// which looks correct on both Android and iOS out of the box. To ship a custom
/// display face, add it to pubspec.yaml and set this to its family name.
abstract final class AppTextStyles {
  static const String? displayFontFamily = null;

  static const TextStyle logo = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 42,
    fontWeight: FontWeight.w900,
    letterSpacing: 3,
    height: 1.05,
    color: AppColors.textPrimary,
  );

  static const TextStyle display = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
    height: 1.15,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textMuted,
  );

  /// All-caps label used on buttons and section headers.
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
    color: Colors.white,
  );

  /// Live score readout. Tabular figures stop the number jittering as it ticks.
  static const TextStyle scoreValue = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle currency = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}

/// ============================================================================
/// APP CONFIGURATION — VALUES THE PROJECT OWNER MUST COMPLETE
/// ============================================================================
///
/// Everything in this file is a placeholder that has to be replaced before a
/// store submission. Nothing here is invented contact information: the URL and
/// email fields are intentionally empty strings, and the UI hides any entry
/// whose value is still blank rather than showing a dead link.
///
/// Ad unit IDs and store product IDs are read from `--dart-define` at build
/// time so that production identifiers never get committed to the repository:
///
///   flutter build appbundle --release \
///     --dart-define=ADS_ENABLED=true \
///     --dart-define=ADMOB_APP_ID_ANDROID=ca-app-pub-xxx~yyy \
///     --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-xxx/yyy \
///     --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-xxx/yyy
///
/// See README.md → "Enabling real ads" and "Enabling real IAP".
library;

import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  // ------------------------------------------------------------- identity
  static const String appName = 'Kingdom Drop';
  static const String tagline = 'Build. Clear. Conquer.';

  /// Must match `applicationId` in android/app/build.gradle.kts and
  /// PRODUCT_BUNDLE_IDENTIFIER in the Xcode project.
  static const String bundleId = 'com.yourcompany.kingdomdrop';

  // ------------------------------------------------ TODO(owner): legal URLs
  // Leave blank to hide the corresponding row in Settings. These must be live,
  // publicly reachable URLs before submitting to either store — both Apple and
  // Google require a privacy policy URL for apps that show ads.
  static const String privacyPolicyUrl = '';
  static const String termsOfServiceUrl = '';

  /// TODO(owner): support contact. Either an email or a support page URL.
  /// Apple requires a working support URL on the App Store listing.
  static const String supportEmail = '';
  static const String supportUrl = '';

  // ------------------------------------------------------------------ ads
  /// Master switch. Stays false until real AdMob units are supplied, which
  /// keeps [AdService] in mock mode where "watch ad" resolves instantly.
  static const bool adsEnabled = bool.fromEnvironment('ADS_ENABLED');

  /// Google's public test IDs. Safe to leave as the default — they only ever
  /// serve test creatives. Never ship a real ID hardcoded here.
  static const String admobRewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const String admobRewardedIos = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );
  static const String admobInterstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const String admobInterstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  // ------------------------------------------------------------------ IAP
  /// When false, [PurchaseService] grants entitlements locally without touching
  /// the store, so the whole economy is testable offline.
  static const bool billingEnabled = bool.fromEnvironment('BILLING_ENABLED');

  // ------------------------------------------------------------ analytics
  static const bool analyticsEnabled = bool.fromEnvironment(
    'ANALYTICS_ENABLED',
  );

  // ---------------------------------------------------------------- debug
  /// The developer menu and screenshot mode. Compiled out of release builds
  /// entirely — [kDebugMode] is a const the tree-shaker can fold away.
  static bool get debugMenuEnabled => kDebugMode || _forceDebugMenu;

  /// Lets a profile build expose the debug menu for capturing store
  /// screenshots: `flutter run --profile --dart-define=FORCE_DEBUG_MENU=true`.
  static const bool _forceDebugMenu = bool.fromEnvironment('FORCE_DEBUG_MENU');

  /// Interstitials are suppressed below this many completed games so a new
  /// player's first sessions are uninterrupted.
  static const int interstitialMinGamesPlayed = 3;

  /// Minimum games between two interstitials.
  static const int interstitialGameInterval = 3;
}

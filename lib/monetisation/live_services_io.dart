import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../economy/player_service.dart';
import '../services/analytics_service.dart';
import 'ad_service.dart';
import 'admob_ad_service.dart';
import 'consent_service.dart';
import 'purchase_service.dart';
import 'ump_consent_service.dart';
import 'store_purchase_service.dart';

/// Live monetisation for the platforms that have it.
///
/// `dart:io` exists on desktop too, so having reached this file is not enough —
/// AdMob and store billing are Android and iOS only, and calling either on
/// Linux or Windows throws a MissingPluginException on the first call. Hence
/// the explicit platform check rather than relying on the conditional import
/// alone.
///
/// Returning null hands the caller back to the mock.
AdService? createLiveAdService({
  required AnalyticsService analytics,
  required ConsentService consent,
}) {
  if (!Platform.isAndroid && !Platform.isIOS) {
    debugPrint(
      '[ads] ADS_ENABLED is set, but AdMob only runs on Android and '
      'iOS — staying in mock mode.',
    );
    return null;
  }
  return AdMobAdService(analytics: analytics, consent: consent);
}

/// Live UMP consent, for the same two platforms. Anywhere else there is no ad
/// SDK to gate, so there is nothing to ask about.
ConsentService? createLiveConsentService() {
  if (!Platform.isAndroid && !Platform.isIOS) return null;
  return UmpConsentService();
}

PurchaseService? createLivePurchaseService({
  required PlayerService player,
  required AnalyticsService analytics,
}) {
  if (!Platform.isAndroid && !Platform.isIOS) {
    debugPrint(
      '[iap] BILLING_ENABLED is set, but store billing only runs on '
      'Android and iOS — staying in mock mode.',
    );
    return null;
  }
  return StorePurchaseService(player: player, analytics: analytics);
}

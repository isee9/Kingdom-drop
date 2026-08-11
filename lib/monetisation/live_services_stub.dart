import '../economy/player_service.dart';
import '../services/analytics_service.dart';
import 'ad_service.dart';
import 'consent_service.dart';
import 'purchase_service.dart';

/// Platforms with no AdMob or store billing: the browser build, and anything
/// else without `dart:io`.
///
/// Returning null means the caller falls back to the mock, so the game is fully
/// playable — rewards granted, shop working — it just does not involve money.
/// This file is chosen by the conditional imports in `ad_service.dart` and
/// `purchase_service.dart`, which is what keeps `google_mobile_ads` (and its
/// `dart:io` dependency) out of the web compile entirely.
AdService? createLiveAdService({
  required AnalyticsService analytics,
  required ConsentService consent,
}) => null;

ConsentService? createLiveConsentService() => null;

PurchaseService? createLivePurchaseService({
  required PlayerService player,
  required AnalyticsService analytics,
}) => null;

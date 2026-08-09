import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';

/// Analytics boundary.
///
/// The game never talks to an SDK directly. [DebugAnalyticsService] prints to
/// the console and keeps a small ring buffer the debug menu can display, so the
/// full event stream is verifiable with no vendor configured. Wiring Firebase
/// or another provider later means writing one more implementation of this
/// interface — no call sites change.
abstract interface class AnalyticsService {
  void log(String event, [Map<String, Object?> parameters]);

  /// Screen views, kept separate because most vendors model them specially.
  void screen(String name);
}

/// The canonical event names. Using constants rather than loose strings keeps
/// the dashboard clean and makes typos a compile error.
abstract final class AnalyticsEvents {
  static const String gameStarted = 'game_started';
  static const String gameEnded = 'game_ended';
  static const String continueUsed = 'continue_used';
  static const String boosterUsed = 'booster_used';
  static const String rewardedAdClicked = 'rewarded_ad_clicked';
  static const String rewardedAdCompleted = 'rewarded_ad_completed';
  static const String rewardedAdFailed = 'rewarded_ad_failed';
  static const String interstitialShown = 'interstitial_shown';
  static const String shopOpened = 'shop_opened';
  static const String purchaseStarted = 'purchase_started';
  static const String purchaseCompleted = 'purchase_completed';
  static const String purchaseFailed = 'purchase_failed';
  static const String purchaseRestored = 'purchase_restored';
  static const String kingdomUpgrade = 'kingdom_upgrade';
  static const String kingdomCompleted = 'kingdom_completed';
  static const String dailyRewardClaimed = 'daily_reward_claimed';
  static const String challengeCompleted = 'challenge_completed';
  static const String tutorialCompleted = 'tutorial_completed';
  static const String chestOpened = 'chest_opened';
}

/// One recorded event, kept for the in-app debug log.
class AnalyticsRecord {
  AnalyticsRecord(this.event, this.parameters) : timestamp = DateTime.now();

  final String event;
  final Map<String, Object?> parameters;
  final DateTime timestamp;

  @override
  String toString() =>
      '${timestamp.toIso8601String().substring(11, 19)} $event '
      '${parameters.isEmpty ? '' : parameters}';
}

/// Console + in-memory implementation used in development.
class DebugAnalyticsService implements AnalyticsService {
  DebugAnalyticsService({this.maxRecords = 200});

  final int maxRecords;
  final List<AnalyticsRecord> _records = <AnalyticsRecord>[];

  List<AnalyticsRecord> get records => List<AnalyticsRecord>.unmodifiable(
    _records.reversed,
  );

  @override
  void log(String event, [Map<String, Object?> parameters = const <String, Object?>{}]) {
    final AnalyticsRecord record = AnalyticsRecord(event, parameters);
    _records.add(record);
    if (_records.length > maxRecords) _records.removeAt(0);
    if (kDebugMode) debugPrint('[analytics] $record');
  }

  @override
  void screen(String name) => log('screen_view', <String, Object?>{
    'screen': name,
  });

  void clear() => _records.clear();
}

/// Drops everything. Used when analytics is compiled off.
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  void log(String event, [Map<String, Object?> parameters = const <String, Object?>{}]) {}

  @override
  void screen(String name) {}
}

/// Picks an implementation from build config.
AnalyticsService createAnalyticsService() {
  if (AppConfig.analyticsEnabled) {
    // TODO(owner): return your real provider here once an SDK is configured.
    // Until then the debug implementation is used so events remain visible.
    return DebugAnalyticsService();
  }
  return kDebugMode ? DebugAnalyticsService() : const NoopAnalyticsService();
}

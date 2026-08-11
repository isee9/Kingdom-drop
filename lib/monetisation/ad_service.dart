import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../services/analytics_service.dart';
import 'consent_service.dart';
// Chosen at compile time: the io version returns the AdMob-backed service on
// Android and iOS, the stub returns null everywhere else. This is what keeps
// google_mobile_ads out of the browser and desktop builds.
import 'live_services_stub.dart' if (dart.library.io) 'live_services_io.dart';

/// Where a rewarded ad was offered from. Passed to analytics so the value of
/// each placement can be compared later.
enum AdPlacement {
  doubleCrowns,
  continueGame,
  freeBooster,
  dailyBonus;

  String get id => name;
}

/// Outcome of a rewarded ad.
enum RewardedAdResult {
  /// Watched to the end — grant the reward.
  earned,

  /// Closed early, so no reward.
  dismissed,

  /// Nothing to show or the SDK errored.
  failed,
}

/// Advertising boundary.
///
/// Nothing in the game calls an ad SDK directly. Swapping in AdMob later means
/// adding one implementation of this interface and returning it from
/// [createAdService]; no screen changes.
abstract interface class AdService {
  /// Preloads whatever the implementation needs.
  Future<void> initialize();

  /// True when a rewarded ad could be shown right now.
  bool get isRewardedReady;

  /// Shows a rewarded ad and resolves once it closes.
  Future<RewardedAdResult> showRewardedAd(AdPlacement placement);

  /// Shows an interstitial if one is loaded and the player is eligible.
  /// Returns true if an ad was actually displayed.
  Future<bool> showInterstitialAd();

  /// True when interstitials are suppressed — the player bought Remove Ads.
  bool get interstitialsDisabled;
  set interstitialsDisabled(bool value);

  /// Re-evaluates the consent gate after the player changed their privacy
  /// choices mid-session.
  ///
  /// Without this, a player who opens the privacy form and grants consent gets
  /// no ads until they restart the app, and — the direction that actually
  /// matters — a player who *revokes* consent keeps being served ads for the
  /// rest of the session.
  Future<void> applyConsentChange();

  void dispose();
}

/// Development implementation.
///
/// "Watch Ad" resolves successfully after a short delay so every reward path in
/// the game is exercisable without a network, an account, or an SDK. This is
/// what runs until [AppConfig.adsEnabled] is turned on at build time.
class MockAdService implements AdService {
  MockAdService({
    required AnalyticsService analytics,
    this.simulatedDuration = const Duration(milliseconds: 900),
  }) : _analytics = analytics;

  final AnalyticsService _analytics;

  /// How long the fake ad "plays" for. The UI shows a spinner over this.
  final Duration simulatedDuration;

  bool _interstitialsDisabled = false;

  /// Flip in the debug menu to exercise the "no ad available" path.
  bool simulateNoFill = false;

  /// Flip in the debug menu to exercise the "user closed early" path.
  bool simulateDismissal = false;

  @override
  Future<void> initialize() async {
    debugPrint('[ads] mock mode — rewarded ads always fill');
  }

  @override
  bool get isRewardedReady => !simulateNoFill;

  @override
  bool get interstitialsDisabled => _interstitialsDisabled;

  @override
  set interstitialsDisabled(bool value) => _interstitialsDisabled = value;

  @override
  Future<RewardedAdResult> showRewardedAd(AdPlacement placement) async {
    _analytics.log(AnalyticsEvents.rewardedAdClicked, <String, Object?>{
      'placement': placement.id,
    });

    if (simulateNoFill) {
      _analytics.log(AnalyticsEvents.rewardedAdFailed, <String, Object?>{
        'placement': placement.id,
        'reason': 'no_fill',
      });
      return RewardedAdResult.failed;
    }

    await Future<void>.delayed(simulatedDuration);

    if (simulateDismissal) return RewardedAdResult.dismissed;

    _analytics.log(AnalyticsEvents.rewardedAdCompleted, <String, Object?>{
      'placement': placement.id,
    });
    return RewardedAdResult.earned;
  }

  @override
  Future<void> applyConsentChange() async {
    // Nothing to gate: the mock never talks to an ad network.
  }

  @override
  Future<bool> showInterstitialAd() async {
    if (_interstitialsDisabled) return false;
    _analytics.log(AnalyticsEvents.interstitialShown, <String, Object?>{
      'mock': true,
    });
    debugPrint('[ads] mock interstitial (suppressed in mock mode)');
    // Deliberately does not block the UI in mock mode — an invisible pause
    // between games would make the game feel broken during development.
    return false;
  }

  @override
  void dispose() {}
}

/// Decides when an interstitial is allowed, independent of the ad network.
///
/// Keeping the pacing rule here rather than in the SDK layer means it is
/// testable and easy to retune: no ads for a new player's first few games, then
/// at most one every few games.
class InterstitialPacer {
  InterstitialPacer({
    this.minGamesPlayed = AppConfig.interstitialMinGamesPlayed,
    this.gameInterval = AppConfig.interstitialGameInterval,
  });

  final int minGamesPlayed;
  final int gameInterval;

  int _lastShownAtGame = -1;

  bool shouldShow({required int gamesPlayed, required bool adsRemoved}) {
    if (adsRemoved) return false;
    if (gamesPlayed < minGamesPlayed) return false;
    if (_lastShownAtGame >= 0 &&
        gamesPlayed - _lastShownAtGame < gameInterval) {
      return false;
    }
    return true;
  }

  void markShown(int gamesPlayed) => _lastShownAtGame = gamesPlayed;
}

/// Builds the ad service for this build.
///
/// Live AdMob only when `ADS_ENABLED=true` was passed at build time *and* the
/// platform supports it. Anything else falls back to the mock, so a
/// misconfigured release is a game without ads rather than a crash on launch.
///
/// [consent] is the UMP gate. The live service will not initialise the ad SDK
/// until that gate says it may.
AdService createAdService({
  required AnalyticsService analytics,
  required ConsentService consent,
}) {
  if (AppConfig.adsEnabled) {
    final AdService? live = createLiveAdService(
      analytics: analytics,
      consent: consent,
    );
    if (live != null) return live;
  }
  return MockAdService(analytics: analytics);
}

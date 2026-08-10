import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config/app_config.dart';
import '../services/analytics_service.dart';
import 'ad_service.dart';

/// The real [AdService], backed by Google Mobile Ads.
///
/// It is only ever constructed when `ADS_ENABLED=true` was passed at build time
/// *and* the app is running on Android or iOS — see `createAdService` in
/// `ad_service.dart`. Everywhere else the mock stays in charge, which is what
/// keeps the desktop and browser builds working.
///
/// The design principle throughout: **an ad problem must never cost the player
/// anything.** Every failure path returns [RewardedAdResult.failed] rather than
/// throwing, and the calling screens already treat that as "grant nothing, say
/// nothing, carry on". A player who taps "double my crowns" and hits a no-fill
/// keeps their single helping.
class AdMobAdService implements AdService {
  AdMobAdService({required AnalyticsService analytics}) : _analytics = analytics;

  final AnalyticsService _analytics;

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;

  bool _interstitialsDisabled = false;
  bool _initialised = false;

  /// True while a load is in flight, so a burst of failures cannot start ten
  /// overlapping requests.
  bool _loadingRewarded = false;
  bool _loadingInterstitial = false;

  /// Consecutive load failures, used to back off. AdMob will happily let you
  /// hammer it after a no-fill; retrying in a tight loop burns battery and
  /// gets nothing.
  int _rewardedFailures = 0;
  int _interstitialFailures = 0;

  static const int _maxBackoffSteps = 6;

  static String get _rewardedUnitId => Platform.isIOS
      ? AppConfig.admobRewardedIos
      : AppConfig.admobRewardedAndroid;

  static String get _interstitialUnitId => Platform.isIOS
      ? AppConfig.admobInterstitialIos
      : AppConfig.admobInterstitialAndroid;

  @override
  Future<void> initialize() async {
    if (_initialised) return;
    _initialised = true;

    try {
      await MobileAds.instance.initialize();
    } catch (error) {
      // A failed SDK init leaves both slots empty, isRewardedReady false and
      // every show returning failed. That is a degraded game, not a broken one.
      debugPrint('[ads] MobileAds init failed: $error');
      return;
    }

    debugPrint('[ads] AdMob initialised');
    unawaited(_loadRewarded());
    unawaited(_loadInterstitial());
  }

  /// Exponential back-off after repeated load failures: 2s, 4s, 8s … capped.
  Duration _backoff(int failures) =>
      Duration(seconds: 1 << failures.clamp(1, _maxBackoffSteps));

  Future<void> _loadRewarded() async {
    if (_rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;

    await RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _loadingRewarded = false;
          _rewardedFailures = 0;
          _rewarded = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _loadingRewarded = false;
          _rewardedFailures++;
          debugPrint('[ads] rewarded load failed: ${error.code} ${error.message}');
          // Keep trying in the background so the button becomes live again if
          // this was a transient no-fill.
          Future<void>.delayed(_backoff(_rewardedFailures), _loadRewarded);
        },
      ),
    );
  }

  Future<void> _loadInterstitial() async {
    if (_interstitial != null || _loadingInterstitial) return;
    if (_interstitialsDisabled) return;
    _loadingInterstitial = true;

    await InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _loadingInterstitial = false;
          _interstitialFailures = 0;
          _interstitial = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _loadingInterstitial = false;
          _interstitialFailures++;
          debugPrint(
            '[ads] interstitial load failed: ${error.code} ${error.message}',
          );
          Future<void>.delayed(_backoff(_interstitialFailures), _loadInterstitial);
        },
      ),
    );
  }

  @override
  bool get isRewardedReady => _rewarded != null;

  @override
  bool get interstitialsDisabled => _interstitialsDisabled;

  @override
  set interstitialsDisabled(bool value) {
    _interstitialsDisabled = value;
    if (value) {
      // The player paid to remove these. Drop the loaded one immediately rather
      // than waiting for the next natural boundary.
      _interstitial?.dispose();
      _interstitial = null;
    } else {
      unawaited(_loadInterstitial());
    }
  }

  @override
  Future<RewardedAdResult> showRewardedAd(AdPlacement placement) async {
    _analytics.log(AnalyticsEvents.rewardedAdClicked, <String, Object?>{
      'placement': placement.id,
    });

    final RewardedAd? ad = _rewarded;
    if (ad == null) {
      _analytics.log(AnalyticsEvents.rewardedAdFailed, <String, Object?>{
        'placement': placement.id,
        'reason': 'not_loaded',
      });
      unawaited(_loadRewarded());
      return RewardedAdResult.failed;
    }

    // Taken out of the slot before showing: an ad object is single-use, and
    // leaving it in place would let a double tap show it twice.
    _rewarded = null;

    final Completer<RewardedAdResult> completer = Completer<RewardedAdResult>();
    bool earned = false;

    void finish(RewardedAdResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        unawaited(_loadRewarded());
        finish(earned ? RewardedAdResult.earned : RewardedAdResult.dismissed);
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint('[ads] rewarded show failed: ${error.message}');
        ad.dispose();
        unawaited(_loadRewarded());
        _analytics.log(AnalyticsEvents.rewardedAdFailed, <String, Object?>{
          'placement': placement.id,
          'reason': 'show_failed',
        });
        finish(RewardedAdResult.failed);
      },
    );

    await ad.show(
      onUserEarnedReward: (AdWithoutView _, RewardItem _) {
        // Fires before dismissal. The reward is banked here and acted on when
        // the ad closes, because that is when the player is back in the game.
        earned = true;
        _analytics.log(AnalyticsEvents.rewardedAdCompleted, <String, Object?>{
          'placement': placement.id,
        });
      },
    );

    return completer.future;
  }

  @override
  Future<bool> showInterstitialAd() async {
    if (_interstitialsDisabled) return false;

    final InterstitialAd? ad = _interstitial;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return false;
    }
    _interstitial = null;

    final Completer<bool> completer = Completer<bool>();
    void finish(bool shown) {
      if (!completer.isCompleted) completer.complete(shown);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        unawaited(_loadInterstitial());
        finish(true);
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('[ads] interstitial show failed: ${error.message}');
        ad.dispose();
        unawaited(_loadInterstitial());
        finish(false);
      },
    );

    _analytics.log(AnalyticsEvents.interstitialShown, <String, Object?>{
      'mock': false,
    });
    await ad.show();
    return completer.future;
  }

  @override
  void dispose() {
    _rewarded?.dispose();
    _interstitial?.dispose();
    _rewarded = null;
    _interstitial = null;
  }
}

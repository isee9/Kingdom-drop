import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config/app_config.dart';
import '../core/utils/stage_log.dart';
import '../services/analytics_service.dart';
import 'ad_service.dart';
import 'consent_service.dart';

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
///
/// Consent comes first. [initialize] gathers it through [ConsentService] and
/// will not call `MobileAds.initialize` at all unless the gate opens —
/// initialising the SDK is itself an ad-related data operation, so gating only
/// the individual ad loads would be too late.
class AdMobAdService implements AdService {
  AdMobAdService({
    required AnalyticsService analytics,
    required ConsentService consent,
    StageLog? log,
  }) : _analytics = analytics,
       _consent = consent,
       _log = log ?? StageLog('ads');

  final AnalyticsService _analytics;
  final ConsentService _consent;
  final StageLog _log;

  /// A bound on `MobileAds.initialize`, which crosses a platform channel and
  /// has no timeout of its own.
  static const Duration _sdkInitTimeout = Duration(seconds: 30);

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;

  bool _interstitialsDisabled = false;
  bool _initialised = false;

  /// True once `MobileAds.initialize` has succeeded. Separate from
  /// [_initialised], which only records that [initialize] ran — consent may
  /// have blocked the SDK from starting at all.
  bool _sdkStarted = false;

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

    // Consent before anything else, every launch. This is the call that may
    // put a form in front of the player.
    await _consent.gather();
    await _startIfPermitted();
  }

  @override
  Future<void> applyConsentChange() async {
    if (_consent.canRequestAds) {
      // Newly granted: bring the SDK up if it was never started.
      await _startIfPermitted();
      return;
    }

    // Newly revoked. Drop everything loaded — an ad already in the slot was
    // fetched under the old permission and must not be shown now.
    debugPrint('[ads] consent withdrawn — discarding loaded ads');
    unawaited(_rewarded?.dispose() ?? Future<void>.value());
    unawaited(_interstitial?.dispose() ?? Future<void>.value());
    _rewarded = null;
    _interstitial = null;
  }

  /// Brings up the SDK and starts preloading, but only if the gate is open.
  Future<void> _startIfPermitted() async {
    if (!_consent.canRequestAds) {
      _log.stage('gate.closed', <String, Object?>{
        'meaning': 'consent does not permit ad requests — no ads this session',
      });
      return;
    }
    if (_sdkStarted) {
      // Already running; just top up whatever is empty.
      unawaited(_loadRewarded());
      unawaited(_loadInterstitial());
      return;
    }

    _log.stage('mobileAds.init.begin');
    try {
      await MobileAds.instance.initialize().timeout(_sdkInitTimeout);
    } on TimeoutException {
      _log.stage('mobileAds.init.TIMEOUT', <String, Object?>{
        'after': _sdkInitTimeout.inSeconds,
      });
      return;
    } catch (error) {
      // A failed SDK init leaves both slots empty, isRewardedReady false and
      // every show returning failed. That is a degraded game, not a broken one.
      _log.stage('mobileAds.init.failed', <String, Object?>{'error': error});
      return;
    }

    _sdkStarted = true;
    _log.stage('mobileAds.init.ok');
    unawaited(_loadRewarded());
    unawaited(_loadInterstitial());
  }

  /// Exponential back-off after repeated load failures: 2s, 4s, 8s … capped.
  Duration _backoff(int failures) =>
      Duration(seconds: 1 << failures.clamp(1, _maxBackoffSteps));

  Future<void> _loadRewarded() async {
    if (_rewarded != null || _loadingRewarded) return;
    // Re-checked on every load, not just at startup: a back-off retry scheduled
    // before the player revoked consent would otherwise still fire.
    if (!_consent.canRequestAds || !_sdkStarted) return;
    _loadingRewarded = true;

    await RewardedAd.load(
      adUnitId: _rewardedUnitId,
      // A plain request on purpose. When a player declines personalisation but
      // UMP still permits ads, Google reads the stored consent signals and
      // serves non-personalised ads itself. Setting an npa flag by hand here
      // would second-guess that and can conflict with what UMP recorded.
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
          debugPrint(
            '[ads] rewarded load failed: ${error.code} ${error.message}',
          );
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
    if (!_consent.canRequestAds || !_sdkStarted) return;
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
          Future<void>.delayed(
            _backoff(_interstitialFailures),
            _loadInterstitial,
          );
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

    // Belt and braces alongside the null check: consent can be revoked between
    // an ad loading and the player tapping the button that shows it.
    final RewardedAd? ad = _consent.canRequestAds ? _rewarded : null;
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
    if (!_consent.canRequestAds) return false;

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

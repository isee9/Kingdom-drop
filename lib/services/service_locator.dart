import 'dart:async';

import 'package:flutter/widgets.dart';

import '../audio/audio_service.dart';
import '../core/utils/stage_log.dart';
import '../economy/player_service.dart';
import '../monetisation/ad_service.dart';
import '../monetisation/consent_service.dart';
import '../monetisation/purchase_service.dart';
import '../progression/chest_service.dart';
import '../progression/daily_service.dart';
import '../storage/prefs_storage.dart';
import 'analytics_service.dart';
import 'haptic_service.dart';

/// Everything the app needs, assembled once at startup.
///
/// Passed down the tree by [ServiceScope] rather than a global singleton, so
/// tests and widget previews can substitute fakes for any part of it.
class AppServices {
  AppServices({
    required this.player,
    required this.storage,
    required this.analytics,
    required this.audio,
    required this.haptics,
    required this.ads,
    required this.consent,
    required this.purchases,
    required this.daily,
    required this.chests,
    required this.interstitials,
  });

  final PlayerService player;
  final DebouncedStorage storage;
  final AnalyticsService analytics;
  final AudioService audio;
  final HapticService haptics;
  final AdService ads;

  /// The UMP consent gate in front of advertising. Settings reads
  /// [ConsentService.privacyOptionsRequired] from it to decide whether to offer
  /// a "Privacy choices" row.
  final ConsentService consent;

  final PurchaseService purchases;
  final DailyService daily;
  final ChestService chests;
  final InterstitialPacer interstitials;

  /// Brings up consent and the ad SDK, off the app-start critical path.
  ///
  /// Deliberately **not** awaited by `main`. Consent shows a form owned by the
  /// platform, and a form that never reports being dismissed used to leave the
  /// game on its launch screen forever — the app was waiting on a callback that
  /// was never coming. Nothing the player can see may depend on this finishing.
  ///
  /// It never throws and it always returns. If it fails or times out, the game
  /// runs with [AdService.isRewardedReady] false and no interstitials: the
  /// fail-closed outcome, reached without taking the game down with it.
  Future<void> startMonetisation({
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final StageLog log = StageLog('boot');
    log.stage('monetisation.begin');

    try {
      await ads.initialize().timeout(timeout);
      log.stage('monetisation.ready', <String, Object?>{
        'canRequestAds': consent.canRequestAds,
        'rewardedReady': ads.isRewardedReady,
      });
    } on TimeoutException {
      log.stage('monetisation.TIMEOUT', <String, Object?>{
        'after': timeout.inSeconds,
        'effect': 'no ads this session; the game is unaffected',
      });
    } catch (error) {
      log.stage('monetisation.failed', <String, Object?>{'error': error});
    }

    // Applied whatever happened above, so a player who bought Remove Ads keeps
    // it even if the ad SDK never came up.
    ads.interstitialsDisabled = player.adsRemoved;
  }

  /// Pushes the player's saved toggles into the services that act on them.
  void applySettings() {
    haptics.enabled = player.settings.hapticsEnabled;
    audio.setSoundEnabled(player.settings.soundEnabled);
    audio.setMusicEnabled(player.settings.musicEnabled);
    ads.interstitialsDisabled = player.adsRemoved;
  }

  Future<void> dispose() async {
    ads.dispose();
    purchases.dispose();
    await audio.dispose();
    await storage.flush();
    storage.dispose();
    player.dispose();
  }
}

/// Builds the whole service graph. Called once from `main`.
Future<AppServices> bootstrapServices() async {
  final StageLog boot = StageLog('boot');
  boot.stage('bootstrap.begin');

  final AnalyticsService analytics = createAnalyticsService();

  final PrefsStorage prefs = await PrefsStorage.create();
  final DebouncedStorage storage = DebouncedStorage(prefs);

  final PlayerService player = await PlayerService.load(
    storage: storage,
    analytics: analytics,
  );

  final AudioService audio = AudioService(
    soundEnabled: player.settings.soundEnabled,
    musicEnabled: player.settings.musicEnabled,
  );
  await audio.init();

  final HapticService haptics = HapticService(
    enabled: player.settings.hapticsEnabled,
  );

  // Consent, then ads — in that order, and never the other way round.
  // AdService.initialize gathers consent through this and refuses to start the
  // ad SDK until it is allowed to.
  //
  // Built here but NOT started here: see AppServices.startMonetisation, which
  // main calls after the first frame. Starting it now would put a platform
  // consent form in front of an app that has not drawn anything yet, and a
  // form that never reports dismissal would hang the launch.
  final ConsentService consent = createConsentService();
  final AdService ads = createAdService(analytics: analytics, consent: consent);
  ads.interstitialsDisabled = player.adsRemoved;

  final PurchaseService purchases = createPurchaseService(
    player: player,
    analytics: analytics,
  );
  // Bounded, unlike before. Store billing is normally fast and the shop wants
  // it ready, so it stays on the startup path — but it may not hold the app
  // open indefinitely if the platform never answers.
  try {
    await purchases.initialize().timeout(const Duration(seconds: 8));
  } on TimeoutException {
    boot.stage('purchases.TIMEOUT', <String, Object?>{
      'effect': 'shop shows fallback prices until the store answers',
    });
  } catch (error) {
    boot.stage('purchases.failed', <String, Object?>{'error': error});
  }

  final ChestService chests = ChestService();
  final DailyService daily = DailyService(
    player: player,
    analytics: analytics,
    chests: chests,
  );

  boot.stage('bootstrap.complete');

  return AppServices(
    player: player,
    storage: storage,
    analytics: analytics,
    audio: audio,
    haptics: haptics,
    ads: ads,
    consent: consent,
    purchases: purchases,
    daily: daily,
    chests: chests,
    interstitials: InterstitialPacer(),
  );
}

/// Makes [AppServices] available to the widget tree.
class ServiceScope extends InheritedWidget {
  const ServiceScope({required this.services, required super.child, super.key});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final ServiceScope? scope = context
        .dependOnInheritedWidgetOfExactType<ServiceScope>();
    assert(scope != null, 'No ServiceScope found in the widget tree');
    return scope!.services;
  }

  /// Non-subscribing lookup, for callbacks that only need to act.
  static AppServices read(BuildContext context) {
    final ServiceScope? scope = context
        .getInheritedWidgetOfExactType<ServiceScope>();
    assert(scope != null, 'No ServiceScope found in the widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(ServiceScope oldWidget) =>
      !identical(services, oldWidget.services);
}

/// Rebuilds [builder] whenever the player profile changes.
///
/// Scoping listeners to the widgets that actually display currency keeps a coin
/// award from rebuilding the whole screen.
class PlayerBuilder extends StatelessWidget {
  const PlayerBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, PlayerService player) builder;

  @override
  Widget build(BuildContext context) {
    final PlayerService player = ServiceScope.of(context).player;
    return ListenableBuilder(
      listenable: player,
      builder: (BuildContext context, _) => builder(context, player),
    );
  }
}

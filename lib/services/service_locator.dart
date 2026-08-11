import 'package:flutter/widgets.dart';

import '../audio/audio_service.dart';
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
  final ConsentService consent = createConsentService();

  final AdService ads = createAdService(analytics: analytics, consent: consent);
  await ads.initialize();
  ads.interstitialsDisabled = player.adsRemoved;

  final PurchaseService purchases = createPurchaseService(
    player: player,
    analytics: analytics,
  );
  await purchases.initialize();

  final ChestService chests = ChestService();
  final DailyService daily = DailyService(
    player: player,
    analytics: analytics,
    chests: chests,
  );

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

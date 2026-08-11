import 'package:flutter/material.dart';
import 'package:kingdom_drop/audio/audio_service.dart';
import 'package:kingdom_drop/economy/player_service.dart';
import 'package:kingdom_drop/models/save_data.dart';
import 'package:kingdom_drop/monetisation/ad_service.dart';
import 'package:kingdom_drop/monetisation/consent_service.dart';
import 'package:kingdom_drop/monetisation/purchase_service.dart';
import 'package:kingdom_drop/progression/chest_service.dart';
import 'package:kingdom_drop/progression/daily_service.dart';
import 'package:kingdom_drop/services/analytics_service.dart';
import 'package:kingdom_drop/services/haptic_service.dart';
import 'package:kingdom_drop/services/service_locator.dart';
import 'package:kingdom_drop/storage/prefs_storage.dart';
import 'package:kingdom_drop/storage/storage_repository.dart';
import 'package:kingdom_drop/theme/app_theme.dart';

/// Builds a fully in-memory service graph for widget tests.
///
/// No plugins are touched: storage is in-memory, ads and purchases are the mock
/// implementations the app already ships, and [AudioService.init] is never
/// called so no platform player is created.
AppServices createTestServices({
  SaveData? save,
  ConsentService? consent,
  AdService? ads,
}) {
  const AnalyticsService analytics = NoopAnalyticsService();
  final DebouncedStorage storage = DebouncedStorage(
    InMemoryStorage(),
    debounce: const Duration(milliseconds: 1),
  );

  final PlayerService player = PlayerService(
    storage: storage,
    analytics: analytics,
    initial: save ?? SaveData.fresh(),
  );

  final ChestService chests = ChestService();

  return AppServices(
    player: player,
    storage: storage,
    analytics: analytics,
    audio: AudioService(),
    haptics: HapticService(enabled: false),
    // No UMP in tests: the permissive gate is what a build with ads compiled
    // out uses anyway, and it touches no platform channel. A test that cares
    // about the consent-dependent UI passes its own.
    consent: consent ?? const PermissiveConsentService(),
    ads:
        ads ??
        MockAdService(analytics: analytics, simulatedDuration: Duration.zero),
    purchases: MockPurchaseService(
      player: player,
      analytics: analytics,
      simulatedDelay: Duration.zero,
    ),
    daily: DailyService(player: player, analytics: analytics, chests: chests),
    chests: chests,
    interstitials: InterstitialPacer(),
  );
}

/// Wraps [child] in the app's theme and service scope.
Widget wrapForTest({required Widget child, required AppServices services}) {
  return ServiceScope(
    services: services,
    child: MaterialApp(
      theme: AppTheme.build(),
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

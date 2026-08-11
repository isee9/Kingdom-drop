import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/monetisation/ad_service.dart';
import 'package:kingdom_drop/services/service_locator.dart';

import '../widget/test_services.dart';

/// An ad service whose `initialize` never finishes.
///
/// Stands in for the real failure: a UMP consent form that reports itself
/// loaded and then never reports being dismissed, leaving the future that the
/// ad service is awaiting permanently unresolved.
class _HangingAdService implements AdService {
  bool disposed = false;
  bool _interstitialsDisabled = false;

  @override
  Future<void> initialize() => Completer<void>().future;

  @override
  bool get isRewardedReady => false;

  @override
  bool get interstitialsDisabled => _interstitialsDisabled;

  @override
  set interstitialsDisabled(bool value) => _interstitialsDisabled = value;

  @override
  Future<void> applyConsentChange() async {}

  @override
  Future<RewardedAdResult> showRewardedAd(AdPlacement placement) async =>
      RewardedAdResult.failed;

  @override
  Future<bool> showInterstitialAd() async => false;

  @override
  void dispose() => disposed = true;
}

/// An ad service that fails loudly.
class _ThrowingAdService extends _HangingAdService {
  @override
  Future<void> initialize() async => throw StateError('SDK exploded');
}

void main() {
  setUp(TestWidgetsFlutterBinding.ensureInitialized);

  group('Starting monetisation', () {
    test('gives up rather than waiting forever on a stuck ad service', () async {
      // The app-level half of the launch-hang fix. Even if consent and the ad
      // SDK never resolve, this must return — because if it did not, and
      // anything on the startup path awaited it, the game would be stuck on its
      // launch screen. That is exactly the bug this guards.
      final AppServices services = createTestServices(ads: _HangingAdService());

      await services
          .startMonetisation(timeout: const Duration(milliseconds: 60))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail(
              'startMonetisation() never returned on a stuck ad service',
            ),
          );
    });

    test('survives an ad service that throws', () async {
      final AppServices services = createTestServices(
        ads: _ThrowingAdService(),
      );

      await expectLater(services.startMonetisation(), completes);
    });

    test('still applies Remove Ads after a failure', () async {
      // A player who paid to remove interstitials keeps that even when the ad
      // stack never came up — the entitlement is theirs regardless.
      final _HangingAdService ads = _HangingAdService();
      final AppServices services = createTestServices(ads: ads);
      services.player.grantProduct('remove_ads');

      await services.startMonetisation(
        timeout: const Duration(milliseconds: 60),
      );

      expect(ads.interstitialsDisabled, isTrue);
    });

    test('completes normally when the ad service is healthy', () async {
      final AppServices services = createTestServices();

      await expectLater(services.startMonetisation(), completes);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/economy/player_service.dart';
import 'package:kingdom_drop/models/booster.dart';
import 'package:kingdom_drop/models/save_data.dart';
import 'package:kingdom_drop/monetisation/products.dart';
import 'package:kingdom_drop/monetisation/purchase_service.dart';
import 'package:kingdom_drop/services/analytics_service.dart';
import 'package:kingdom_drop/storage/prefs_storage.dart';
import 'package:kingdom_drop/storage/storage_repository.dart';

/// Tests for what a purchase actually gives the player.
///
/// `grantEntitlement` is deliberately the one place both the mock and the
/// store-backed service credit an account, so these cover both. The rules they
/// pin down are the ones that cost real money when they go wrong: paying twice
/// for a non-consumable, or being credited twice for one payment.
void main() {
  late PlayerService player;

  PlayerService buildPlayer() => PlayerService(
    storage: DebouncedStorage(
      InMemoryStorage(),
      debounce: const Duration(milliseconds: 1),
    ),
    analytics: const NoopAnalyticsService(),
    initial: SaveData.fresh(),
  );

  setUp(() => player = buildPlayer());

  group('Granting a product', () {
    test('a coin pack credits exactly its coins', () {
      final Product pack = ProductCatalog.byId('coins_1200')!;
      final int before = player.coins;

      grantEntitlement(player, pack);

      expect(player.coins, before + pack.coins);
      expect(player.ownsProduct(pack.id), isFalse,
          reason: 'a consumable must not be recorded as owned, or the player '
              'could never buy it again');
    });

    test('a non-consumable is recorded as owned', () {
      final Product removeAds = ProductCatalog.byId('remove_ads')!;

      grantEntitlement(player, removeAds);

      expect(player.ownsProduct('remove_ads'), isTrue);
    });

    test('the starter pack credits coins, boosters and ownership together', () {
      final Product starter = ProductCatalog.byId('starter_pack')!;
      final int coinsBefore = player.coins;
      final Map<BoosterType, int> boostersBefore = <BoosterType, int>{
        for (final BoosterType t in BoosterType.values) t: player.boosterCount(t),
      };

      grantEntitlement(player, starter);

      expect(player.coins, coinsBefore + starter.coins);
      expect(player.ownsProduct(starter.id), isTrue);
      starter.boosters.forEach((BoosterType type, int count) {
        expect(player.boosterCount(type), boostersBefore[type]! + count);
      });
    });

    test('buying a coin pack twice credits it twice', () {
      final Product pack = ProductCatalog.byId('coins_500')!;
      final int before = player.coins;

      grantEntitlement(player, pack);
      grantEntitlement(player, pack);

      expect(player.coins, before + pack.coins * 2);
    });
  });

  group('The mock service', () {
    late MockPurchaseService service;

    setUp(() {
      service = MockPurchaseService(
        player: player,
        analytics: const NoopAnalyticsService(),
        simulatedDelay: Duration.zero,
      );
    });

    test('refuses to sell a non-consumable the player already owns', () async {
      await service.buy('remove_ads');
      final PurchaseResult second = await service.buy('remove_ads');

      expect(second.status, PurchaseStatus.alreadyOwned);
    });

    test('an unknown product is unavailable rather than a crash', () async {
      final PurchaseResult result = await service.buy('not_a_real_product');
      expect(result.status, PurchaseStatus.unavailable);
    });

    test('a cancelled purchase grants nothing', () async {
      service.simulateCancellation = true;
      final int before = player.coins;

      final PurchaseResult result = await service.buy('coins_3000');

      expect(result.status, PurchaseStatus.cancelled);
      expect(player.coins, before);
    });

    test('a failed purchase grants nothing', () async {
      service.simulateFailure = true;
      final int before = player.coins;

      final PurchaseResult result = await service.buy('coins_3000');

      expect(result.status, PurchaseStatus.failed);
      expect(player.coins, before);
    });

    test('restoring returns the non-consumables the player owns', () async {
      await service.buy('remove_ads');

      final List<String> restored = await service.restorePurchases();

      expect(restored, contains('remove_ads'));
      expect(restored, isNot(contains('coins_500')),
          reason: 'consumables are never restored — that would be free coins');
    });
  });

  group('The catalogue', () {
    test('every product ID is unique', () {
      final List<String> ids =
          ProductCatalog.all.map((Product p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('non-consumable IDs are exactly the non-consumable products', () {
      final Set<String> expected = ProductCatalog.all
          .where((Product p) => p.kind == ProductKind.nonConsumable)
          .map((Product p) => p.id)
          .toSet();

      expect(ProductCatalog.nonConsumableIds.toSet(), expected);
    });

    test('every product has a fallback price for the pre-query UI', () {
      for (final Product p in ProductCatalog.all) {
        expect(p.fallbackPrice, isNotEmpty, reason: p.id);
      }
    });

    test('every product gives the player something', () {
      // A product that grants nothing is a charge with no delivery — the exact
      // shape of complaint that gets an app pulled.
      for (final Product p in ProductCatalog.all) {
        final bool givesSomething = p.coins > 0 ||
            p.crowns > 0 ||
            p.boosters.isNotEmpty ||
            p.kind == ProductKind.nonConsumable;
        expect(givesSomething, isTrue, reason: p.id);
      }
    });
  });
}

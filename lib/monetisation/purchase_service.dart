import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../economy/player_service.dart';
import '../services/analytics_service.dart';
import 'products.dart';

enum PurchaseStatus { success, cancelled, failed, alreadyOwned, unavailable }

class PurchaseResult {
  const PurchaseResult(this.status, {this.product, this.message});

  final PurchaseStatus status;
  final Product? product;
  final String? message;

  bool get isSuccess => status == PurchaseStatus.success;
}

/// In-app purchase boundary.
///
/// Consumables (coin packs) and non-consumables (starter pack, remove ads) are
/// both handled here, along with restoration. The game only ever sees
/// [PurchaseResult]; entitlement is granted centrally in [_grantEntitlement] so
/// the mock and a real store implementation cannot drift apart.
abstract interface class PurchaseService {
  Future<void> initialize();

  /// True when the store is reachable and products have been fetched.
  bool get isAvailable;

  /// Localised price for [productId], falling back to the catalogue value.
  String priceFor(String productId);

  Future<PurchaseResult> buy(String productId);

  /// Re-applies non-consumables. Required by Apple's review guidelines for any
  /// app selling non-consumables.
  Future<List<String>> restorePurchases();

  void dispose();
}

/// Development implementation.
///
/// Grants entitlements locally with no store involved, so the shop, the starter
/// pack and Remove Ads are all fully testable offline. Enable a real store by
/// setting BILLING_ENABLED and returning a live implementation from
/// [createPurchaseService].
class MockPurchaseService implements PurchaseService {
  MockPurchaseService({
    required PlayerService player,
    required AnalyticsService analytics,
    this.simulatedDelay = const Duration(milliseconds: 600),
  }) : _player = player,
       _analytics = analytics;

  final PlayerService _player;
  final AnalyticsService _analytics;
  final Duration simulatedDelay;

  /// Flip in the debug menu to exercise the failure path.
  bool simulateFailure = false;

  /// Flip in the debug menu to exercise the cancellation path.
  bool simulateCancellation = false;

  @override
  Future<void> initialize() async {
    debugPrint('[iap] mock mode — purchases are granted locally, no charge');
  }

  @override
  bool get isAvailable => true;

  @override
  String priceFor(String productId) =>
      ProductCatalog.byId(productId)?.fallbackPrice ?? '—';

  @override
  Future<PurchaseResult> buy(String productId) async {
    final Product? product = ProductCatalog.byId(productId);
    if (product == null) {
      return const PurchaseResult(
        PurchaseStatus.unavailable,
        message: 'Unknown product',
      );
    }

    if (product.kind == ProductKind.nonConsumable &&
        _player.ownsProduct(productId)) {
      return PurchaseResult(PurchaseStatus.alreadyOwned, product: product);
    }

    _analytics.log(AnalyticsEvents.purchaseStarted, <String, Object?>{
      'product': productId,
      'mock': true,
    });

    await Future<void>.delayed(simulatedDelay);

    if (simulateCancellation) {
      return PurchaseResult(PurchaseStatus.cancelled, product: product);
    }
    if (simulateFailure) {
      _analytics.log(AnalyticsEvents.purchaseFailed, <String, Object?>{
        'product': productId,
      });
      return PurchaseResult(
        PurchaseStatus.failed,
        product: product,
        message: 'Simulated failure',
      );
    }

    grantEntitlement(_player, product);

    _analytics.log(AnalyticsEvents.purchaseCompleted, <String, Object?>{
      'product': productId,
      'mock': true,
    });
    return PurchaseResult(PurchaseStatus.success, product: product);
  }

  @override
  Future<List<String>> restorePurchases() async {
    await Future<void>.delayed(simulatedDelay);
    // With no store attached the only record is the local one, so restoring
    // re-applies what is already owned. Against a real store this would come
    // back from the platform instead.
    final List<String> owned = ProductCatalog.nonConsumableIds
        .where(_player.ownsProduct)
        .toList();
    _player.restoreProducts(owned);
    _analytics.log(AnalyticsEvents.purchaseRestored, <String, Object?>{
      'count': owned.length,
    });
    return owned;
  }

  @override
  void dispose() {}
}

/// Applies what a product gives the player.
///
/// Shared by every implementation so a real store grants exactly what the mock
/// does. Consumables are credited; non-consumables are recorded as owned.
void grantEntitlement(PlayerService player, Product product) {
  if (product.coins > 0) player.addCoins(product.coins);
  if (product.crowns > 0) player.addCrowns(product.crowns);
  if (product.boosters.isNotEmpty) player.grantBoosters(product.boosters);
  if (product.kind == ProductKind.nonConsumable) {
    player.grantProduct(product.id);
  }
}

/// Builds the purchase service for this build.
PurchaseService createPurchaseService({
  required PlayerService player,
  required AnalyticsService analytics,
}) {
  if (AppConfig.billingEnabled) {
    // TODO(owner): construct your in_app_purchase-backed implementation here
    // once products exist in Play Console and App Store Connect.
    debugPrint(
      '[iap] BILLING_ENABLED is set but no live implementation is wired up; '
      'continuing in mock mode',
    );
  }
  return MockPurchaseService(player: player, analytics: analytics);
}

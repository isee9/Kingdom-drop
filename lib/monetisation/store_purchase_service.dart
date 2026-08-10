import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart' as iap;

import '../economy/player_service.dart';
import '../services/analytics_service.dart';
import 'products.dart';
import 'purchase_service.dart';

/// The real [PurchaseService], backed by Google Play Billing and StoreKit
/// through the `in_app_purchase` plugin.
///
/// Only constructed when `BILLING_ENABLED=true` was passed at build time and
/// the app is on Android or iOS — see `createPurchaseService`.
///
/// Two things about billing that the mock cannot teach you, and that this class
/// exists to get right:
///
/// * **Purchases arrive on a stream, not as the return value of `buy`.** They
///   can also arrive with no `buy` call at all — a purchase that was pending
///   when the app closed, a restore, or a promo code redeemed on the store.
///   So the stream is the source of truth and [buy] just waits on it.
/// * **`completePurchase` is not optional.** Any purchase left uncompleted is
///   automatically refunded by Google after three days, and StoreKit will keep
///   redelivering it forever. It is called for every delivery here, including
///   ones that arrive unexpectedly.
class StorePurchaseService implements PurchaseService {
  StorePurchaseService({
    required PlayerService player,
    required AnalyticsService analytics,
  }) : _player = player,
       _analytics = analytics;

  final PlayerService _player;
  final AnalyticsService _analytics;

  final iap.InAppPurchase _iap = iap.InAppPurchase.instance;

  StreamSubscription<List<iap.PurchaseDetails>>? _subscription;

  /// Store details keyed by product ID, filled by [initialize].
  final Map<String, iap.ProductDetails> _details =
      <String, iap.ProductDetails>{};

  /// The buy currently awaiting a stream event, if any.
  Completer<PurchaseResult>? _pending;
  String? _pendingProductId;

  bool _available = false;

  /// How long to wait for the store to answer a purchase before giving up on
  /// the UI spinner. The purchase itself is not cancelled — if it lands later
  /// the stream still grants it — this only stops the shop hanging forever.
  static const Duration _purchaseTimeout = Duration(minutes: 3);

  @override
  Future<void> initialize() async {
    try {
      _available = await _iap.isAvailable();
    } catch (error) {
      debugPrint('[iap] store unavailable: $error');
      _available = false;
    }

    if (!_available) {
      debugPrint('[iap] store not available on this device');
      return;
    }

    // Subscribe before querying, so a purchase that was pending from a previous
    // session is not missed.
    _subscription = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => debugPrint('[iap] purchase stream error: $error'),
    );

    try {
      final iap.ProductDetailsResponse response = await _iap.queryProductDetails(
        ProductCatalog.all.map((Product p) => p.id).toSet(),
      );

      for (final iap.ProductDetails d in response.productDetails) {
        _details[d.id] = d;
      }

      if (response.notFoundIDs.isNotEmpty) {
        // Almost always a console configuration problem: the ID is missing, or
        // the product is not activated, or the build is not on a test track.
        debugPrint(
          '[iap] products not found in the store: ${response.notFoundIDs}. '
          'Check they exist and are active, and that this build is signed with '
          'the upload key and published to a test track.',
        );
      }
    } catch (error) {
      debugPrint('[iap] product query failed: $error');
    }

    debugPrint('[iap] store ready, ${_details.length} products loaded');
  }

  @override
  bool get isAvailable => _available && _details.isNotEmpty;

  @override
  String priceFor(String productId) =>
      _details[productId]?.price ??
      ProductCatalog.byId(productId)?.fallbackPrice ??
      '—';

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

    final iap.ProductDetails? details = _details[productId];
    if (!_available || details == null) {
      return PurchaseResult(
        PurchaseStatus.unavailable,
        product: product,
        message: 'This item is not available right now.',
      );
    }

    // One purchase at a time. The stores serialise them anyway, and letting two
    // run would make it ambiguous which one a stream event belongs to.
    if (_pending != null && !_pending!.isCompleted) {
      return PurchaseResult(
        PurchaseStatus.failed,
        product: product,
        message: 'Another purchase is already in progress.',
      );
    }

    _analytics.log(AnalyticsEvents.purchaseStarted, <String, Object?>{
      'product': productId,
      'mock': false,
    });

    final Completer<PurchaseResult> completer = Completer<PurchaseResult>();
    _pending = completer;
    _pendingProductId = productId;

    final iap.PurchaseParam param = iap.PurchaseParam(productDetails: details);

    try {
      if (product.kind == ProductKind.consumable) {
        await _iap.buyConsumable(purchaseParam: param);
      } else {
        await _iap.buyNonConsumable(purchaseParam: param);
      }
    } catch (error) {
      _settle(
        PurchaseResult(
          PurchaseStatus.failed,
          product: product,
          message: '$error',
        ),
      );
    }

    return completer.future.timeout(
      _purchaseTimeout,
      onTimeout: () {
        _pending = null;
        _pendingProductId = null;
        return PurchaseResult(
          PurchaseStatus.failed,
          product: product,
          message: 'The store did not respond. If you were charged, the '
              'purchase will be applied next time you open the game.',
        );
      },
    );
  }

  /// Handles every purchase the platform reports, whether or not [buy] is
  /// waiting for it.
  Future<void> _onPurchases(List<iap.PurchaseDetails> purchases) async {
    for (final iap.PurchaseDetails purchase in purchases) {
      final Product? product = ProductCatalog.byId(purchase.productID);

      switch (purchase.status) {
        case iap.PurchaseStatus.pending:
          // Slow payment methods, or a child asking a parent for approval.
          // Nothing to do but wait for the next event.
          continue;

        case iap.PurchaseStatus.canceled:
          _settle(PurchaseResult(PurchaseStatus.cancelled, product: product));

        case iap.PurchaseStatus.error:
          debugPrint('[iap] purchase error: ${purchase.error}');
          _analytics.log(AnalyticsEvents.purchaseFailed, <String, Object?>{
            'product': purchase.productID,
            'code': purchase.error?.code,
          });
          _settle(
            PurchaseResult(
              PurchaseStatus.failed,
              product: product,
              message: purchase.error?.message,
            ),
          );

        case iap.PurchaseStatus.purchased:
        case iap.PurchaseStatus.restored:
          if (product != null) {
            // Consumables are only granted on a fresh purchase. A "restored"
            // consumable would be a redelivery, and crediting it again would
            // hand out free coins on every launch.
            final bool fresh = purchase.status == iap.PurchaseStatus.purchased;
            if (fresh || product.kind == ProductKind.nonConsumable) {
              grantEntitlement(_player, product);
            }

            _analytics.log(
              fresh
                  ? AnalyticsEvents.purchaseCompleted
                  : AnalyticsEvents.purchaseRestored,
              <String, Object?>{'product': product.id, 'mock': false},
            );
          } else {
            debugPrint('[iap] unknown product delivered: ${purchase.productID}');
          }

          _settle(PurchaseResult(PurchaseStatus.success, product: product));
      }

      // Unconditional, and after granting: Google refunds anything left
      // uncompleted after three days, and StoreKit redelivers it forever.
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (error) {
          debugPrint('[iap] completePurchase failed: $error');
        }
      }
    }
  }

  /// Resolves the waiting [buy], if this event belongs to it.
  void _settle(PurchaseResult result) {
    final Completer<PurchaseResult>? pending = _pending;
    if (pending == null || pending.isCompleted) return;

    // A purchase arriving for a different product is someone else's — a
    // restore, or a promo redemption. It has already been granted above; the
    // waiting buy keeps waiting for its own.
    if (result.product != null &&
        _pendingProductId != null &&
        result.product!.id != _pendingProductId) {
      return;
    }

    _pending = null;
    _pendingProductId = null;
    pending.complete(result);
  }

  @override
  Future<List<String>> restorePurchases() async {
    if (!_available) return <String>[];

    try {
      // Results arrive on the stream as `restored`, which _onPurchases grants.
      await _iap.restorePurchases();
      // Give the stream a moment to deliver before reporting back, so the
      // Settings screen's confirmation reflects what actually came in.
      await Future<void>.delayed(const Duration(milliseconds: 900));
    } catch (error) {
      debugPrint('[iap] restore failed: $error');
      return <String>[];
    }

    final List<String> owned = ProductCatalog.nonConsumableIds
        .where(_player.ownsProduct)
        .toList();
    _player.restoreProducts(owned);
    return owned;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

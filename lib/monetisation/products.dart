import '../core/config/economy_config.dart';
import '../models/booster.dart';

enum ProductKind { consumable, nonConsumable }

/// A store product.
///
/// [fallbackPrice] is only shown in mock mode and as a placeholder while the
/// store query is in flight. A real build replaces it with the localised price
/// string the platform returns, which is what Apple and Google require.
class Product {
  const Product({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.fallbackPrice,
    this.coins = 0,
    this.crowns = 0,
    this.boosters = const <BoosterType, int>{},
    this.badge,
    this.bonusPercent = 0,
    this.highlight = false,
  });

  final String id;
  final ProductKind kind;
  final String title;
  final String description;

  /// Display-only placeholder price.
  final String fallbackPrice;

  final int coins;
  final int crowns;
  final Map<BoosterType, int> boosters;

  /// Small tag such as "BEST VALUE".
  final String? badge;

  /// Extra value versus the base pack, shown as "+15% bonus".
  final int bonusPercent;

  /// Renders with the premium treatment in the shop.
  final bool highlight;
}

/// The shipped catalogue.
///
/// Ids must match exactly what is configured in Google Play Console and App
/// Store Connect. See README → "Enabling real IAP".
abstract final class ProductCatalog {
  static const String starterPackId = 'starter_pack';
  static const String removeAdsId = 'remove_ads';

  static final List<Product> coinPacks = List<Product>.unmodifiable(<Product>[
    Product(
      id: 'coins_500',
      kind: ProductKind.consumable,
      title: 'Pouch of Coins',
      description: '${EconomyConfig.coinPackAmounts['coins_500']} coins',
      fallbackPrice: '£0.99',
      coins: EconomyConfig.coinPackAmounts['coins_500']!,
    ),
    Product(
      id: 'coins_1200',
      kind: ProductKind.consumable,
      title: 'Bag of Coins',
      description: '${EconomyConfig.coinPackAmounts['coins_1200']} coins',
      fallbackPrice: '£1.99',
      coins: EconomyConfig.coinPackAmounts['coins_1200']!,
      bonusPercent: 20,
    ),
    Product(
      id: 'coins_3000',
      kind: ProductKind.consumable,
      title: 'Chest of Coins',
      description: '${EconomyConfig.coinPackAmounts['coins_3000']} coins',
      fallbackPrice: '£3.99',
      coins: EconomyConfig.coinPackAmounts['coins_3000']!,
      bonusPercent: 50,
      badge: 'POPULAR',
    ),
    Product(
      id: 'coins_8000',
      kind: ProductKind.consumable,
      title: 'Vault of Coins',
      description: '${EconomyConfig.coinPackAmounts['coins_8000']} coins',
      fallbackPrice: '£7.99',
      coins: EconomyConfig.coinPackAmounts['coins_8000']!,
      bonusPercent: 100,
    ),
    Product(
      id: 'coins_25000',
      kind: ProductKind.consumable,
      title: 'Royal Treasury',
      description: '${EconomyConfig.coinPackAmounts['coins_25000']} coins',
      fallbackPrice: '£19.99',
      coins: EconomyConfig.coinPackAmounts['coins_25000']!,
      bonusPercent: 150,
      badge: 'BEST VALUE',
      highlight: true,
    ),
  ]);

  static final Product starterPack = Product(
    id: starterPackId,
    kind: ProductKind.nonConsumable,
    title: 'New Player Pack',
    description: 'A one-time bundle to get your kingdom moving.',
    fallbackPrice: '£1.99',
    coins: EconomyConfig.starterPackCoins,
    boosters: EconomyConfig.starterPackBoosters,
    badge: 'LIMITED OFFER',
    highlight: true,
  );

  static const Product removeAds = Product(
    id: removeAdsId,
    kind: ProductKind.nonConsumable,
    title: 'Remove Ads',
    description:
        'Removes all interstitial ads. Rewarded ads stay available if you '
        'want to use them.',
    fallbackPrice: '£3.99',
  );

  static List<Product> get all => <Product>[
    ...coinPacks,
    starterPack,
    removeAds,
  ];

  static Product? byId(String id) {
    for (final Product p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Ids to query the store with.
  static Set<String> get allIds => all.map((Product p) => p.id).toSet();

  static Set<String> get nonConsumableIds => all
      .where((Product p) => p.kind == ProductKind.nonConsumable)
      .map((Product p) => p.id)
      .toSet();
}

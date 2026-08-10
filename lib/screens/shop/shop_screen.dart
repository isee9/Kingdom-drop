import 'package:flutter/material.dart';

import '../../core/config/economy_config.dart';
import '../../core/utils/formatters.dart';
import '../../models/booster.dart';
import '../../monetisation/products.dart';
import '../../monetisation/purchase_service.dart';
import '../../services/analytics_service.dart';
import '../../services/service_locator.dart';
import '../../theme/app_art.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/currency_pill.dart';
import '../../widgets/game_icons.dart';
import '../../widgets/kd_button.dart';
import '../../widgets/kd_card.dart';

/// The shop.
///
/// Four sections: the starter offer (only while genuinely available), coin
/// packs, boosters bought with coins, and Remove Ads. Everything runs through
/// [PurchaseService], so in mock mode the whole screen is testable with no
/// store account.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const ShopScreen());

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? _busyProductId;

  @override
  void initState() {
    super.initState();
    final AppServices services = ServiceScope.read(context);
    services.analytics.screen('shop');
    services.analytics.log(AnalyticsEvents.shopOpened);
  }

  Future<void> _buy(String productId) async {
    if (_busyProductId != null) return;
    setState(() => _busyProductId = productId);

    final AppServices services = ServiceScope.read(context);
    final PurchaseResult result = await services.purchases.buy(productId);
    if (!mounted) return;

    setState(() => _busyProductId = null);

    final String message = switch (result.status) {
      PurchaseStatus.success => 'Purchase complete. Enjoy!',
      PurchaseStatus.alreadyOwned => 'You already own this.',
      PurchaseStatus.cancelled => 'Purchase cancelled.',
      PurchaseStatus.failed => result.message ?? 'Purchase failed.',
      PurchaseStatus.unavailable => 'That product is not available.',
    };

    if (result.isSuccess) services.haptics.reward();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _buyBooster(BoosterType type) {
    final AppServices services = ServiceScope.read(context);
    final bool ok = services.player.buyBooster(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${type.displayName} added to your boosters.'
              : 'Not enough coins for a ${type.displayName}.',
        ),
      ),
    );
    if (ok) services.haptics.reward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        scene: ArtScene.menu,
        child: SafeArea(
          child: PlayerBuilder(
            builder: (BuildContext context, player) {
              final bool starterAvailable = player.starterPackAvailable();

              return Column(
                children: <Widget>[
                  _buildHeader(context, player.coins, player.crowns),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: <Widget>[
                        if (starterAvailable) ...<Widget>[
                          const KdSectionHeader(title: 'Limited offer'),
                          _StarterPackCard(
                            remaining: player.starterPackRemaining(),
                            busy:
                                _busyProductId == ProductCatalog.starterPackId,
                            onBuy: () => _buy(ProductCatalog.starterPackId),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],

                        const KdSectionHeader(title: 'Coins'),
                        for (final Product product in ProductCatalog.coinPacks)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _CoinPackRow(
                              product: product,
                              price: ServiceScope.read(
                                context,
                              ).purchases.priceFor(product.id),
                              busy: _busyProductId == product.id,
                              onBuy: () => _buy(product.id),
                            ),
                          ),

                        const SizedBox(height: AppSpacing.lg),
                        const KdSectionHeader(title: 'Boosters'),
                        for (final BoosterType type in BoosterType.values)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _BoosterRow(
                              type: type,
                              owned: player.boosterCount(type),
                              cost: EconomyConfig.boosterCoinCost[type] ?? 0,
                              affordable:
                                  player.coins >=
                                  (EconomyConfig.boosterCoinCost[type] ?? 0),
                              onBuy: () => _buyBooster(type),
                            ),
                          ),

                        const SizedBox(height: AppSpacing.lg),
                        const KdSectionHeader(title: 'Remove ads'),
                        _RemoveAdsCard(
                          owned: player.adsRemoved,
                          price: ServiceScope.read(
                            context,
                          ).purchases.priceFor(ProductCatalog.removeAdsId),
                          busy: _busyProductId == ProductCatalog.removeAdsId,
                          onBuy: () => _buy(ProductCatalog.removeAdsId),
                        ),

                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Rewarded ads stay available after buying Remove Ads, '
                          'because those are always your choice.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int coins, int crowns) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          KdIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: StrokedText('SHOP', style: AppTextStyles.headline)),
          CurrencyPill(
            kind: CurrencyKind.crowns,
            amount: crowns,
            compact: true,
          ),
          const SizedBox(width: AppSpacing.sm),
          CurrencyPill(kind: CurrencyKind.coins, amount: coins, compact: true),
        ],
      ),
    );
  }
}

class _StarterPackCard extends StatelessWidget {
  const _StarterPackCard({
    required this.remaining,
    required this.busy,
    required this.onBuy,
  });

  final Duration remaining;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final Product pack = ProductCatalog.starterPack;

    return KdCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF4B3FC4), Color(0xFF7C3F9E)],
      ),
      borderColor: AppColors.gold.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  pack.badge!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textOnGold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              // A real countdown from the player's own first-open timestamp.
              // It never resets and the offer really does end.
              Text(
                'Ends in ${Formatters.countdown(remaining)}',
                style: AppTextStyles.caption.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(pack.title.toUpperCase(), style: AppTextStyles.headline),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              _PackItem(
                icon: const CoinIcon(size: 22),
                label: Formatters.number(pack.coins),
              ),
              for (final MapEntry<BoosterType, int> e in pack.boosters.entries)
                _PackItem(
                  icon: BoosterIcon(type: e.key, size: 24),
                  label: 'x${e.value}',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          KdButton(
            label: busy ? 'PURCHASING…' : 'GET IT — ${pack.fallbackPrice}',
            gradient: AppColors.goldGradient,
            size: KdButtonSize.large,
            expand: true,
            enabled: !busy,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}

class _PackItem extends StatelessWidget {
  const _PackItem({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          icon,
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPackRow extends StatelessWidget {
  const _CoinPackRow({
    required this.product,
    required this.price,
    required this.busy,
    required this.onBuy,
  });

  final Product product;
  final String price;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return KdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: product.highlight
          ? AppColors.gold.withValues(alpha: 0.5)
          : null,
      child: Row(
        children: <Widget>[
          CoinIcon(size: product.highlight ? 44 : 34),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        Formatters.number(product.coins),
                        style: AppTextStyles.title,
                      ),
                    ),
                    if (product.badge != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          product.badge!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  product.bonusPercent > 0
                      ? '${product.title} · +${product.bonusPercent}% value'
                      : product.title,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          KdButton(
            label: busy ? '…' : price,
            size: KdButtonSize.small,
            enabled: !busy,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}

class _BoosterRow extends StatelessWidget {
  const _BoosterRow({
    required this.type,
    required this.owned,
    required this.cost,
    required this.affordable,
    required this.onBuy,
  });

  final BoosterType type;
  final int owned;
  final int cost;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return KdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: boosterColor(type).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            padding: const EdgeInsets.all(4),
            child: BoosterIcon(type: type, size: 36),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(type.displayName, style: AppTextStyles.bodyStrong),
                    const SizedBox(width: AppSpacing.sm),
                    Text('owned $owned', style: AppTextStyles.caption),
                  ],
                ),
                Text(type.description, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          KdButton(
            label: '$cost',
            icon: Icons.monetization_on_rounded,
            size: KdButtonSize.small,
            color: affordable ? AppColors.primary : AppColors.surfaceHigh,
            enabled: affordable,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}

class _RemoveAdsCard extends StatelessWidget {
  const _RemoveAdsCard({
    required this.owned,
    required this.price,
    required this.busy,
    required this.onBuy,
  });

  final bool owned;
  final String price;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return KdCard(
      child: Row(
        children: <Widget>[
          Icon(
            owned ? Icons.verified_rounded : Icons.block_rounded,
            size: 34,
            color: owned ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ProductCatalog.removeAds.title,
                  style: AppTextStyles.bodyStrong,
                ),
                Text(
                  ProductCatalog.removeAds.description,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (owned)
            Text(
              'OWNED',
              style: AppTextStyles.label.copyWith(color: AppColors.success),
            )
          else
            KdButton(
              label: busy ? '…' : price,
              size: KdButtonSize.small,
              enabled: !busy,
              onPressed: onBuy,
            ),
        ],
      ),
    );
  }
}

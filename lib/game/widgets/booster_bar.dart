import 'package:flutter/material.dart';

import '../../core/config/economy_config.dart';
import '../../models/booster.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_icons.dart';
import '../controller/game_controller.dart';

/// The in-game booster strip.
///
/// A booster the player owns shows its count; one they do not shows its coin
/// price and buys on tap. Keeping both states in the same control means the
/// player never has to leave the board to restock.
class BoosterBar extends StatelessWidget {
  const BoosterBar({
    required this.controller,
    required this.coins,
    required this.onNeedCoins,
    super.key,
  });

  final GameController controller;
  final int coins;

  /// Called when the player taps a booster they cannot afford.
  final VoidCallback onNeedCoins;

  static const List<BoosterType> _inGame = <BoosterType>[
    BoosterType.hammer,
    BoosterType.bomb,
    BoosterType.shuffle,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (final BoosterType type in _inGame)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: _BoosterChip(
                  type: type,
                  count: controller.boosterCount(type),
                  armed: controller.armedBooster == type,
                  price: EconomyConfig.boosterCoinCost[type] ?? 0,
                  canAfford:
                      coins >= (EconomyConfig.boosterCoinCost[type] ?? 0),
                  onTap: () {
                    if (controller.boosterCount(type) > 0) {
                      controller.toggleBooster(type);
                    } else if (coins >= (EconomyConfig.boosterCoinCost[type] ?? 0)) {
                      controller.buyBooster(type);
                    } else {
                      onNeedCoins();
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BoosterChip extends StatelessWidget {
  const _BoosterChip({
    required this.type,
    required this.count,
    required this.armed,
    required this.price,
    required this.canAfford,
    required this.onTap,
  });

  final BoosterType type;
  final int count;
  final bool armed;
  final int price;
  final bool canAfford;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool owned = count > 0;
    final Color accent = boosterColor(type);

    return Semantics(
      button: true,
      label: owned
          ? '${type.displayName}, $count available'
          : '${type.displayName}, buy for $price coins',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 66,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: armed
                ? accent.withValues(alpha: 0.25)
                : AppColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: armed ? accent : AppColors.border,
              width: armed ? 2 : 1,
            ),
            boxShadow: armed
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                boosterIcon(type),
                size: 24,
                color: owned || canAfford
                    ? accent
                    : AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.xs),
              if (owned)
                Text(
                  'x$count',
                  style: AppTextStyles.currency.copyWith(fontSize: 13),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const CoinIcon(size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '$price',
                      style: AppTextStyles.caption.copyWith(
                        color: canAfford
                            ? AppColors.textSecondary
                            : AppColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

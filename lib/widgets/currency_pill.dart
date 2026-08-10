import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'game_icons.dart';

enum CurrencyKind { coins, crowns }

/// The coin / crown readout used in every header.
///
/// The value animates between changes so a reward reads as an increase rather
/// than a jump. Tapping opens the shop when [onTap] is supplied.
class CurrencyPill extends StatelessWidget {
  const CurrencyPill({
    required this.kind,
    required this.amount,
    this.onTap,
    this.showAdd = false,
    this.compact = false,
    super.key,
  });

  final CurrencyKind kind;
  final int amount;
  final VoidCallback? onTap;

  /// Shows a "+" affordance, used on the home header to reach the shop.
  final bool showAdd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double iconSize = compact ? 16 : 20;

    return Semantics(
      label:
          '${Formatters.number(amount)} '
          '${kind == CurrencyKind.coins ? 'coins' : 'crowns'}',
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.md,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (kind == CurrencyKind.coins)
                CoinIcon(size: iconSize)
              else
                CrownIcon(size: iconSize),
              SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm),
              _AnimatedCount(
                value: amount,
                style: AppTextStyles.currency.copyWith(
                  fontSize: compact ? 13 : 15,
                ),
              ),
              if (showAdd) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tweens an integer so currency counts up instead of snapping.
class _AnimatedCount extends StatelessWidget {
  const _AnimatedCount({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value.toDouble(), end: value.toDouble()),
      duration: AppDurations.slow,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, _) =>
          Text(Formatters.number(v.round()), style: style),
    );
  }
}

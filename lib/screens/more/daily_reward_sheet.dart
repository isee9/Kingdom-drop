import 'package:flutter/material.dart';

import '../../core/config/economy_config.dart';
import '../../models/booster.dart';
import '../../progression/daily_service.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_icons.dart';
import '../../widgets/kd_button.dart';
import '../../widgets/game_ui.dart';

/// The seven-day login streak.
///
/// Days are laid out as a row of tiles so the player can see the whole week and
/// what day seven holds. Missing a day restarts at day one — the sheet says so
/// rather than hiding it.
Future<void> showDailyRewardSheet(
  BuildContext context, {
  required AppServices services,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _DailyRewardSheet(services: services),
  );
}

class _DailyRewardSheet extends StatefulWidget {
  const _DailyRewardSheet({required this.services});

  final AppServices services;

  @override
  State<_DailyRewardSheet> createState() => _DailyRewardSheetState();
}

class _DailyRewardSheetState extends State<_DailyRewardSheet> {
  bool _justClaimed = false;

  void _claim() {
    final DailyRewardConfig? reward = widget.services.daily.claimDailyReward();
    if (reward == null) return;

    widget.services.audio.playTap();
    widget.services.haptics.reward();
    setState(() => _justClaimed = true);
  }

  @override
  Widget build(BuildContext context) {
    final DailyRewardStatus status = widget.services.daily.statusFor();
    final bool canClaim = status.canClaim && !_justClaimed;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StrokedText(
            'DAILY REWARD',
            style: AppTextStyles.headline,
            fillGradient: AppColors.goldGradient,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            status.streakBroken && canClaim
                ? 'You missed a day, so the streak restarts at day one.'
                : 'Come back each day for a bigger reward.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.xl),

          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final DailyRewardConfig day in EconomyConfig.dailyRewards)
                _DayTile(
                  config: day,
                  claimed:
                      day.day < status.claimableDay ||
                      (_justClaimed && day.day == status.claimableDay),
                  isToday: day.day == status.claimableDay,
                  claimable: canClaim && day.day == status.claimableDay,
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          if (canClaim)
            KdButton(
              label: 'CLAIM DAY ${status.claimableDay}',
              gradient: AppColors.goldGradient,
              size: KdButtonSize.large,
              expand: true,
              onPressed: _claim,
            )
          else
            KdButton.ghost(
              label: 'COME BACK TOMORROW',
              size: KdButtonSize.large,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.config,
    required this.claimed,
    required this.isToday,
    required this.claimable,
  });

  final DailyRewardConfig config;
  final bool claimed;
  final bool isToday;
  final bool claimable;

  @override
  Widget build(BuildContext context) {
    final bool isFinalDay = config.day == EconomyConfig.dailyStreakLength;

    return Container(
      width: isFinalDay ? 152 : 68,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: claimed
            ? AppColors.success.withValues(alpha: 0.14)
            : AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: claimable
              ? AppColors.gold
              : claimed
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.border,
          width: claimable ? 2 : 1,
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'DAY ${config.day}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isToday ? AppColors.gold : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (claimed)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 24,
            )
          else
            _rewardIcon(),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _rewardLabel(),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _rewardIcon() {
    if (config.chest) {
      return const Icon(
        Icons.inventory_2_rounded,
        color: AppColors.gold,
        size: 24,
      );
    }
    if (config.booster != null) {
      return Icon(
        boosterIcon(config.booster!),
        color: boosterColor(config.booster!),
        size: 24,
      );
    }
    return const CoinIcon(size: 24);
  }

  String _rewardLabel() {
    if (config.chest) return 'Mystery Chest';
    if (config.booster != null) {
      return '${config.booster!.displayName} x${config.boosterCount}';
    }
    return '${config.coins}';
  }
}

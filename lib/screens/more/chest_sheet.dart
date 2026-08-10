import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/booster.dart';
import '../../progression/chest_service.dart';
import '../../services/analytics_service.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_icons.dart';
import '../../widgets/kd_button.dart';

/// Opens a chest and shows what fell out.
///
/// The reward is rolled and banked immediately on open, so a player who
/// backgrounds the app mid-animation still keeps it.
Future<void> showChestSheet(
  BuildContext context, {
  required ChestTier tier,
  required AppServices services,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _ChestSheet(
      tier: tier,
      services: services,
    ),
  );
}

class _ChestSheet extends StatefulWidget {
  const _ChestSheet({required this.tier, required this.services});

  final ChestTier tier;
  final AppServices services;

  @override
  State<_ChestSheet> createState() => _ChestSheetState();
}

class _ChestSheetState extends State<_ChestSheet>
    with SingleTickerProviderStateMixin {
  late final ChestReward _reward;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _reward = widget.services.chests.open(widget.tier);

    // Bank straight away — the animation is presentation, not a gate.
    widget.services.player.addCoins(_reward.coins);
    widget.services.player.addCrowns(_reward.crowns);
    widget.services.player.grantBoosters(_reward.boosters);

    widget.services.analytics.log(
      AnalyticsEvents.chestOpened,
      <String, Object?>{
        'tier': widget.tier.name,
        'coins': _reward.coins,
        'crowns': _reward.crowns,
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _opened = true);
    _controller.forward();
    widget.services.audio.play(Sfx.chestOpened);
    widget.services.haptics.reward();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
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
          Text(
            widget.tier.displayName.toUpperCase(),
            style: AppTextStyles.headline,
          ),
          const SizedBox(height: AppSpacing.xl),

          _ChestArt(tier: widget.tier, opened: _opened, controller: _controller),

          const SizedBox(height: AppSpacing.xl),
          AnimatedSize(
            duration: AppDurations.normal,
            child: _opened
                ? _RewardList(reward: _reward, controller: _controller)
                : const SizedBox(height: 8),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_opened)
            KdButton(
              label: 'COLLECT',
              gradient: AppColors.playGradient,
              size: KdButtonSize.large,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            )
          else
            KdButton(
              label: 'OPEN',
              gradient: AppColors.goldGradient,
              size: KdButtonSize.large,
              expand: true,
              onPressed: _open,
            ),
        ],
      ),
    );
  }
}

/// The chest itself: a shaking box that pops its lid.
class _ChestArt extends StatelessWidget {
  const _ChestArt({
    required this.tier,
    required this.opened,
    required this.controller,
  });

  final ChestTier tier;
  final bool opened;
  final AnimationController controller;

  Color get _accent => switch (tier) {
    ChestTier.common => AppColors.info,
    ChestTier.rare => AppColors.primaryLight,
    ChestTier.kingdom => AppColors.gold,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final double t = controller.value;
        // Rattle, then a pop as the lid comes off.
        final double shake = t < 0.45
            ? (0.45 - t) * 0.16 * (t * 40 % 2 < 1 ? 1 : -1)
            : 0;
        final double scale = 1 + Curves.easeOutBack.transform(
              (t.clamp(0.45, 1.0) - 0.45) / 0.55,
            ) * 0.12;

        return Transform.rotate(
          angle: shake,
          child: Transform.scale(scale: opened ? scale : 1, child: child),
        );
      },
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              _accent.withValues(alpha: 0.9),
              Color.lerp(_accent, Colors.black, 0.45)!,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _accent.withValues(alpha: 0.4),
              blurRadius: 30,
            ),
          ],
        ),
        child: Icon(
          opened ? Icons.auto_awesome_rounded : Icons.inventory_2_rounded,
          size: 60,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RewardList extends StatelessWidget {
  const _RewardList({required this.reward, required this.controller});

  final ChestReward reward;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tiles = <Widget>[
      if (reward.coins > 0)
        _RewardTile(
          icon: const CoinIcon(size: 26),
          label: Formatters.number(reward.coins),
        ),
      if (reward.crowns > 0)
        _RewardTile(
          icon: const CrownIcon(size: 26),
          label: Formatters.number(reward.crowns),
        ),
      for (final MapEntry<BoosterType, int> e in reward.boosters.entries)
        _RewardTile(
          icon: Icon(boosterIcon(e.key), size: 26, color: boosterColor(e.key)),
          label: 'x${e.value}',
        ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: <Widget>[
        for (int i = 0; i < tiles.length; i++)
          FadeTransition(
            opacity: CurvedAnimation(
              parent: controller,
              curve: Interval(
                (0.5 + i * 0.1).clamp(0.0, 0.95),
                1,
                curve: Curves.easeOut,
              ),
            ),
            child: tiles[i],
          ),
      ],
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          icon,
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTextStyles.currency.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

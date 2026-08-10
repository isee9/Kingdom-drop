import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../core/config/kingdom_config.dart';
import '../../core/utils/formatters.dart';
import '../../economy/player_service.dart';
import '../../progression/chest_service.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/currency_pill.dart';
import '../../widgets/game_icons.dart';
import '../../widgets/kd_button.dart';
import '../../widgets/kd_card.dart';
import '../more/chest_sheet.dart';
import 'kingdom_complete_sheet.dart';
import 'kingdom_view.dart';

/// The kingdom screen: spend crowns, watch the realm come back.
class KingdomScreen extends StatefulWidget {
  const KingdomScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const KingdomScreen());

  @override
  State<KingdomScreen> createState() => _KingdomScreenState();
}

class _KingdomScreenState extends State<KingdomScreen> {
  late final AppServices _services;

  /// Index of the upgrade currently playing its restoration animation.
  int? _animatingIndex;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _services = ServiceScope.read(context);
    _services.analytics.screen('kingdom');
  }

  Future<void> _buyUpgrade() async {
    if (_busy) return;

    final PlayerService player = _services.player;
    final KingdomUpgrade? next = player.nextUpgrade;
    if (next == null) return;

    if (!player.canAffordNextUpgrade) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You need ${next.cost - player.crowns} more crowns. '
            'Play a run to earn them.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
      _animatingIndex = next.index;
    });

    final UpgradeOutcome outcome = player.buyNextUpgrade();
    _services.audio.play(Sfx.kingdomUpgrade);
    _services.haptics.reward();

    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;

    setState(() {
      _busy = false;
      _animatingIndex = null;
    });

    if (outcome == UpgradeOutcome.kingdomComplete) {
      await _celebrateCompletion();
    }
  }

  Future<void> _celebrateCompletion() async {
    final PlayerService player = _services.player;
    final KingdomDefinition finished = player.currentKingdom;

    await showKingdomCompleteSheet(
      context,
      kingdom: finished,
      services: _services,
    );
    if (!mounted) return;

    // The kingdom chest is the reward for finishing a realm.
    await showChestSheet(context, tier: ChestTier.kingdom, services: _services);
    if (!mounted) return;

    final bool advanced = player.advanceToNextKingdom();
    if (mounted) setState(() {});

    if (!advanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Every kingdom is restored. More realms are on the way.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: PlayerBuilder(
            builder: (BuildContext context, PlayerService player) {
              final KingdomDefinition kingdom = player.currentKingdom;
              final int done = player.currentKingdomUpgradesDone;
              final KingdomUpgrade? next = player.nextUpgrade;

              return Column(
                children: <Widget>[
                  _buildHeader(context, player),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: <Widget>[
                        KingdomView(
                          kingdom: kingdom,
                          upgradesDone: done,
                          animateTo: _animatingIndex,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          kingdom.name.toUpperCase(),
                          style: AppTextStyles.headline.copyWith(
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(kingdom.blurb, style: AppTextStyles.body),
                        const SizedBox(height: AppSpacing.md),
                        KdProgressBar(value: done / kingdom.upgradeCount),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '$done of ${kingdom.upgradeCount} restored',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        for (final KingdomUpgrade upgrade in kingdom.upgrades)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _UpgradeRow(
                              upgrade: upgrade,
                              done: upgrade.index < done,
                              isNext: upgrade.index == done,
                              affordable: player.crowns >= upgrade.cost,
                            ),
                          ),

                        const SizedBox(height: AppSpacing.lg),
                        _RealmProgress(
                          currentIndex: kingdom.index,
                          completed: player.data.stats.kingdomsCompleted,
                        ),
                      ],
                    ),
                  ),
                  if (next != null)
                    _buildActionBar(player, next)
                  else
                    _buildCompleteBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PlayerService player) {
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
          Expanded(
            child: StrokedText('KINGDOM', style: AppTextStyles.headline),
          ),
          CurrencyPill(
            kind: CurrencyKind.crowns,
            amount: player.crowns,
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(PlayerService player, KingdomUpgrade next) {
    final bool affordable = player.crowns >= next.cost;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow.withValues(alpha: 0.9),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'NEXT: ${next.name.toUpperCase()}',
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          KdButton(
            label: affordable ? 'RESTORE' : 'NOT ENOUGH CROWNS',
            gradient: affordable
                ? AppColors.goldGradient
                : const LinearGradient(
                    colors: <Color>[
                      AppColors.surfaceHigh,
                      AppColors.surfaceHigh,
                    ],
                  ),
            size: KdButtonSize.large,
            expand: true,
            badge: '${next.cost}',
            enabled: !_busy,
            onPressed: _buyUpgrade,
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.success.withValues(alpha: 0.12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.verified_rounded, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'KINGDOM RESTORED',
            style: AppTextStyles.label.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.upgrade,
    required this.done,
    required this.isNext,
    required this.affordable,
  });

  final KingdomUpgrade upgrade;
  final bool done;
  final bool isNext;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    return KdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: done ? AppColors.surfaceLow : AppColors.surface,
      borderColor: isNext ? AppColors.gold.withValues(alpha: 0.55) : null,
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: done
                  ? AppColors.success.withValues(alpha: 0.2)
                  : AppColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.success,
                  )
                : Text(
                    '${upgrade.index + 1}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              upgrade.name,
              style: done
                  ? AppTextStyles.body.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textMuted,
                    )
                  : AppTextStyles.bodyStrong,
            ),
          ),
          if (!done)
            Row(
              children: <Widget>[
                const CrownIcon(size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  Formatters.number(upgrade.cost),
                  style: AppTextStyles.currency.copyWith(
                    fontSize: 14,
                    color: affordable
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The ten-realm ladder, so the player can see what is ahead.
class _RealmProgress extends StatelessWidget {
  const _RealmProgress({required this.currentIndex, required this.completed});

  final int currentIndex;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return KdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const KdSectionHeader(title: 'All realms'),
          for (final KingdomDefinition kingdom in KingdomConfig.kingdoms)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: <Widget>[
                  Icon(
                    kingdom.index < currentIndex
                        ? Icons.check_circle_rounded
                        : kingdom.index == currentIndex
                        ? Icons.play_circle_fill_rounded
                        : Icons.lock_rounded,
                    size: 18,
                    color: kingdom.index < currentIndex
                        ? AppColors.success
                        : kingdom.index == currentIndex
                        ? AppColors.gold
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      kingdom.index <= currentIndex
                          ? kingdom.name
                          : 'Realm ${kingdom.index + 1}',
                      style: kingdom.index == currentIndex
                          ? AppTextStyles.bodyStrong
                          : AppTextStyles.body.copyWith(
                              color: AppColors.textMuted,
                            ),
                    ),
                  ),
                  if (kingdom.index <= currentIndex)
                    Text('${kingdom.totalCost}', style: AppTextStyles.caption),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/config/kingdom_config.dart';
import '../../core/utils/formatters.dart';
import '../../economy/player_service.dart';
import '../../game/controller/game_controller.dart';
import '../../game/engine/game_engine.dart';
import '../../monetisation/ad_service.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/game_icons.dart';
import '../../widgets/kd_button.dart';
import '../../widgets/kd_card.dart';

enum SummaryChoice { playAgain, home }

/// End-of-run summary.
///
/// The run's rewards are banked the moment this screen opens, not when a button
/// is pressed. Holding them until a tap means a player who is interrupted — the
/// phone rings, the OS reclaims the app — comes back to find the run they just
/// played paid nothing, and losing earned progress is never an acceptable
/// outcome. Watching the rewarded ad then grants a second helping on top, which
/// keeps "double" a genuine choice with nothing at risk either way.
class GameSummaryScreen extends StatefulWidget {
  const GameSummaryScreen({
    required this.controller,
    required this.services,
    super.key,
  });

  static Route<SummaryChoice> route({
    required GameController controller,
    required AppServices services,
  }) {
    return PageRouteBuilder<SummaryChoice>(
      opaque: false,
      barrierColor: Colors.black54,
      transitionDuration: AppDurations.normal,
      pageBuilder: (_, _, _) =>
          GameSummaryScreen(controller: controller, services: services),
      transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
    );
  }

  final GameController controller;
  final AppServices services;

  @override
  State<GameSummaryScreen> createState() => _GameSummaryScreenState();
}

class _GameSummaryScreenState extends State<GameSummaryScreen> {
  late final int _baseCrowns = widget.controller.engine.crownsEarned;
  late final int _baseCoins = widget.controller.engine.coinsEarned;
  late final int _xp = widget.controller.engine.xpEarned;

  bool _doubled = false;
  bool _busy = false;

  int get _crowns => _doubled ? _baseCrowns * 2 : _baseCrowns;
  int get _coins => _doubled ? _baseCoins * 2 : _baseCoins;

  @override
  void initState() {
    super.initState();
    widget.services.analytics.screen('game_summary');

    // Bank the run immediately — see the class comment.
    widget.services.player.grantRunRewards(
      crowns: _baseCrowns,
      coins: _baseCoins,
      xp: _xp,
    );
    if (_baseCrowns > 0 || _baseCoins > 0) widget.services.haptics.reward();
  }

  Future<void> _watchAdToDouble() async {
    if (_busy || _doubled) return;
    setState(() => _busy = true);

    final RewardedAdResult result = await widget.services.ads.showRewardedAd(
      AdPlacement.doubleCrowns,
    );
    if (!mounted) return;

    if (result == RewardedAdResult.earned) {
      // The base payout is already banked, so the ad grants the second helping.
      widget.services.player.grantRunRewards(
        crowns: _baseCrowns,
        coins: _baseCoins,
        xp: 0, // XP is not doubled: levels pace the game, ads should not.
      );
      setState(() {
        _doubled = true;
        _busy = false;
      });
      widget.services.haptics.reward();
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == RewardedAdResult.dismissed
                ? 'Ad closed early — rewards not doubled.'
                : 'No ad available right now.',
          ),
        ),
      );
    }
  }

  void _leave(SummaryChoice choice) => Navigator.of(context).pop(choice);

  @override
  Widget build(BuildContext context) {
    final GameStats stats = widget.controller.stats;
    final bool isBest =
        stats.score >= widget.services.player.bestScore && stats.score > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) _leave(SummaryChoice.home);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GameBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                children: <Widget>[
                  const Spacer(),
                  RibbonBanner(
                    text: isBest ? 'NEW BEST!' : 'GAME OVER',
                    color: isBest ? AppColors.gold : AppColors.danger,
                    edgeColor: isBest
                        ? AppColors.goldDark
                        : AppColors.dangerDark,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CountUpScore(score: stats.score),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Best ${Formatters.number(widget.services.player.bestScore)}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _RewardRow(crowns: _crowns, coins: _coins, xp: _xp),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Added to your kingdom',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _StatsGrid(stats: stats),
                  const SizedBox(height: AppSpacing.lg),
                  _KingdomNudge(player: widget.services.player),

                  const Spacer(),

                  if (!_doubled)
                    KdButton(
                      label: 'DOUBLE REWARDS — WATCH AD',
                      icon: Icons.play_circle_fill_rounded,
                      gradient: AppColors.goldGradient,
                      size: KdButtonSize.large,
                      expand: true,
                      enabled: !_busy && widget.services.ads.isRewardedReady,
                      onPressed: _watchAdToDouble,
                    )
                  else
                    Container(
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'REWARDS DOUBLED',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: KdButton.ghost(
                          label: 'HOME',
                          size: KdButtonSize.large,
                          expand: true,
                          enabled: !_busy,
                          onPressed: () => _leave(SummaryChoice.home),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: KdButton(
                          label: 'PLAY AGAIN',
                          gradient: AppColors.playGradient,
                          size: KdButtonSize.large,
                          expand: true,
                          enabled: !_busy,
                          onPressed: () => _leave(SummaryChoice.playAgain),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountUpScore extends StatelessWidget {
  const _CountUpScore({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: score.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, _) => StrokedText(
        Formatters.number(value.round()),
        strokeWidth: 6,
        style: AppTextStyles.logo.copyWith(fontSize: 58, letterSpacing: 1),
        fillGradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFFF6D0), Color(0xFFFFB61F)],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.crowns,
    required this.coins,
    required this.xp,
  });

  final int crowns;
  final int coins;
  final int xp;

  @override
  Widget build(BuildContext context) {
    return KdCard(
      gradient: LinearGradient(
        colors: <Color>[
          AppColors.surfaceHigh,
          AppColors.surface.withValues(alpha: 0.9),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _RewardTile(
              icon: const CrownIcon(size: 28),
              value: crowns,
              label: 'CROWNS',
            ),
          ),
          Container(width: 1, height: 44, color: AppColors.border),
          Expanded(
            child: _RewardTile(
              icon: const CoinIcon(size: 28),
              value: coins,
              label: 'COINS',
            ),
          ),
          Container(width: 1, height: 44, color: AppColors.border),
          Expanded(
            child: _RewardTile(
              icon: const Icon(
                Icons.auto_awesome_rounded,
                size: 26,
                color: AppColors.primaryLight,
              ),
              value: xp,
              label: 'XP',
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final Widget icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        icon,
        const SizedBox(height: AppSpacing.sm),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.toDouble()),
          duration: AppDurations.slow,
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double v, _) => Text(
            '+${Formatters.number(v.round())}',
            style: AppTextStyles.title,
          ),
        ),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

/// Ties the run just finished back to the kingdom it paid for.
///
/// This is the whole reason the puzzle has a meta layer, so the summary says it
/// out loud: here is the next repair, and here is exactly how close you are.
class _KingdomNudge extends StatelessWidget {
  const _KingdomNudge({required this.player});

  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    final KingdomDefinition kingdom = player.currentKingdom;
    final KingdomUpgrade? next = player.nextUpgrade;

    if (next == null) {
      return KdCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            const Icon(Icons.verified_rounded, color: AppColors.success),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '${kingdom.name} is fully restored.',
                style: AppTextStyles.bodyStrong,
              ),
            ),
          ],
        ),
      );
    }

    final int shortfall = next.cost - player.crowns;
    final double progress = (player.crowns / next.cost).clamp(0.0, 1.0);

    return KdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const CrownIcon(size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  next.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong,
                ),
              ),
              Text(
                '${Formatters.number(player.crowns)} / '
                '${Formatters.number(next.cost)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          KdProgressBar(value: progress, height: 8),
          const SizedBox(height: AppSpacing.xs),
          Text(
            shortfall <= 0
                ? 'You can afford this repair now.'
                : '$shortfall more crowns to go.',
            style: AppTextStyles.caption.copyWith(
              color: shortfall <= 0 ? AppColors.success : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final GameStats stats;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> entries = <(String, String)>[
      ('Lines cleared', Formatters.number(stats.linesCleared)),
      ('Combos', Formatters.number(stats.combosTriggered)),
      ('Pieces placed', Formatters.number(stats.piecesPlaced)),
      ('Best combo', 'x${stats.bestComboDepth}'),
    ];

    return KdCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: <Widget>[
          for (final (String label, String value) in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(label, style: AppTextStyles.body),
                  Text(value, style: AppTextStyles.bodyStrong),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

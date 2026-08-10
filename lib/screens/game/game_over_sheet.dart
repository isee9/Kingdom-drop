import 'package:flutter/material.dart';

import '../../core/config/economy_config.dart';
import '../../core/utils/formatters.dart';
import '../../game/controller/game_controller.dart';
import '../../models/booster.dart';
import '../../monetisation/ad_service.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_icons.dart';
import '../../widgets/kd_button.dart';
import 'game_screen.dart';

enum OutOfMovesChoice { continued, ended }

/// The "no more moves" panel.
///
/// Offers the three continue routes — coins, a rewarded ad, or a Second Chance
/// the player already owns — and is dismissible only through an explicit
/// choice, so a stray tap cannot throw away a good run.
Future<OutOfMovesChoice?> showGameOverSheet(
  BuildContext context, {
  required GameController controller,
  required AppServices services,
}) {
  return showModalBottomSheet<OutOfMovesChoice>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _OutOfMovesSheet(
      controller: controller,
      services: services,
    ),
  );
}

class _OutOfMovesSheet extends StatefulWidget {
  const _OutOfMovesSheet({required this.controller, required this.services});

  final GameController controller;
  final AppServices services;

  @override
  State<_OutOfMovesSheet> createState() => _OutOfMovesSheetState();
}

class _OutOfMovesSheetState extends State<_OutOfMovesSheet> {
  bool _busy = false;

  GameController get _controller => widget.controller;
  AppServices get _services => widget.services;

  Future<void> _continueWithCoins() async {
    if (_busy) return;
    setState(() => _busy = true);

    final bool ok = _controller.continueWithCoins();
    if (!mounted) return;

    if (!ok) {
      setState(() => _busy = false);
      _showMessage('Not enough coins.');
      return;
    }
    Navigator.of(context).pop(OutOfMovesChoice.continued);
  }

  Future<void> _continueWithAd() async {
    if (_busy) return;
    setState(() => _busy = true);

    final RewardedAdResult result = await _services.ads.showRewardedAd(
      AdPlacement.continueGame,
    );
    if (!mounted) return;

    if (result != RewardedAdResult.earned) {
      setState(() => _busy = false);
      _showMessage(
        result == RewardedAdResult.dismissed
            ? 'Ad closed early — no continue awarded.'
            : 'No ad available right now.',
      );
      return;
    }

    final bool ok = _controller.continueWithAd();
    if (!mounted) return;

    if (!ok) {
      setState(() => _busy = false);
      _showMessage('Could not continue.');
      return;
    }
    Navigator.of(context).pop(OutOfMovesChoice.continued);
  }

  Future<void> _useSecondChance() async {
    if (_busy) return;
    _controller.toggleBooster(BoosterType.secondChance);
    if (!mounted) return;

    if (_controller.phase == GamePhase.playing) {
      Navigator.of(context).pop(OutOfMovesChoice.continued);
    } else {
      _showMessage('That did not free up enough space.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int secondChances = _services.player.boosterCount(
      BoosterType.secondChance,
    );
    final bool canContinue = _controller.canContinue;
    final int coins = _services.player.coins;
    final bool affordable = coins >= EconomyConfig.continueCostCoins;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const GameSheetHeader(
            title: 'NO MORE MOVES',
            subtitle: 'None of your pieces fit. Clear some space to keep going.',
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Score ${Formatters.number(_controller.score)}',
                style: AppTextStyles.bodyStrong,
              ),
              const SizedBox(width: AppSpacing.lg),
              const SheetCoinBalance(),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (canContinue) ...<Widget>[
            if (secondChances > 0) ...<Widget>[
              KdButton(
                label: 'USE SECOND CHANCE',
                icon: Icons.favorite_rounded,
                gradient: AppColors.playGradient,
                size: KdButtonSize.large,
                expand: true,
                badge: 'x$secondChances',
                enabled: !_busy,
                onPressed: _useSecondChance,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            KdButton(
              label: 'WATCH AD — CONTINUE FREE',
              icon: Icons.play_circle_fill_rounded,
              gradient: AppColors.primaryGradient,
              size: KdButtonSize.large,
              expand: true,
              enabled: !_busy && _services.ads.isRewardedReady,
              onPressed: _continueWithAd,
            ),
            const SizedBox(height: AppSpacing.md),
            KdButton(
              label: 'CONTINUE',
              icon: Icons.bolt_rounded,
              color: AppColors.surfaceHigh,
              size: KdButtonSize.large,
              expand: true,
              badge: '${EconomyConfig.continueCostCoins}',
              enabled: !_busy && affordable,
              onPressed: _continueWithCoins,
            ),
            if (!affordable)
              sheetHint(
                'You need ${Formatters.number(EconomyConfig.continueCostCoins - coins)} '
                'more coins for a paid continue.',
              ),
            sheetHint(
              '${_controller.engine.continuesRemaining} of '
              '${EconomyConfig.maxContinuesPerGame} continues left this run.',
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: <Widget>[
                  const CrownIcon(size: 22),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'You have used every continue this run. Time to bank '
                      'your crowns.',
                      style: AppTextStyles.body,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.lg),
          KdButton.ghost(
            label: 'END GAME',
            expand: true,
            enabled: !_busy,
            onPressed: () =>
                Navigator.of(context).pop(OutOfMovesChoice.ended),
          ),
        ],
      ),
    );
  }
}

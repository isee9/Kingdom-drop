import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/kd_button.dart';
import '../controller/game_controller.dart';

/// Score, best score and combo readout at the top of the game screen.
class GameHud extends StatelessWidget {
  const GameHud({required this.controller, required this.onPause, super.key});

  final GameController controller;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            GameChip(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'BEST ${Formatters.number(controller.bestScore)}',
                        style: AppTextStyles.caption.copyWith(
                          color: controller.isNewBest
                              ? AppColors.gold
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (controller.isNewBest) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 14,
                          color: AppColors.gold,
                        ),
                      ],
                    ],
                  ),
                  _ScoreReadout(score: controller.score),
                ],
              ),
            ),
            const Spacer(),
            _ComboBadge(
              active: controller.comboActive,
              multiplier: controller.comboMultiplier,
            ),
            const SizedBox(width: AppSpacing.sm),
            KdIconButton(
              icon: Icons.pause_rounded,
              tooltip: 'Pause',
              onPressed: onPause,
            ),
          ],
        );
      },
    );
  }
}

/// Counts the score up rather than snapping, which makes a big clear land.
class _ScoreReadout extends StatelessWidget {
  const _ScoreReadout({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: score.toDouble(), end: score.toDouble()),
      duration: AppDurations.slow,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, _) => StrokedText(
        Formatters.number(value.round()),
        strokeWidth: 4.5,
        style: AppTextStyles.scoreValue,
        fillGradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.white, Color(0xFFBBD2F5)],
        ),
      ),
    );
  }
}

/// Combo multiplier pill. Hidden entirely at x1 so the HUD stays quiet until
/// there is something to celebrate.
class _ComboBadge extends StatelessWidget {
  const _ComboBadge({required this.active, required this.multiplier});

  final bool active;
  final double multiplier;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: AppDurations.normal,
      curve: Curves.easeOutBack,
      scale: active ? 1 : 0,
      child: AnimatedOpacity(
        duration: AppDurations.fast,
        opacity: active ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.45),
                blurRadius: 14,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: AppColors.textOnGold,
              ),
              const SizedBox(width: AppSpacing.xs),
              StrokedText(
                Formatters.multiplier(multiplier),
                strokeWidth: 3,
                strokeColor: AppColors.goldEdge,
                style: AppTextStyles.currency.copyWith(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating "+120" numbers that rise off the board and fade.
class FloatingScoreLayer extends StatelessWidget {
  const FloatingScoreLayer({
    required this.controller,
    required this.cellSize,
    super.key,
  });

  final GameController controller;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return IgnorePointer(
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (final FloatingScore score in controller.floatingScores)
                _FloatingScoreText(
                  key: ValueKey<int>(score.id),
                  score: score,
                  cellSize: cellSize,
                  onDone: () => controller.consumeFloatingScore(score.id),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FloatingScoreText extends StatefulWidget {
  const _FloatingScoreText({
    required this.score,
    required this.cellSize,
    required this.onDone,
    super.key,
  });

  final FloatingScore score;
  final double cellSize;
  final VoidCallback onDone;

  @override
  State<_FloatingScoreText> createState() => _FloatingScoreTextState();
}

class _FloatingScoreTextState extends State<_FloatingScoreText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool emphatic = widget.score.emphasis >= 2;
    final double left = widget.score.anchor.dx * widget.cellSize;
    final double top = widget.score.anchor.dy * widget.cellSize;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        final double rise =
            Curves.easeOutCubic.transform(t) * widget.cellSize * 2.2;
        final double opacity = t < 0.15
            ? t / 0.15
            : (1 - ((t - 0.15) / 0.85)).clamp(0.0, 1.0);
        final double scale =
            0.7 +
            0.5 * Curves.easeOutBack.transform((t / 0.35).clamp(0.0, 1.0));

        return Positioned(
          left: left - 60,
          top: top - rise,
          width: 120,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: StrokedText(
        widget.score.text,
        strokeWidth: emphatic ? 5 : 4,
        style: TextStyle(
          fontSize: emphatic ? 28 : 21,
          fontWeight: FontWeight.w900,
          color: emphatic ? AppColors.gold : AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

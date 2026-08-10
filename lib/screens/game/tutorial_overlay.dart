import 'package:flutter/material.dart';

import '../../game/controller/game_controller.dart';
import '../../game/widgets/board_view.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_icons.dart';
import '../../widgets/kd_button.dart';

/// First-run tutorial.
///
/// Five short beats, taught by doing rather than reading:
///
/// 1. Drag a piece onto the board (the board is seeded so this first drag
///    completes a row).
/// 2. That was a clear.
/// 3. Clears score points, and points become crowns.
/// 4. Crowns rebuild your kingdom.
///
/// Step one is fully interactive — the overlay does not swallow the drag — and
/// a Skip control appears as soon as the player has made that first move, which
/// is the point at which the core interaction is understood.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    required this.controller,
    required this.boardOrigin,
    required this.geometry,
    required this.onFinished,
    super.key,
  });

  final GameController controller;
  final Offset boardOrigin;
  final BoardGeometry geometry;
  final VoidCallback onFinished;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _step = 0;
  bool _firstPlacementCleared = false;

  @override
  void initState() {
    super.initState();
    // The guided board is seeded by GameScreen before the first build.
    widget.controller.addListener(_onGameChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGameChanged);
    super.dispose();
  }

  void _onGameChanged() {
    if (_step != 0) return;
    if (widget.controller.stats.piecesPlaced < 1) return;

    _firstPlacementCleared = widget.controller.stats.linesCleared > 0;
    // Let the clear animation land before the next card appears.
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted && _step == 0) setState(() => _step = 1);
    });
  }

  void _next() {
    if (_step >= _cards.length) {
      widget.onFinished();
    } else {
      setState(() => _step++);
    }
  }

  List<_TutorialCard> get _cards => <_TutorialCard>[
    _TutorialCard(
      icon: Icons.check_circle_rounded,
      accent: AppColors.success,
      title: _firstPlacementCleared ? 'That is a clear!' : 'Nicely placed',
      body: _firstPlacementCleared
          ? 'Fill a whole row, column or 3x3 block and it clears away, '
                'making room for more.'
          : 'Fill a whole row, column or 3x3 block and it clears away, '
                'making room for more.',
    ),
    const _TutorialCard(
      icon: Icons.local_fire_department_rounded,
      accent: AppColors.gold,
      title: 'Clear more at once',
      body: 'Two or more clears from a single piece builds a combo, and every '
          'combo multiplies your score.',
    ),
    const _TutorialCard(
      icon: null,
      accent: AppColors.crown,
      title: 'Points become crowns',
      body: 'Every run pays out crowns based on your score. Crowns are what '
          'rebuild your kingdom.',
      showCrown: true,
    ),
    const _TutorialCard(
      icon: Icons.castle_rounded,
      accent: AppColors.primaryLight,
      title: 'Rebuild the Forgotten Keep',
      body: 'Spend crowns on repairs. Finish all five and a new kingdom opens '
          'up. That is the whole game — drag, clear, conquer.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_step == 0) return _buildFirstMoveCoach();
    return _buildCard(_cards[_step - 1]);
  }

  /// Step one leaves the game fully interactive; only the prompt is drawn.
  Widget _buildFirstMoveCoach() {
    final double trayTop =
        widget.boardOrigin.dy + widget.geometry.extent + 110;

    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: widget.boardOrigin.dy + widget.geometry.extent * 0.34,
            child: _Prompt(
              title: 'Drag a piece onto the board',
              body: 'Hold a piece and slide it into place. It cannot be moved '
                  'once you let go.',
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: trayTop,
            child: const Center(child: _BouncingHint()),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_TutorialCard card) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: widget.onFinished,
                  child: Text(
                    'SKIP',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: card.accent.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (card.showCrown)
                      const CrownIcon(size: 52)
                    else
                      Icon(card.icon, size: 48, color: card.accent),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      card.title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headline,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      card.body,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    KdButton(
                      label: _step >= _cards.length ? 'START PLAYING' : 'GOT IT',
                      gradient: AppColors.playGradient,
                      size: KdButtonSize.large,
                      expand: true,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '$_step of ${_cards.length}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialCard {
  const _TutorialCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    this.showCrown = false,
  });

  final IconData? icon;
  final Color accent;
  final String title;
  final String body;
  final bool showCrown;
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

/// A finger hint that bobs upward, pointing from the tray to the board.
class _BouncingHint extends StatefulWidget {
  const _BouncingHint();

  @override
  State<_BouncingHint> createState() => _BouncingHintState();
}

class _BouncingHintState extends State<_BouncingHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => Transform.translate(
        offset: Offset(0, -16 * Curves.easeInOut.transform(_controller.value)),
        child: child,
      ),
      child: const Icon(
        Icons.arrow_upward_rounded,
        size: 34,
        color: AppColors.gold,
        shadows: <Shadow>[
          Shadow(color: Colors.black54, blurRadius: 8),
        ],
      ),
    );
  }
}

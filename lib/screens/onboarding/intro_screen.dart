import 'package:flutter/material.dart';

import '../../core/config/kingdom_config.dart';
import '../../services/service_locator.dart';
import '../../theme/app_art.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/kd_button.dart';
import '../game/game_screen.dart';
import '../home/home_screen.dart';
import '../kingdom/kingdom_view.dart';

/// First-launch story beat.
///
/// Two lines of setup over the ruined Forgotten Keep, then straight into a
/// game. The whole thing is well under twenty seconds and can be skipped from
/// the first frame — nobody should be held hostage by an intro.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );

  static const List<String> _lines = <String>[
    'Your kingdom has fallen…',
    'Every puzzle helps rebuild it.',
  ];

  @override
  void initState() {
    super.initState();
    _controller.forward();
    ServiceScope.read(context).analytics.screen('intro');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _begin() {
    final AppServices services = ServiceScope.read(context);
    services.player.markIntroSeen();

    // Straight into the tutorial run; Home sits underneath so backing out of
    // the game lands somewhere sensible.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: AppDurations.slow,
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    Navigator.of(context).push(GameScreen.route());
  }

  @override
  Widget build(BuildContext context) {
    final KingdomDefinition keep = KingdomConfig.byIndex(0);

    return Scaffold(
      body: GameBackground(
        scene: ArtScene.kingdom,
        child: SafeArea(
          // The intro has a lot of vertical content. On a short screen the
          // fixed Spacers would overflow, so the whole thing scrolls while
          // still filling and centring on a tall one.
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(child: _buildContent(keep)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(KingdomDefinition keep) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: _begin,
              child: Text(
                'SKIP',
                style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
          const Spacer(),

          // The ruin, with nothing yet restored.
          _FadeIn(
            controller: _controller,
            start: 0,
            end: 0.18,
            child: GamePanel(
              padding: const EdgeInsets.all(6),
              studs: true,
              child: KingdomView(kingdom: keep, upgradesDone: 0),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          _FadeIn(
            controller: _controller,
            start: 0.20,
            end: 0.36,
            child: StrokedText(
              keep.name.toUpperCase(),
              strokeWidth: 4.5,
              style: AppTextStyles.headline.copyWith(letterSpacing: 2),
              fillGradient: AppColors.goldGradient,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          _FadeIn(
            controller: _controller,
            start: 0.34,
            end: 0.50,
            child: Text(
              _lines[0],
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FadeIn(
            controller: _controller,
            start: 0.56,
            end: 0.72,
            child: Text(
              _lines[1],
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(color: AppColors.gold),
            ),
          ),

          const Spacer(),
          _FadeIn(
            controller: _controller,
            start: 0.74,
            end: 0.9,
            child: KdButton(
              label: 'PLAY',
              gradient: AppColors.playGradient,
              size: KdButtonSize.hero,
              expand: true,
              onPressed: _begin,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Fades and lifts a child over a slice of the parent timeline.
class _FadeIn extends StatelessWidget {
  const _FadeIn({
    required this.controller,
    required this.start,
    required this.end,
    required this.child,
  });

  final AnimationController controller;
  final double start;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

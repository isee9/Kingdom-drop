import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/service_locator.dart';
import '../../theme/app_art.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/kingdom_logo.dart';
import '../home/home_screen.dart';
import '../onboarding/intro_screen.dart';

/// Launch screen.
///
/// Deliberately brief: the painted logo animates in over the castle at sunset,
/// holds for a beat, and hands off. Services are already loaded by the time
/// this builds, so the delay here is purely for the brand moment, not for work.
///
/// The logo artwork already contains the wordmark and the tagline ribbon, so
/// there is nothing else on this screen — anything more would be competing with
/// it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.65, curve: Curves.easeOutBack),
  );

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _scheduleHandoff();
  }

  Future<void> _scheduleHandoff() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final AppServices services = ServiceScope.read(context);
    final bool showIntro = !services.player.introSeen;

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: AppDurations.slow,
        pageBuilder: (_, _, _) =>
            showIntro ? const IntroScreen() : const HomeScreen(),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GameBackground(
        scene: ArtScene.home,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      // Capped so the lockup does not balloon on a tablet or
                      // in the desktop preview frame.
                      child: KingdomLogoArt(
                        width: math.min(constraints.maxWidth, 340),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

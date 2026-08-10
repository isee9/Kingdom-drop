import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/kingdom_logo.dart';
import '../home/home_screen.dart';
import '../onboarding/intro_screen.dart';

/// Launch screen.
///
/// Deliberately brief: the mark animates in, holds for a beat, and hands off.
/// Services are already loaded by the time this builds, so the delay here is
/// purely for the brand moment, not for work.
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

  late final Animation<double> _textFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 1, curve: Curves.easeOut),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF2A1F5E), AppColors.background],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ScaleTransition(
                scale: _logoScale,
                child: const KingdomLogo(size: 148),
              ),
              const SizedBox(height: AppSpacing.xl),
              FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: <Widget>[
                    Text(
                      AppConfig.appName.toUpperCase(),
                      style: AppTextStyles.logo,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppConfig.tagline,
                      style: AppTextStyles.body.copyWith(
                        letterSpacing: 2,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

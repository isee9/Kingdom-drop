import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../screens/splash/splash_screen.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';

/// Root widget.
///
/// Owns the service graph, keeps the save flushed across lifecycle changes, and
/// clamps text scaling to a range the game's fixed-height chrome can absorb.
class KingdomDropApp extends StatefulWidget {
  const KingdomDropApp({required this.services, super.key});

  final AppServices services;

  @override
  State<KingdomDropApp> createState() => _KingdomDropAppState();
}

class _KingdomDropAppState extends State<KingdomDropApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.services.applySettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Force any debounced save to disk before the OS can reclaim us.
        widget.services.storage.flush();
        widget.services.audio.stopMusic();
      case AppLifecycleState.resumed:
        if (widget.services.player.settings.musicEnabled) {
          widget.services.audio.startMusic();
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ServiceScope(
      services: widget.services,
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const SplashScreen(),
        builder: (BuildContext context, Widget? child) {
          final MediaQueryData media = MediaQuery.of(context);
          // Respect the system text size, but only so far: past ~1.3 the score
          // readout and button labels start clipping their fixed-height rows.
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.3,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

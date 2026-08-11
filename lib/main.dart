import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/kingdom_drop_app.dart';
import 'core/utils/stage_log.dart';
import 'services/service_locator.dart';
import 'theme/app_art.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  final StageLog log = StageLog('boot');
  log.stage('main.begin');

  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: the board, tray and one-handed reach are all designed around
  // a tall screen, and a landscape layout would be a different product.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);

  // Decode the block faces and warm the backdrops before the first frame, so
  // the board never paints a frame of untextured blocks and the splash does not
  // flash its gradient before the castle appears.
  await ArtCache.preload();
  log.stage('art.ready');

  final AppServices services = await bootstrapServices();

  // The launch gate opens here, and everything above it is local work with a
  // known end: reading a save file and decoding images. Nothing that talks to
  // a network or shows a platform dialog is allowed above this line.
  log.stage('runApp — launch gate released');
  runApp(KingdomDropApp(services: services));

  // Consent and the ad SDK come up afterwards, deliberately unawaited.
  //
  // This ordering is the fix for a real hang: UMP would report the consent form
  // loaded and then never report it dismissed, and because startup awaited that
  // callback the app sat on its launch screen indefinitely. Now the game is
  // already on screen and interactive; if consent never resolves the only
  // consequence is no ads.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    log.stage('firstFrame — UI is live');
    unawaited(services.startMonetisation());
  });
}

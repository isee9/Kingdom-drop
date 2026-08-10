import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/kingdom_drop_app.dart';
import 'services/service_locator.dart';
import 'theme/app_art.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
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

  final AppServices services = await bootstrapServices();

  runApp(KingdomDropApp(services: services));
}

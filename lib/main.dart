import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/kingdom_drop_app.dart';
import 'services/service_locator.dart';
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

  final AppServices services = await bootstrapServices();

  runApp(KingdomDropApp(services: services));
}

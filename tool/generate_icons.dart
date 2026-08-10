// Generates the Android and iOS app icons from the in-code Kingdom Drop mark.
//
// The icon is not a hand-drawn asset — it is [KingdomLogoPainter] rendered to a
// PNG at every size each platform asks for. That means the icon can never drift
// from the logo used in the app, and re-skinning is a code change plus one
// command:
//
//     flutter run -d <device> -t tool/generate_icons.dart
//
// It needs a running Flutter engine to rasterise, so it is a tiny app rather
// than a plain Dart script. Run it once on any device or on desktop; it writes
// straight into the android/ and ios/ resource folders and then reports what it
// wrote. Nothing else in the project depends on it at build time.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kingdom_drop/widgets/kingdom_logo.dart';

/// Android mipmap buckets.
const Map<String, int> _androidSizes = <String, int>{
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// iOS AppIcon.appiconset entries: filename to pixel size.
const Map<String, int> _iosSizes = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _IconGeneratorApp());
}

class _IconGeneratorApp extends StatefulWidget {
  const _IconGeneratorApp();

  @override
  State<_IconGeneratorApp> createState() => _IconGeneratorAppState();
}

class _IconGeneratorAppState extends State<_IconGeneratorApp> {
  final List<String> _log = <String>[];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  Future<void> _generate() async {
    // Run from the project root so the relative paths below resolve.
    final Directory root = Directory.current;
    _say('Working directory: ${root.path}');

    for (final MapEntry<String, int> entry in _androidSizes.entries) {
      final String path =
          '${root.path}/android/app/src/main/res/${entry.key}/ic_launcher.png';
      await _writeIcon(path, entry.value);
    }

    // Adaptive icon foreground: the mark alone on transparency, drawn smaller
    // so Android's mask cannot clip the crown.
    for (final MapEntry<String, int> entry in _androidSizes.entries) {
      final String path =
          '${root.path}/android/app/src/main/res/${entry.key}/ic_launcher_foreground.png';
      await _writeIcon(path, (entry.value * 2.2).round(), foregroundOnly: true);
    }

    for (final MapEntry<String, int> entry in _iosSizes.entries) {
      final String path =
          '${root.path}/ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}';
      await _writeIcon(path, entry.value);
    }

    // iOS launch image: the mark on transparency, centred by the storyboard
    // over the dark background colour.
    const Map<String, int> launchSizes = <String, int>{
      'LaunchImage.png': 192,
      'LaunchImage@2x.png': 384,
      'LaunchImage@3x.png': 576,
    };
    for (final MapEntry<String, int> entry in launchSizes.entries) {
      await _writeIcon(
        '${root.path}/ios/Runner/Assets.xcassets/LaunchImage.imageset/'
        '${entry.key}',
        entry.value,
        foregroundOnly: true,
      );
    }

    // A large master for store listings.
    await _writeIcon('${root.path}/assets/images/app_icon_1024.png', 1024);

    _say('Done.');
    setState(() => _done = true);
  }

  Future<void> _writeIcon(
    String path,
    int size, {
    bool foregroundOnly = false,
  }) async {
    try {
      final ui.Image image = await _render(size, foregroundOnly: foregroundOnly);
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      if (data == null) {
        _say('FAILED (encode): $path');
        return;
      }

      final File file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      _say('wrote ${size}px  $path');
    } catch (error) {
      _say('FAILED: $path — $error');
    }
  }

  /// Rasterises the logo painter at [size] x [size].
  Future<ui.Image> _render(int size, {required bool foregroundOnly}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    KingdomLogoPainter(
      withBackground: !foregroundOnly,
      // Android crops an adaptive foreground to a centred safe zone of roughly
      // two thirds, so the mark has to sit well inside the canvas.
      marginFraction: foregroundOnly ? 0.26 : null,
    ).paint(canvas, Size(size.toDouble(), size.toDouble()));

    return recorder.endRecording().toImage(size, size);
  }

  void _say(String message) {
    debugPrint('[icons] $message');
    setState(() => _log.add(message));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF15122B),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16),
                child: KingdomLogo(size: 96),
              ),
              Text(
                _done ? 'Icons generated' : 'Generating…',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _log.length,
                  itemBuilder: (BuildContext context, int i) => Text(
                    _log[i],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/audio/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioService', () {
    test('every sound cue maps to an asset path', () {
      for (final Sfx sfx in Sfx.values) {
        final String? asset = AudioService.assetFor(sfx);
        expect(asset, isNotNull, reason: sfx.name);
        expect(asset, startsWith('audio/'), reason: sfx.name);
      }
    });

    test('cue paths are unique, so no two effects share a file by mistake', () {
      final Set<String?> paths = Sfx.values.map(AudioService.assetFor).toSet();
      expect(paths.length, Sfx.values.length);
    });

    test('runs silent when the bundle has no playable audio', () async {
      // The project ships with the audio slots empty apart from a README, so
      // init must decide there is nothing to play and never create a platform
      // player. A documentation file in assets/audio/ must not count.
      final AudioService audio = AudioService();
      await audio.init();

      expect(audio.isSilent, isTrue);
    });

    test('playing while silent is a harmless no-op', () async {
      final AudioService audio = AudioService();
      await audio.init();

      expect(() {
        for (final Sfx sfx in Sfx.values) {
          audio.play(sfx);
        }
        audio
          ..playTap()
          ..playClear(1)
          ..playClear(3);
      }, returnsNormally);
    });

    test('toggles are respected without touching the platform', () async {
      final AudioService audio = AudioService();
      await audio.init();

      await audio.setSoundEnabled(false);
      expect(audio.soundEnabled, isFalse);

      await audio.setMusicEnabled(false);
      expect(audio.musicEnabled, isFalse);

      await audio.setSoundEnabled(true);
      expect(audio.soundEnabled, isTrue);
    });

    test('music start and stop are safe with nothing bundled', () async {
      final AudioService audio = AudioService();
      await audio.init();

      await expectLater(audio.startMusic(), completes);
      await expectLater(audio.stopMusic(), completes);
      await expectLater(audio.dispose(), completes);
    });

    test('init is idempotent', () async {
      final AudioService audio = AudioService();
      await audio.init();
      await expectLater(audio.init(), completes);
      expect(audio.isSilent, isTrue);
    });
  });
}

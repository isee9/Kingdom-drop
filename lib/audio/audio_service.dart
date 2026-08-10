import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Every sound the game can ask for.
///
/// The enum is the contract; [AudioService.assetFor] maps it to a file. The
/// project ships with the slots empty (see `assets/audio/README.md`), and a
/// missing file is a silent no-op rather than a crash — so gameplay, tests and
/// CI all run with no audio present.
enum Sfx {
  blockPickup,
  blockPlaced,
  blockInvalid,
  lineCleared,
  comboCleared,
  coinGained,
  crownGained,
  levelUp,
  kingdomUpgrade,
  chestOpened,
  gameOver,
  buttonTap,
}

/// Sound and music playback.
///
/// Loading is lazy and failures are cached, so a missing asset costs one failed
/// lookup rather than an attempt on every clear.
class AudioService {
  AudioService({bool soundEnabled = true, bool musicEnabled = true})
    : _soundEnabled = soundEnabled,
      _musicEnabled = musicEnabled;

  /// Filenames under `assets/audio/`. Drop matching files in and they start
  /// working with no code change.
  static const Map<Sfx, String> _assets = <Sfx, String>{
    Sfx.blockPickup: 'audio/block_pickup.mp3',
    Sfx.blockPlaced: 'audio/block_placed.mp3',
    Sfx.blockInvalid: 'audio/block_invalid.mp3',
    Sfx.lineCleared: 'audio/line_cleared.mp3',
    Sfx.comboCleared: 'audio/combo.mp3',
    Sfx.coinGained: 'audio/coin.mp3',
    Sfx.crownGained: 'audio/crown.mp3',
    Sfx.levelUp: 'audio/level_up.mp3',
    Sfx.kingdomUpgrade: 'audio/kingdom_upgrade.mp3',
    Sfx.chestOpened: 'audio/chest.mp3',
    Sfx.gameOver: 'audio/game_over.mp3',
    Sfx.buttonTap: 'audio/button_tap.mp3',
  };

  static const String _musicAsset = 'audio/theme_loop.mp3';

  static String? assetFor(Sfx sfx) => _assets[sfx];

  bool _soundEnabled;
  bool _musicEnabled;
  bool _initialised = false;

  /// Sounds whose asset is absent. Checked before every play so a missing file
  /// is only ever probed once.
  final Set<Sfx> _unavailable = <Sfx>{};
  bool _musicUnavailable = false;

  /// A small pool of players so overlapping effects do not cut each other off.
  final List<AudioPlayer> _sfxPool = <AudioPlayer>[];
  int _poolCursor = 0;
  static const int _poolSize = 4;

  AudioPlayer? _musicPlayer;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  /// True when no audio assets are bundled, so the platform audio plugin is
  /// never touched at all.
  bool _silent = false;

  bool get isSilent => _silent;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // The project ships with the audio slots empty. Creating platform players
    // for a game that has nothing to play is pure cost, and on some platforms
    // the native side aborts the process when its audio backend is missing —
    // which a Dart try/catch cannot rescue. So check for assets first and stay
    // completely out of the plugin's way when there are none.
    _silent = !await _hasBundledAudio();
    if (_silent) {
      debugPrint('[audio] no audio assets bundled — running silent');
      return;
    }

    try {
      for (int i = 0; i < _poolSize; i++) {
        final AudioPlayer player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        _sfxPool.add(player);
      }
    } catch (error) {
      // Audio is optional. If the platform side is unavailable the game
      // continues in silence rather than failing to start.
      debugPrint('[audio] init failed, running silent: $error');
      _silent = true;
      _sfxPool.clear();
    }
  }

  /// Playable file extensions. The check below matches on these rather than on
  /// the folder alone — `assets/audio/` also contains a README describing the
  /// slots, and a documentation file must not convince the game it has sound.
  static const List<String> _audioExtensions = <String>[
    '.mp3',
    '.ogg',
    '.wav',
    '.m4a',
    '.aac',
    '.flac',
  ];

  /// True when the bundle actually contains a playable audio file.
  Future<bool> _hasBundledAudio() async {
    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );
      return manifest.listAssets().any((String key) {
        if (!key.startsWith('assets/audio/')) return false;
        final String lower = key.toLowerCase();
        return _audioExtensions.any(lower.endsWith);
      });
    } catch (error) {
      debugPrint('[audio] could not read the asset manifest: $error');
      return false;
    }
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    if (!value) await _stopAllSfx();
  }

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    if (value) {
      await startMusic();
    } else {
      await stopMusic();
    }
  }

  /// Fires a one-shot effect. Never awaited by gameplay code.
  void play(Sfx sfx) {
    if (_silent || !_soundEnabled || _unavailable.contains(sfx)) return;
    final String? asset = _assets[sfx];
    if (asset == null || _sfxPool.isEmpty) return;

    final AudioPlayer player = _sfxPool[_poolCursor];
    _poolCursor = (_poolCursor + 1) % _sfxPool.length;

    unawaited(
      player.play(AssetSource(asset)).catchError((Object error) {
        _unavailable.add(sfx);
        debugPrint('[audio] "$asset" unavailable, muting this cue');
      }),
    );
  }

  /// The button press cue, used by every tappable control.
  void playTap() => play(Sfx.buttonTap);

  /// Convenience for a clear: picks the plain or combo cue by group count.
  void playClear(int groupCount) =>
      play(groupCount > 1 ? Sfx.comboCleared : Sfx.lineCleared);

  Future<void> startMusic() async {
    if (_silent || !_musicEnabled || _musicUnavailable) return;
    try {
      _musicPlayer ??= AudioPlayer();
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer!.setVolume(0.35);
      await _musicPlayer!.play(AssetSource(_musicAsset));
    } catch (error) {
      _musicUnavailable = true;
      debugPrint('[audio] music track unavailable, continuing without it');
    }
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer?.stop();
    } catch (_) {
      // Nothing to do; music is best-effort.
    }
  }

  Future<void> _stopAllSfx() async {
    for (final AudioPlayer player in _sfxPool) {
      try {
        await player.stop();
      } catch (_) {
        // Ignore: stopping an idle player is harmless.
      }
    }
  }

  Future<void> dispose() async {
    for (final AudioPlayer player in _sfxPool) {
      try {
        await player.dispose();
      } catch (_) {
        // Ignore.
      }
    }
    _sfxPool.clear();
    try {
      await _musicPlayer?.dispose();
    } catch (_) {
      // Ignore.
    }
    _musicPlayer = null;
  }
}

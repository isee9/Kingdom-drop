import 'dart:math';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../../audio/audio_service.dart';
import '../../core/config/economy_config.dart';
import '../../economy/player_service.dart';
import '../../models/booster.dart';
import '../../progression/daily_service.dart';
import '../../services/analytics_service.dart';
import '../../services/haptic_service.dart';
import '../engine/board.dart';
import '../engine/game_engine.dart';
import '../engine/scoring.dart';
import '../engine/shape.dart';
import '../engine/shape_generator.dart';

/// What the game screen should be showing.
enum GamePhase {
  playing,

  /// "No more moves" panel is up; the run can still be rescued.
  outOfMoves,

  /// The run is over and the summary is showing.
  summary,
}

/// A transient visual effect the renderer plays and then discards.
///
/// The controller records *what* happened; the widgets decide how it looks.
class ClearEffect {
  ClearEffect({
    required this.cells,
    required this.groupCount,
    required this.colors,
  }) : startedAt = DateTime.now();

  final Set<Cell> cells;
  final int groupCount;

  /// Colour each cleared cell had, so the burst matches what was there.
  final Map<Cell, int> colors;
  final DateTime startedAt;
}

/// A score number that floats up from the board.
class FloatingScore {
  FloatingScore({
    required this.text,
    required this.anchor,
    required this.emphasis,
  }) : id = _nextId++;

  static int _nextId = 0;

  final int id;
  final String text;

  /// Board-space anchor in cell coordinates (may be fractional).
  final Offset anchor;

  /// 0 for a plain placement, higher for combos — drives size and colour.
  final int emphasis;
}

/// Drives one run of the game for the UI.
///
/// Holds the drag state, the effect queue and the phase, and forwards rules
/// decisions to [GameEngine]. Keeping the engine ignorant of Flutter means the
/// rules stay unit-testable while this class stays thin enough to reason about.
class GameController extends ChangeNotifier {
  GameController({
    required PlayerService player,
    required AudioService audio,
    required HapticService haptics,
    required AnalyticsService analytics,
    required DailyService daily,
    Random? random,
  }) : _player = player,
       _audio = audio,
       _haptics = haptics,
       _analytics = analytics,
       _daily = daily,
       engine = GameEngine(random: random) {
    _analytics.log(AnalyticsEvents.gameStarted);
  }

  final PlayerService _player;
  final AudioService _audio;
  final HapticService _haptics;
  final AnalyticsService _analytics;
  final DailyService _daily;

  final GameEngine engine;

  // ------------------------------------------------------------------ phase
  GamePhase _phase = GamePhase.playing;
  GamePhase get phase => _phase;

  Board get board => engine.board;
  List<TrayPiece> get tray => engine.tray;
  int get score => engine.score;
  int get bestScore => max(_player.bestScore, engine.score);
  bool get comboActive => engine.comboActive;
  double get comboMultiplier => engine.comboMultiplier;
  int get comboDepth => engine.comboDepth;
  GameStats get stats => engine.stats;
  bool get canContinue => engine.canContinue;

  /// True once the score passes the previous best, so the HUD can celebrate.
  bool get isNewBest =>
      _player.bestScore > 0 && engine.score > _player.bestScore;

  // ------------------------------------------------------------- drag state
  int? _draggingPieceId;
  Offset? _dragPointer;
  Cell? _hoverOrigin;
  bool _hoverValid = false;
  List<ClearGroup> _hoverClears = const <ClearGroup>[];

  int? get draggingPieceId => _draggingPieceId;
  Offset? get dragPointer => _dragPointer;

  /// Board origin the dragged piece would land on, or null when off-board.
  Cell? get hoverOrigin => _hoverOrigin;
  bool get hoverValid => _hoverValid;

  /// Groups that would clear if the player let go now.
  List<ClearGroup> get hoverClears => _hoverClears;

  TrayPiece? get draggingPiece =>
      _draggingPieceId == null ? null : engine.pieceById(_draggingPieceId!);

  /// Cells the dragged piece would occupy, for the ghost preview.
  Set<Cell> get hoverCells {
    final TrayPiece? piece = draggingPiece;
    final Cell? origin = _hoverOrigin;
    if (piece == null || origin == null) return const <Cell>{};
    return <Cell>{
      for (final Cell c in piece.shape.cells)
        Cell(origin.row + c.row, origin.col + c.col),
    };
  }

  /// Cells that will be wiped by the pending clear, for the highlight.
  Set<Cell> get hoverClearCells {
    if (_hoverClears.isEmpty) return const <Cell>{};
    return <Cell>{for (final ClearGroup g in _hoverClears) ...g.cells};
  }

  // --------------------------------------------------------------- effects
  final List<ClearEffect> _clearEffects = <ClearEffect>[];
  final List<FloatingScore> _floatingScores = <FloatingScore>[];

  List<ClearEffect> get clearEffects => List<ClearEffect>.unmodifiable(
    _clearEffects,
  );
  List<FloatingScore> get floatingScores => List<FloatingScore>.unmodifiable(
    _floatingScores,
  );

  /// Cells that just landed, so they can pop in.
  Set<Cell> _justPlaced = <Cell>{};
  Set<Cell> get justPlaced => _justPlaced;

  /// Bumped whenever the board should shake. The renderer watches for changes.
  int _shakeToken = 0;
  double _shakeStrength = 0;
  int get shakeToken => _shakeToken;
  double get shakeStrength => _shakeStrength;

  void consumeClearEffect(ClearEffect effect) {
    _clearEffects.remove(effect);
  }

  void consumeFloatingScore(int id) {
    _floatingScores.removeWhere((FloatingScore s) => s.id == id);
  }

  // ------------------------------------------------------------- boosters
  BoosterType? _armedBooster;

  /// The booster waiting for the player to tap a cell, if any.
  BoosterType? get armedBooster => _armedBooster;

  int boosterCount(BoosterType type) => _player.boosterCount(type);

  /// Arms or disarms a targeted booster. Untargeted ones fire immediately.
  void toggleBooster(BoosterType type) {
    if (_phase != GamePhase.playing && type != BoosterType.secondChance) {
      return;
    }
    if (_player.boosterCount(type) <= 0) return;

    _haptics.tap();
    _audio.play(Sfx.buttonTap);

    if (!type.requiresCellTarget) {
      _fireUntargetedBooster(type);
      return;
    }

    _armedBooster = _armedBooster == type ? null : type;
    _cancelDrag(notify: false);
    notifyListeners();
  }

  void disarmBooster() {
    if (_armedBooster == null) return;
    _armedBooster = null;
    notifyListeners();
  }

  void _fireUntargetedBooster(BoosterType type) {
    switch (type) {
      case BoosterType.shuffle:
        if (!_player.consumeBooster(type)) return;
        engine.useShuffle();
        _analytics.log(AnalyticsEvents.boosterUsed, <String, Object?>{
          'booster': type.name,
        });
        _syncPhaseWithEngine();
        notifyListeners();
      case BoosterType.secondChance:
        if (!_player.consumeBooster(type)) return;
        final BoosterResult result = engine.useSecondChance();
        if (result.applied) {
          _registerClearEffect(result.affectedCells, 1);
          _analytics.log(AnalyticsEvents.boosterUsed, <String, Object?>{
            'booster': type.name,
          });
        }
        _syncPhaseWithEngine();
        notifyListeners();
      case BoosterType.hammer:
      case BoosterType.bomb:
        break; // Targeted; handled by applyBoosterAt.
    }
  }

  /// Fires an armed hammer or bomb at a board cell.
  void applyBoosterAt(int row, int col) {
    final BoosterType? type = _armedBooster;
    if (type == null) return;

    final BoosterResult result = switch (type) {
      BoosterType.hammer => engine.useHammer(row, col),
      BoosterType.bomb => engine.useBomb(row, col),
      _ => BoosterResult.rejected,
    };

    if (!result.applied) {
      _haptics.invalid();
      _audio.play(Sfx.blockInvalid);
      return;
    }

    // Only charged once the booster actually did something.
    if (!_player.consumeBooster(type)) return;
    _armedBooster = null;

    _analytics.log(AnalyticsEvents.boosterUsed, <String, Object?>{
      'booster': type.name,
    });

    _registerClearEffect(
      <Cell>{...result.affectedCells, ...result.clearedCells},
      max(1, result.clears.length),
    );
    _haptics.clear(max(1, result.clears.length));
    _audio.playClear(max(1, result.clears.length));
    if (result.clears.isNotEmpty) _shake(result.clears.length);

    _syncPhaseWithEngine();
    notifyListeners();
  }

  /// Buys a booster with coins from the in-game bar.
  bool buyBooster(BoosterType type) {
    final bool ok = _player.buyBooster(type);
    if (ok) {
      _audio.play(Sfx.coinGained);
      _haptics.reward();
      notifyListeners();
    }
    return ok;
  }

  // ------------------------------------------------------------------ drag
  /// Starts dragging a tray piece. [pointer] is in board-local coordinates.
  void startDrag(int pieceId, Offset pointer) {
    if (_phase != GamePhase.playing) return;
    final TrayPiece? piece = engine.pieceById(pieceId);
    if (piece == null || piece.used) return;

    _armedBooster = null;
    _draggingPieceId = pieceId;
    _dragPointer = pointer;
    _updateHover();
    _haptics.pickup();
    _audio.play(Sfx.blockPickup);
    notifyListeners();
  }

  /// Updates the drag position. [origin] is the cell the piece's bounding box
  /// top-left currently sits over, computed by the view from its own geometry.
  void updateDrag(Offset pointer, Cell? origin) {
    if (_draggingPieceId == null) return;
    _dragPointer = pointer;

    final bool originChanged = origin != _hoverOrigin;
    _hoverOrigin = origin;
    if (originChanged) {
      _updateHover();
      // A light tick each time the target cell changes makes the snap legible
      // without the finger covering it.
      if (_hoverValid) _haptics.pickup();
    }
    notifyListeners();
  }

  void _updateHover() {
    final int? pieceId = _draggingPieceId;
    final Cell? origin = _hoverOrigin;
    if (pieceId == null || origin == null) {
      _hoverValid = false;
      _hoverClears = const <ClearGroup>[];
      return;
    }
    _hoverValid = engine.canPlace(pieceId, origin.row, origin.col);
    _hoverClears = _hoverValid
        ? engine.previewClears(pieceId, origin.row, origin.col)
        : const <ClearGroup>[];
  }

  /// Ends the drag. Places the piece if the drop is legal, otherwise returns it
  /// to the tray. Returns true when a placement happened.
  bool endDrag() {
    final int? pieceId = _draggingPieceId;
    final Cell? origin = _hoverOrigin;

    if (pieceId == null) return false;

    if (origin == null || !_hoverValid) {
      _haptics.invalid();
      _audio.play(Sfx.blockInvalid);
      _cancelDrag();
      return false;
    }

    final PlacementResult result = engine.place(pieceId, origin.row, origin.col);
    _cancelDrag(notify: false);

    if (!result.accepted) {
      _haptics.invalid();
      _audio.play(Sfx.blockInvalid);
      notifyListeners();
      return false;
    }

    _onPlacement(result);
    return true;
  }

  void cancelDrag() => _cancelDrag();

  void _cancelDrag({bool notify = true}) {
    _draggingPieceId = null;
    _dragPointer = null;
    _hoverOrigin = null;
    _hoverValid = false;
    _hoverClears = const <ClearGroup>[];
    if (notify) notifyListeners();
  }

  // ------------------------------------------------------------- placement
  void _onPlacement(PlacementResult result) {
    _justPlaced = result.placedCells.toSet();

    if (result.didClear) {
      _registerClearEffect(result.clearedCells, result.clears.length);
      _haptics.clear(result.clears.length);
      _audio.playClear(result.clears.length);
      if (result.clears.length >= 2) _shake(result.clears.length);
    } else {
      _haptics.place();
      _audio.play(Sfx.blockPlaced);
    }

    _addFloatingScore(result);
    _syncPhaseWithEngine();
    notifyListeners();
  }

  void _addFloatingScore(PlacementResult result) {
    final ScoreBreakdown score = result.score;
    if (score.total <= 0) return;

    // Anchor the number at the centre of what just happened.
    final List<Cell> anchorCells = result.didClear
        ? result.clearedCells.toList()
        : result.placedCells;
    if (anchorCells.isEmpty) return;

    double row = 0;
    double col = 0;
    for (final Cell cell in anchorCells) {
      row += cell.row;
      col += cell.col;
    }
    row /= anchorCells.length;
    col /= anchorCells.length;

    _floatingScores.add(
      FloatingScore(
        text: '+${score.total}',
        anchor: Offset(col, row),
        emphasis: result.clears.length,
      ),
    );

    if (score.comboMultiplier > 1) {
      _floatingScores.add(
        FloatingScore(
          text: 'COMBO x${_trimMultiplier(score.comboMultiplier)}',
          anchor: Offset(col, row - 0.9),
          emphasis: score.comboDepth + 1,
        ),
      );
    }
  }

  static String _trimMultiplier(double value) {
    final String text = value.toStringAsFixed(2);
    if (text.endsWith('00')) return text.substring(0, text.length - 3);
    if (text.endsWith('0')) return text.substring(0, text.length - 1);
    return text;
  }

  void _registerClearEffect(Set<Cell> cells, int groupCount) {
    if (cells.isEmpty) return;
    // Snapshot the colours before the board forgets them. The engine has
    // already emptied these cells, so fall back to the palette by position.
    final Map<Cell, int> colors = <Cell, int>{
      for (final Cell cell in cells)
        cell: (cell.row + cell.col) % 6,
    };
    _clearEffects.add(
      ClearEffect(cells: cells, groupCount: groupCount, colors: colors),
    );
  }

  void _shake(int intensity) {
    _shakeToken++;
    _shakeStrength = (intensity.clamp(1, 5)) / 5;
  }

  void _syncPhaseWithEngine() {
    if (engine.state == GameState.noMoves && _phase == GamePhase.playing) {
      _phase = GamePhase.outOfMoves;
      _haptics.gameOver();
      _audio.play(Sfx.gameOver);
      _analytics.log('out_of_moves', <String, Object?>{'score': engine.score});
    } else if (engine.state == GameState.playing &&
        _phase == GamePhase.outOfMoves) {
      _phase = GamePhase.playing;
    }
  }

  // ------------------------------------------------------------- continues
  /// Pays coins to keep playing. False when the player cannot afford it or has
  /// used all their continues.
  bool continueWithCoins() {
    if (!engine.canContinue) return false;
    if (!_player.spendCoins(EconomyConfig.continueCostCoins)) return false;
    return _applyContinue('coins');
  }

  /// Keeps playing after a completed rewarded ad. The caller is responsible for
  /// having actually shown the ad.
  bool continueWithAd() {
    if (!engine.canContinue) return false;
    return _applyContinue('rewarded_ad');
  }

  bool _applyContinue(String source) {
    final bool resumed = engine.consumeContinue();
    if (!resumed) return false;

    _phase = GamePhase.playing;
    _analytics.log(AnalyticsEvents.continueUsed, <String, Object?>{
      'source': source,
      'score': engine.score,
      'used': engine.stats.continuesUsed,
    });
    _haptics.reward();
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------ end of run
  bool _resultsRecorded = false;

  /// Closes the run and books the stats. Rewards are handed out separately by
  /// the summary screen so the player can choose to double them first.
  void finishGame() {
    if (_phase == GamePhase.summary) return;

    engine.endGame();
    _phase = GamePhase.summary;

    if (!_resultsRecorded) {
      _resultsRecorded = true;
      _player.recordGameFinished(
        score: engine.stats.score,
        linesCleared: engine.stats.linesCleared,
        piecesPlaced: engine.stats.piecesPlaced,
        bestComboDepth: engine.stats.bestComboDepth,
      );
      _daily.applyRunToChallenge(engine.stats);
      _analytics.log(AnalyticsEvents.gameEnded, engine.stats.toAnalyticsMap());
    }

    notifyListeners();
  }

  /// Starts a fresh run in place.
  void restart() {
    engine.restart();
    _phase = GamePhase.playing;
    _resultsRecorded = false;
    _clearEffects.clear();
    _floatingScores.clear();
    _justPlaced = <Cell>{};
    _cancelDrag(notify: false);
    _armedBooster = null;
    _analytics.log(AnalyticsEvents.gameStarted);
    notifyListeners();
  }

  // --------------------------------------------------------------- tutorial
  /// Seeds a guided opening board for the first-run tutorial.
  ///
  /// The bottom row is left one piece short and the tray is stacked so the
  /// player's very first drag produces a line clear. Teaching the payoff on
  /// move one is worth far more than a page of text, and it only ever happens
  /// on the tutorial run.
  void prepareTutorial() {
    engine.board.clearAll();
    for (int c = 0; c <= 4; c++) {
      engine.board.setCell(6, c, c % 6);
    }
    engine.debugSetTray(
      <Shape>[
        ShapeCatalog.byId('h2'),
        ShapeCatalog.byId('v2'),
        ShapeCatalog.byId('dot'),
      ],
      colors: <int>[2, 0, 4],
    );
    notifyListeners();
  }

  // ------------------------------------------------------------------ debug
  void debugForceGameOver() {
    engine.debugForceGameOver();
    _syncPhaseWithEngine();
    notifyListeners();
  }

  void debugSetScore(int score) {
    engine.debugSetScore(score);
    notifyListeners();
  }

  /// Fills the board with an attractive pattern for store screenshots.
  void debugFillForScreenshot() {
    final Random rng = Random(7);
    engine.board.clearAll();
    for (int r = 0; r < engine.board.size; r++) {
      for (int c = 0; c < engine.board.size; c++) {
        // Leave the top-right open so the layout reads as an active game.
        if (r < 2 && c > 4) continue;
        if (rng.nextDouble() < 0.62) {
          engine.board.setCell(r, c, rng.nextInt(6));
        }
      }
    }
    notifyListeners();
  }
}

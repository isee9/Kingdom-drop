import 'dart:math';

import '../../core/config/economy_config.dart';
import 'board.dart';
import 'scoring.dart';
import 'shape.dart';
import 'shape_generator.dart';

/// Lifecycle of a single run.
enum GameState {
  /// Accepting placements.
  playing,

  /// No remaining piece fits. The run is paused pending continue or end.
  noMoves,

  /// Finished. Rewards have been handed to the meta layer.
  ended,
}

/// Everything a run accumulates, used for the summary, achievements and the
/// daily challenge.
class GameStats {
  GameStats();

  int score = 0;
  int piecesPlaced = 0;
  int linesCleared = 0;

  /// Placements that cleared at least two groups at once.
  int combosTriggered = 0;

  /// Deepest combo ladder position reached.
  int bestComboDepth = 0;

  /// Largest number of groups cleared by one placement.
  int maxSimultaneousClears = 0;

  /// Combos at ladder depth 3+, which pay bonus crowns.
  int bigCombos = 0;

  int continuesUsed = 0;
  int boostersUsed = 0;

  /// Wall-clock duration, filled in when the run ends.
  Duration duration = Duration.zero;

  Map<String, int> toAnalyticsMap() => <String, int>{
    'score': score,
    'pieces_placed': piecesPlaced,
    'lines_cleared': linesCleared,
    'combos': combosTriggered,
    'best_combo_depth': bestComboDepth,
    'max_simultaneous': maxSimultaneousClears,
    'continues_used': continuesUsed,
    'boosters_used': boostersUsed,
    'duration_seconds': duration.inSeconds,
  };
}

/// The outcome of one attempted placement. The UI reads this to decide what to
/// animate; it never has to re-derive anything from the board.
class PlacementResult {
  const PlacementResult({
    required this.accepted,
    this.placedCells = const <Cell>[],
    this.clears = const <ClearGroup>[],
    this.clearedCells = const <Cell>{},
    this.score = ScoreBreakdown.zero,
    this.trayRefilled = false,
    this.outOfMoves = false,
  });

  static const PlacementResult rejected = PlacementResult(accepted: false);

  final bool accepted;
  final List<Cell> placedCells;
  final List<ClearGroup> clears;
  final Set<Cell> clearedCells;
  final ScoreBreakdown score;

  /// True when this placement emptied the tray and three new pieces appeared.
  final bool trayRefilled;

  /// True when nothing in the tray fits any more.
  final bool outOfMoves;

  bool get didClear => clears.isNotEmpty;
}

/// Result of firing a booster at the board.
class BoosterResult {
  const BoosterResult({
    required this.applied,
    this.affectedCells = const <Cell>{},
    this.clears = const <ClearGroup>[],
    this.clearedCells = const <Cell>{},
    this.outOfMoves = false,
  });

  static const BoosterResult rejected = BoosterResult(applied: false);

  final bool applied;

  /// Cells the booster itself removed.
  final Set<Cell> affectedCells;

  /// Groups completed as a side effect (a bomb can finish a region).
  final List<ClearGroup> clears;
  final Set<Cell> clearedCells;
  final bool outOfMoves;
}

/// Owns one run of Kingdom Drop.
///
/// Pure Dart on purpose: no Flutter import, no timers, no animation. The
/// controller layer above turns these results into motion, which keeps every
/// rule in here directly unit-testable.
class GameEngine {
  GameEngine({Random? random, int boardSize = Board.defaultSize})
    : board = Board(size: boardSize),
      _generator = ShapeGenerator(random: random ?? Random()) {
    _startRun();
  }

  final Board board;
  final ShapeGenerator _generator;
  final ScoreCalculator _scorer = ScoreCalculator();
  final GameStats stats = GameStats();

  List<TrayPiece> _tray = <TrayPiece>[];
  GameState _state = GameState.playing;
  DateTime _startedAt = DateTime.now();

  // ------------------------------------------------------------- read-only
  List<TrayPiece> get tray => List<TrayPiece>.unmodifiable(_tray);

  Iterable<TrayPiece> get availablePieces =>
      _tray.where((TrayPiece p) => !p.used);

  GameState get state => _state;

  int get score => stats.score;

  bool get isPlaying => _state == GameState.playing;

  bool get comboActive => _scorer.comboActive;

  double get comboMultiplier => _scorer.currentMultiplier;

  int get comboDepth => _scorer.comboIndex;

  bool get canContinue =>
      stats.continuesUsed < EconomyConfig.maxContinuesPerGame;

  int get continuesRemaining =>
      max(0, EconomyConfig.maxContinuesPerGame - stats.continuesUsed);

  // ------------------------------------------------------------- lifecycle
  void _startRun() {
    board.clearAll();
    _scorer.reset();
    _tray = _generator.generateSet(board);
    _state = GameState.playing;
    _startedAt = DateTime.now();
  }

  /// Wipes everything and deals a fresh tray.
  void restart() {
    stats
      ..score = 0
      ..piecesPlaced = 0
      ..linesCleared = 0
      ..combosTriggered = 0
      ..bestComboDepth = 0
      ..maxSimultaneousClears = 0
      ..bigCombos = 0
      ..continuesUsed = 0
      ..boostersUsed = 0
      ..duration = Duration.zero;
    _startRun();
  }

  /// Ends the run for good and stamps the duration.
  void endGame() {
    if (_state == GameState.ended) return;
    stats.duration = DateTime.now().difference(_startedAt);
    _state = GameState.ended;
  }

  // ------------------------------------------------------------- placement
  TrayPiece? pieceById(int id) {
    for (final TrayPiece piece in _tray) {
      if (piece.id == id) return piece;
    }
    return null;
  }

  /// True if [pieceId] can legally land with its bounding box at (row, col).
  bool canPlace(int pieceId, int row, int col) {
    if (_state != GameState.playing) return false;
    final TrayPiece? piece = pieceById(pieceId);
    if (piece == null || piece.used) return false;
    return board.canPlace(piece.shape, row, col);
  }

  /// Groups that *would* complete if [pieceId] landed at (row, col). Drives the
  /// pre-drop highlight so the player can see a clear coming.
  List<ClearGroup> previewClears(int pieceId, int row, int col) {
    if (!canPlace(pieceId, row, col)) return const <ClearGroup>[];
    final TrayPiece piece = pieceById(pieceId)!;
    final Board scratch = board.copy();
    scratch.place(piece.shape, row, col, piece.colorIndex);
    return scratch.findCompleteGroups();
  }

  /// Commits a placement, resolves clears, updates score and refills the tray.
  PlacementResult place(int pieceId, int row, int col) {
    if (!canPlace(pieceId, row, col)) return PlacementResult.rejected;

    final TrayPiece piece = pieceById(pieceId)!;
    final List<Cell> placed = board.place(
      piece.shape,
      row,
      col,
      piece.colorIndex,
    );
    piece.used = true;

    final List<ClearGroup> groups = board.findCompleteGroups();
    final Set<Cell> clearedCells = board.applyClears(groups);

    final ScoreBreakdown breakdown = _scorer.scorePlacement(
      blocksPlaced: piece.shape.blockCount,
      groups: groups,
    );

    stats.score += breakdown.total;
    stats.piecesPlaced++;
    stats.linesCleared += groups.length;
    if (groups.length > 1) stats.combosTriggered++;
    if (groups.length > stats.maxSimultaneousClears) {
      stats.maxSimultaneousClears = groups.length;
    }
    if (breakdown.comboDepth > stats.bestComboDepth) {
      stats.bestComboDepth = breakdown.comboDepth;
    }
    if (breakdown.comboDepth >= 3) stats.bigCombos++;

    bool refilled = false;
    if (_tray.every((TrayPiece p) => p.used)) {
      _tray = _generator.generateSet(board);
      refilled = true;
    }

    final bool stuck = !_hasAnyMove();
    if (stuck) _state = GameState.noMoves;

    return PlacementResult(
      accepted: true,
      placedCells: placed,
      clears: groups,
      clearedCells: clearedCells,
      score: breakdown,
      trayRefilled: refilled,
      outOfMoves: stuck,
    );
  }

  /// True while at least one unused tray piece still fits somewhere.
  bool _hasAnyMove() {
    for (final TrayPiece piece in availablePieces) {
      if (board.hasAnyPlacement(piece.shape)) return true;
    }
    return false;
  }

  /// Public form used by the controller and tests.
  bool get hasAvailableMove => _hasAnyMove();

  /// Every legal origin for a piece, for the drop preview and the tutorial's
  /// suggested placement.
  List<Cell> placementsFor(int pieceId) {
    final TrayPiece? piece = pieceById(pieceId);
    if (piece == null || piece.used) return const <Cell>[];
    return board.allPlacements(piece.shape);
  }

  // -------------------------------------------------------------- boosters
  /// Removes a single occupied cell.
  BoosterResult useHammer(int row, int col) {
    if (!board.isFilled(row, col)) return BoosterResult.rejected;
    board.clearCell(row, col);
    stats.boostersUsed++;
    return _resolveBoosterAftermath(<Cell>{Cell(row, col)});
  }

  /// Clears the 3x3 area centred on (row, col), stopping at the board edge.
  BoosterResult useBomb(int row, int col) {
    final Set<Cell> hit = <Cell>{};
    for (int r = row - 1; r <= row + 1; r++) {
      for (int c = col - 1; c <= col + 1; c++) {
        if (board.isFilled(r, c)) {
          board.clearCell(r, c);
          hit.add(Cell(r, c));
        }
      }
    }
    if (hit.isEmpty) return BoosterResult.rejected;
    stats.boostersUsed++;
    return _resolveBoosterAftermath(hit);
  }

  /// Swaps the unused tray pieces for a fresh draw.
  bool useShuffle() {
    if (availablePieces.isEmpty) return false;
    _tray = _generator.shuffleTray(board, _tray);
    stats.boostersUsed++;
    if (_state == GameState.noMoves && _hasAnyMove()) {
      _state = GameState.playing;
    } else if (_state == GameState.playing && !_hasAnyMove()) {
      _state = GameState.noMoves;
    }
    return true;
  }

  /// Frees space after a loss so the run can carry on.
  ///
  /// Clears the fullest rows first — that removes the most dead weight per row
  /// and tends to reopen the middle of the board — stopping as soon as a tray
  /// piece fits or the cell budget is spent. Nothing is scored for it.
  BoosterResult useSecondChance() {
    final Set<Cell> removed = <Cell>{};
    int budget = EconomyConfig.secondChanceCellsCleared;

    final List<int> rowsByFill = List<int>.generate(board.size, (int r) => r)
      ..sort((int a, int b) => _rowFill(b).compareTo(_rowFill(a)));

    for (final int row in rowsByFill) {
      if (budget <= 0 || _hasAnyMove()) break;
      for (int c = 0; c < board.size && budget > 0; c++) {
        if (board.isFilled(row, c)) {
          board.clearCell(row, c);
          removed.add(Cell(row, c));
          budget--;
        }
      }
    }

    if (removed.isEmpty) return BoosterResult.rejected;

    stats.boostersUsed++;
    if (_hasAnyMove()) _state = GameState.playing;
    return BoosterResult(
      applied: true,
      affectedCells: removed,
      outOfMoves: !_hasAnyMove(),
    );
  }

  int _rowFill(int row) {
    int n = 0;
    for (int c = 0; c < board.size; c++) {
      if (board.isFilled(row, c)) n++;
    }
    return n;
  }

  /// Boosters can complete a group; resolve and score it like a placement would
  /// so a bomb that finishes a region still feels rewarding.
  BoosterResult _resolveBoosterAftermath(Set<Cell> affected) {
    final List<ClearGroup> groups = board.findCompleteGroups();
    final Set<Cell> clearedCells = board.applyClears(groups);

    if (groups.isNotEmpty) {
      final ScoreBreakdown breakdown = _scorer.scorePlacement(
        blocksPlaced: 0,
        groups: groups,
      );
      stats.score += breakdown.total;
      stats.linesCleared += groups.length;
      if (groups.length > 1) stats.combosTriggered++;
    }

    if (_state == GameState.noMoves && _hasAnyMove()) {
      _state = GameState.playing;
    }

    return BoosterResult(
      applied: true,
      affectedCells: affected,
      clears: groups,
      clearedCells: clearedCells,
      outOfMoves: !_hasAnyMove(),
    );
  }

  // ------------------------------------------------------------- continues
  /// Spends a continue and reopens the board. The caller is responsible for
  /// having taken payment (coins or a completed rewarded ad).
  bool consumeContinue() {
    if (!canContinue) return false;
    stats.continuesUsed++;
    final BoosterResult result = useSecondChance();
    if (!result.applied) return false;
    stats.boostersUsed--; // A continue is not a booster use.
    _state = _hasAnyMove() ? GameState.playing : GameState.noMoves;
    return _state == GameState.playing;
  }

  // ----------------------------------------------------------- end rewards
  int get crownsEarned => RewardCalculator.crownsFor(
    score: stats.score,
    bigCombos: stats.bigCombos,
  );

  int get coinsEarned => RewardCalculator.coinsFor(score: stats.score);

  int get xpEarned => RewardCalculator.xpFor(score: stats.score);

  // ------------------------------------------------------- debug / testing
  /// Replaces the tray with specific shapes. Used by the tutorial, the debug
  /// menu and tests; never called from normal play.
  void debugSetTray(List<Shape> shapes, {List<int>? colors}) {
    _tray = <TrayPiece>[
      for (int i = 0; i < shapes.length; i++)
        TrayPiece(
          id: -(i + 1),
          shape: shapes[i],
          colorIndex: colors != null && i < colors.length ? colors[i] : i % 6,
        ),
    ];
    _state = _hasAnyMove() ? GameState.playing : GameState.noMoves;
  }

  /// Forces the loss state, for the debug menu.
  void debugForceGameOver() {
    for (final TrayPiece piece in _tray) {
      piece.used = true;
    }
    _tray = <TrayPiece>[
      TrayPiece(id: -99, shape: ShapeCatalog.byId('square3'), colorIndex: 0),
    ];
    for (int r = 0; r < board.size; r++) {
      for (int c = 0; c < board.size; c++) {
        if (r % 2 == 0) board.setCell(r, c, 4);
      }
    }
    _state = _hasAnyMove() ? GameState.playing : GameState.noMoves;
  }

  /// Injects a score, for the debug menu and screenshot mode.
  void debugSetScore(int value) => stats.score = value;
}

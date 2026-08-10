import 'dart:math';

import 'board.dart';
import 'shape.dart';

/// A shape instance sitting in the tray, with the colour it will keep once
/// placed. Two tray slots can hold the same [Shape] but are distinct pieces.
class TrayPiece {
  TrayPiece({
    required this.id,
    required this.shape,
    required this.colorIndex,
    this.used = false,
  });

  final int id;
  final Shape shape;
  final int colorIndex;

  /// Set once the piece has been dropped on the board. Used pieces stay in the
  /// tray as empty slots until all three are gone.
  bool used;

  TrayPiece copyWith({bool? used}) => TrayPiece(
    id: id,
    shape: shape,
    colorIndex: colorIndex,
    used: used ?? this.used,
  );
}

/// Produces the sets of three pieces the player draws from.
///
/// ## Fairness
///
/// The generator never hands out a set where nothing fits. It rolls a weighted
/// set, checks it against the live board, and if no piece can be placed it
/// re-rolls a bounded number of times before force-substituting a piece that
/// definitely fits (smallest first). That removes the "instant unfair loss"
/// case without steering the player toward wins.
///
/// It does *not* look ahead past the first piece. Once the player commits to a
/// placement the board can still close up, so the game keeps getting harder as
/// space runs out and ends honestly.
///
/// ## Difficulty
///
/// As the board fills past [_pressureThreshold], large shapes are progressively
/// down-weighted. This is a gentle assist that keeps a typical early session in
/// the 3–8 minute band rather than ending abruptly. It never removes large
/// pieces entirely, and it never forces a win.
class ShapeGenerator {
  ShapeGenerator({Random? random, int paletteSize = 6})
    : _random = random ?? Random(),
      _paletteSize = paletteSize;

  final Random _random;
  final int _paletteSize;

  int _nextPieceId = 0;

  /// Board occupancy above which large pieces start being down-weighted.
  static const double _pressureThreshold = 0.45;

  /// Block count at or above which a shape counts as "large".
  static const int _largeShapeBlocks = 5;

  /// Block count at which the size penalty is at full strength.
  static const int _hugeShapeBlocks = 9;

  /// Most weight a large shape can lose at maximum pressure.
  static const double _maxSizePenalty = 0.85;

  /// How many full sets to re-roll before force-substituting.
  static const int _maxSetRerolls = 12;

  /// Draws a fresh set of [count] pieces for [board].
  List<TrayPiece> generateSet(Board board, {int count = 3}) {
    final double pressure = _pressureFor(board);

    List<TrayPiece> best = <TrayPiece>[];
    for (int attempt = 0; attempt <= _maxSetRerolls; attempt++) {
      final List<TrayPiece> candidate = <TrayPiece>[
        for (int i = 0; i < count; i++) _rollPiece(pressure),
      ];
      if (_anyPlaceable(board, candidate)) return candidate;
      best = candidate;
    }

    // Nothing rolled fits. Swap one slot for the largest piece that does still
    // fit, so the rescue is as generous as the board honestly allows.
    final Shape? rescue = _largestFittingShape(board);
    if (rescue != null) {
      best[_random.nextInt(best.length)] = TrayPiece(
        id: _nextPieceId++,
        shape: rescue,
        colorIndex: _random.nextInt(_paletteSize),
      );
    }
    return best;
  }

  /// Replaces the unused pieces of an existing tray, for the shuffle booster.
  /// Pieces already placed stay used so the player cannot rewind a move.
  List<TrayPiece> shuffleTray(Board board, List<TrayPiece> current) {
    final int unusedCount = current.where((TrayPiece p) => !p.used).length;
    if (unusedCount == 0) return current;

    final List<TrayPiece> replacements = generateSet(board, count: unusedCount);
    int next = 0;
    return <TrayPiece>[
      for (final TrayPiece piece in current)
        if (piece.used) piece else replacements[next++],
    ];
  }

  /// 0.0 when the board is empty or lightly used, rising to 1.0 when full.
  double _pressureFor(Board board) {
    final double occupancy = board.occupancy;
    if (occupancy <= _pressureThreshold) return 0;
    return ((occupancy - _pressureThreshold) / (1 - _pressureThreshold)).clamp(
      0.0,
      1.0,
    );
  }

  TrayPiece _rollPiece(double pressure) => TrayPiece(
    id: _nextPieceId++,
    shape: _rollShape(pressure),
    colorIndex: _random.nextInt(_paletteSize),
  );

  Shape _rollShape(double pressure) {
    int total = 0;
    final List<int> weights = <int>[];
    for (final Shape shape in ShapeCatalog.all) {
      final int w = _weightFor(shape, pressure);
      weights.add(w);
      total += w;
    }

    int roll = _random.nextInt(total);
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return ShapeCatalog.all[i];
    }
    return ShapeCatalog.all.last;
  }

  /// Scales a shape's spawn weight down as the board fills.
  ///
  /// The penalty grows with both board pressure and shape size, so a 3x3 square
  /// becomes rare on a crowded board while a 5-cell line only becomes somewhat
  /// less likely. Weight is never driven to zero — every shape can still turn
  /// up, so the run gets harder honestly instead of being quietly rigged safe.
  int _weightFor(Shape shape, double pressure) {
    if (pressure <= 0 || shape.blockCount < _largeShapeBlocks) {
      return shape.weight;
    }
    // 0.4 at the "large" threshold, ramping to 1.0 at the biggest shape.
    final double sizeFactor =
        (0.4 +
                0.6 *
                    (shape.blockCount - _largeShapeBlocks) /
                    (_hugeShapeBlocks - _largeShapeBlocks))
            .clamp(0.0, 1.0);
    final double factor = 1 - (_maxSizePenalty * pressure * sizeFactor);
    return max(1, (shape.weight * factor).round());
  }

  bool _anyPlaceable(Board board, List<TrayPiece> pieces) {
    for (final TrayPiece piece in pieces) {
      if (board.hasAnyPlacement(piece.shape)) return true;
    }
    return false;
  }

  Shape? _largestFittingShape(Board board) {
    final List<Shape> fitting = ShapeCatalog.all
        .where((Shape s) => board.hasAnyPlacement(s))
        .toList();
    if (fitting.isEmpty) return null;
    fitting.sort((Shape a, Shape b) => b.blockCount.compareTo(a.blockCount));
    return fitting.first;
  }
}

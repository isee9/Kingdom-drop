import 'package:meta/meta.dart';

/// A cell offset inside a shape, or an absolute cell on the board.
///
/// Deliberately not `dart:ui`'s `Offset` or `Point<int>` — the engine stays
/// free of Flutter so it can be unit tested without a binding.
@immutable
class Cell {
  const Cell(this.row, this.col);

  final int row;
  final int col;

  Cell translate(int dRow, int dCol) => Cell(row + dRow, col + dCol);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

/// An immutable block piece.
///
/// Cells are normalised so the top-left of the bounding box is (0,0). Shapes
/// are never rotated at runtime; every orientation a player can receive is its
/// own catalogue entry, which keeps placement checks trivial and makes the
/// spawn weights explicit per orientation.
@immutable
class Shape {
  const Shape({
    required this.id,
    required this.cells,
    required this.width,
    required this.height,
    required this.weight,
  });

  /// Builds a shape from an ASCII sketch, which keeps the catalogue readable.
  /// Any character other than space or '.' counts as a filled cell.
  factory Shape.fromPattern({
    required String id,
    required List<String> pattern,
    required int weight,
  }) {
    final List<Cell> cells = <Cell>[];
    for (int r = 0; r < pattern.length; r++) {
      final String line = pattern[r];
      for (int c = 0; c < line.length; c++) {
        final String ch = line[c];
        if (ch != ' ' && ch != '.') cells.add(Cell(r, c));
      }
    }
    assert(cells.isNotEmpty, 'Shape "$id" has no filled cells');

    int minRow = cells.first.row, minCol = cells.first.col;
    int maxRow = minRow, maxCol = minCol;
    for (final Cell cell in cells) {
      if (cell.row < minRow) minRow = cell.row;
      if (cell.col < minCol) minCol = cell.col;
      if (cell.row > maxRow) maxRow = cell.row;
      if (cell.col > maxCol) maxCol = cell.col;
    }

    final List<Cell> normalised = <Cell>[
      for (final Cell cell in cells) Cell(cell.row - minRow, cell.col - minCol),
    ];

    return Shape(
      id: id,
      cells: List<Cell>.unmodifiable(normalised),
      width: maxCol - minCol + 1,
      height: maxRow - minRow + 1,
      weight: weight,
    );
  }

  final String id;

  /// Filled cells, normalised to a (0,0) origin.
  final List<Cell> cells;

  /// Bounding box.
  final int width;
  final int height;

  /// Relative spawn frequency. Larger shapes carry smaller weights so the tray
  /// is mostly workable pieces with the occasional awkward one.
  final int weight;

  int get blockCount => cells.length;

  /// True if this shape occupies (row, col) of its own bounding box.
  bool occupies(int row, int col) {
    for (final Cell cell in cells) {
      if (cell.row == row && cell.col == col) return true;
    }
    return false;
  }

  @override
  String toString() => 'Shape($id, ${width}x$height, $blockCount blocks)';
}

/// Every shape the generator can produce.
///
/// Weighting philosophy: 1–3 block pieces are the bread and butter, 4–5 block
/// pieces are common enough to matter, and the 3x3 square is rare because it
/// needs a large clean area and is the main cause of a sudden loss.
abstract final class ShapeCatalog {
  static final List<Shape> all = List<Shape>.unmodifiable(<Shape>[
    // ---------------------------------------------------------- 1 block
    Shape.fromPattern(id: 'dot', pattern: <String>['X'], weight: 70),

    // --------------------------------------------------------- 2 blocks
    Shape.fromPattern(id: 'h2', pattern: <String>['XX'], weight: 90),
    Shape.fromPattern(id: 'v2', pattern: <String>['X', 'X'], weight: 90),

    // --------------------------------------------- 3 blocks — lines
    Shape.fromPattern(id: 'h3', pattern: <String>['XXX'], weight: 80),
    Shape.fromPattern(id: 'v3', pattern: <String>['X', 'X', 'X'], weight: 80),

    // ------------------------------------------ 3 blocks — corners (L tromino)
    Shape.fromPattern(
      id: 'corner_tl',
      pattern: <String>['XX', 'X.'],
      weight: 62,
    ),
    Shape.fromPattern(
      id: 'corner_tr',
      pattern: <String>['XX', '.X'],
      weight: 62,
    ),
    Shape.fromPattern(
      id: 'corner_bl',
      pattern: <String>['X.', 'XX'],
      weight: 62,
    ),
    Shape.fromPattern(
      id: 'corner_br',
      pattern: <String>['.X', 'XX'],
      weight: 62,
    ),

    // --------------------------------------------------- 4 blocks — square
    Shape.fromPattern(id: 'square2', pattern: <String>['XX', 'XX'], weight: 55),

    // ---------------------------------------------------- 4 blocks — lines
    Shape.fromPattern(id: 'h4', pattern: <String>['XXXX'], weight: 40),
    Shape.fromPattern(
      id: 'v4',
      pattern: <String>['X', 'X', 'X', 'X'],
      weight: 40,
    ),

    // ------------------------------------------------------- 4 blocks — T
    Shape.fromPattern(id: 't_up', pattern: <String>['XXX', '.X.'], weight: 30),
    Shape.fromPattern(
      id: 't_down',
      pattern: <String>['.X.', 'XXX'],
      weight: 30,
    ),
    Shape.fromPattern(
      id: 't_left',
      pattern: <String>['.X', 'XX', '.X'],
      weight: 30,
    ),
    Shape.fromPattern(
      id: 't_right',
      pattern: <String>['X.', 'XX', 'X.'],
      weight: 30,
    ),

    // -------------------------------------------------- 4 blocks — L and J
    Shape.fromPattern(
      id: 'l_0',
      pattern: <String>['X.', 'X.', 'XX'],
      weight: 26,
    ),
    Shape.fromPattern(id: 'l_1', pattern: <String>['XXX', 'X..'], weight: 26),
    Shape.fromPattern(
      id: 'l_2',
      pattern: <String>['XX', '.X', '.X'],
      weight: 26,
    ),
    Shape.fromPattern(id: 'l_3', pattern: <String>['..X', 'XXX'], weight: 26),
    Shape.fromPattern(
      id: 'j_0',
      pattern: <String>['.X', '.X', 'XX'],
      weight: 26,
    ),
    Shape.fromPattern(id: 'j_1', pattern: <String>['X..', 'XXX'], weight: 26),
    Shape.fromPattern(
      id: 'j_2',
      pattern: <String>['XX', 'X.', 'X.'],
      weight: 26,
    ),
    Shape.fromPattern(id: 'j_3', pattern: <String>['XXX', '..X'], weight: 26),

    // -------------------------------------------------- 4 blocks — S and Z
    Shape.fromPattern(id: 's_h', pattern: <String>['.XX', 'XX.'], weight: 18),
    Shape.fromPattern(
      id: 's_v',
      pattern: <String>['X.', 'XX', '.X'],
      weight: 18,
    ),
    Shape.fromPattern(id: 'z_h', pattern: <String>['XX.', '.XX'], weight: 18),
    Shape.fromPattern(
      id: 'z_v',
      pattern: <String>['.X', 'XX', 'X.'],
      weight: 18,
    ),

    // -------------------------------------------------- 5 blocks — long lines
    Shape.fromPattern(id: 'h5', pattern: <String>['XXXXX'], weight: 14),
    Shape.fromPattern(
      id: 'v5',
      pattern: <String>['X', 'X', 'X', 'X', 'X'],
      weight: 14,
    ),

    // ------------------------------------------------ 6 blocks — rectangles
    Shape.fromPattern(
      id: 'rect23',
      pattern: <String>['XXX', 'XXX'],
      weight: 12,
    ),
    Shape.fromPattern(
      id: 'rect32',
      pattern: <String>['XX', 'XX', 'XX'],
      weight: 12,
    ),

    // ------------------------------------------------------ 9 blocks — big
    Shape.fromPattern(
      id: 'square3',
      pattern: <String>['XXX', 'XXX', 'XXX'],
      weight: 5,
    ),
  ]);

  static final Map<String, Shape> _byId = <String, Shape>{
    for (final Shape s in all) s.id: s,
  };

  static Shape byId(String id) {
    final Shape? shape = _byId[id];
    if (shape == null) throw ArgumentError('Unknown shape id: $id');
    return shape;
  }

  /// Shapes small enough to be a reliable rescue when the board is tight.
  static List<Shape> get smallShapes =>
      all.where((Shape s) => s.blockCount <= 2).toList(growable: false);

  static int get totalWeight =>
      all.fold(0, (int sum, Shape s) => sum + s.weight);
}

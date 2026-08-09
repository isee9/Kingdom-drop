import 'shape.dart';

/// What kind of group completed and cleared.
enum ClearType { row, column, region }

/// One completed group removed by a placement.
class ClearGroup {
  const ClearGroup({
    required this.type,
    required this.index,
    required this.cells,
  });

  final ClearType type;

  /// Row number, column number, or region ordinal depending on [type].
  final int index;

  /// Every cell removed by this group. Groups can overlap — a cell sitting at
  /// the intersection of a cleared row and a cleared column appears in both.
  final List<Cell> cells;

  @override
  String toString() => 'ClearGroup(${type.name} $index)';
}

/// A fixed 3x3 area that clears when completely filled.
class BoardRegion {
  const BoardRegion({
    required this.index,
    required this.topRow,
    required this.leftCol,
    required this.size,
  });

  final int index;
  final int topRow;
  final int leftCol;
  final int size;

  bool contains(int row, int col) =>
      row >= topRow &&
      row < topRow + size &&
      col >= leftCol &&
      col < leftCol + size;
}

/// The 7x7 playfield.
///
/// ## Region layout
///
/// Seven does not divide by three, so the classic "every 3x3 block" rule cannot
/// tile this board. Kingdom Drop uses four fixed 3x3 quadrants pinned to the
/// corners:
///
/// ```
///   A A A | B B B      rows/cols 0-2 and 4-6 form the quadrants
///   A A A | B B B      row 3 and column 3 are the "cross"
///   A A A | B B B
///   - - - + - - -
///   C C C | D D D
///   C C C | D D D
///   C C C | D D D
/// ```
///
/// No cell belongs to two quadrants, so the rule stays unambiguous and the UI
/// can draw it as four tinted plates split by a visible cross. Cells on the
/// cross still count toward row and column clears, which makes the middle lane
/// the natural place to dump an awkward piece.
class Board {
  Board({this.size = defaultSize})
    : _cells = List<int>.filled(size * size, emptyCell);

  /// Restores a board from a flat cell list. Used by save/load and tests.
  Board.fromCells(List<int> cells, {this.size = defaultSize})
    : _cells = List<int>.of(cells) {
    if (cells.length != size * size) {
      throw ArgumentError(
        'Expected ${size * size} cells for a $size x $size board, '
        'got ${cells.length}',
      );
    }
  }

  /// Builds a board from an ASCII sketch, one string per row. Any character
  /// other than space or '.' is a filled cell. Test-facing convenience.
  factory Board.fromPattern(List<String> pattern) {
    final int size = pattern.length;
    final Board board = Board(size: size);
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < pattern[r].length && c < size; c++) {
        final String ch = pattern[r][c];
        if (ch != ' ' && ch != '.') board.setCell(r, c, 0);
      }
    }
    return board;
  }

  static const int defaultSize = 7;
  static const int regionSize = 3;
  static const int emptyCell = -1;

  final int size;

  /// Row-major cell colours. [emptyCell] means empty; anything else is an index
  /// into the block palette.
  final List<int> _cells;

  /// Read-only view for renderers and save code.
  List<int> get cells => List<int>.unmodifiable(_cells);

  int get cellCount => size * size;

  // ------------------------------------------------------------- regions
  static final List<BoardRegion> regions = List<BoardRegion>.unmodifiable(
    <BoardRegion>[
      for (int qr = 0; qr < 2; qr++)
        for (int qc = 0; qc < 2; qc++)
          BoardRegion(
            index: qr * 2 + qc,
            topRow: qr * (defaultSize - regionSize),
            leftCol: qc * (defaultSize - regionSize),
            size: regionSize,
          ),
    ],
  );

  /// True for cells in the central cross, which belong to no region.
  static bool isCrossCell(int row, int col) {
    for (final BoardRegion region in regions) {
      if (region.contains(row, col)) return false;
    }
    return true;
  }

  // --------------------------------------------------------------- access
  bool inBounds(int row, int col) =>
      row >= 0 && row < size && col >= 0 && col < size;

  int cellAt(int row, int col) =>
      inBounds(row, col) ? _cells[row * size + col] : emptyCell;

  bool isFilled(int row, int col) => cellAt(row, col) != emptyCell;

  bool isEmpty(int row, int col) => inBounds(row, col) && !isFilled(row, col);

  void setCell(int row, int col, int colorIndex) {
    if (!inBounds(row, col)) return;
    _cells[row * size + col] = colorIndex;
  }

  void clearCell(int row, int col) => setCell(row, col, emptyCell);

  void clearAll() {
    for (int i = 0; i < _cells.length; i++) {
      _cells[i] = emptyCell;
    }
  }

  int get filledCount {
    int n = 0;
    for (final int c in _cells) {
      if (c != emptyCell) n++;
    }
    return n;
  }

  double get occupancy => filledCount / cellCount;

  Board copy() => Board.fromCells(_cells, size: size);

  // ------------------------------------------------------------ placement
  /// True if [shape] fits with its bounding-box origin at (row, col): fully in
  /// bounds and over empty cells only.
  bool canPlace(Shape shape, int row, int col) {
    for (final Cell cell in shape.cells) {
      final int r = row + cell.row;
      final int c = col + cell.col;
      if (!inBounds(r, c)) return false;
      if (isFilled(r, c)) return false;
    }
    return true;
  }

  /// True if [shape] fits anywhere at all.
  bool hasAnyPlacement(Shape shape) => firstPlacement(shape) != null;

  /// The top-left-most origin where [shape] fits, or null.
  Cell? firstPlacement(Shape shape) {
    final int maxRow = size - shape.height;
    final int maxCol = size - shape.width;
    for (int r = 0; r <= maxRow; r++) {
      for (int c = 0; c <= maxCol; c++) {
        if (canPlace(shape, r, c)) return Cell(r, c);
      }
    }
    return null;
  }

  /// Every origin where [shape] fits.
  List<Cell> allPlacements(Shape shape) {
    final List<Cell> result = <Cell>[];
    final int maxRow = size - shape.height;
    final int maxCol = size - shape.width;
    for (int r = 0; r <= maxRow; r++) {
      for (int c = 0; c <= maxCol; c++) {
        if (canPlace(shape, r, c)) result.add(Cell(r, c));
      }
    }
    return result;
  }

  /// Writes [shape] onto the board. Callers must check [canPlace] first;
  /// placing an illegal shape throws rather than silently corrupting the board.
  List<Cell> place(Shape shape, int row, int col, int colorIndex) {
    if (!canPlace(shape, row, col)) {
      throw StateError('Illegal placement of ${shape.id} at ($row,$col)');
    }
    final List<Cell> written = <Cell>[];
    for (final Cell cell in shape.cells) {
      final int r = row + cell.row;
      final int c = col + cell.col;
      setCell(r, c, colorIndex);
      written.add(Cell(r, c));
    }
    return written;
  }

  // -------------------------------------------------------------- clearing
  /// Every complete row, column and region, without mutating the board.
  ///
  /// Order matters for presentation only: rows, then columns, then regions.
  List<ClearGroup> findCompleteGroups() {
    final List<ClearGroup> groups = <ClearGroup>[];

    for (int r = 0; r < size; r++) {
      bool full = true;
      for (int c = 0; c < size; c++) {
        if (!isFilled(r, c)) {
          full = false;
          break;
        }
      }
      if (full) {
        groups.add(
          ClearGroup(
            type: ClearType.row,
            index: r,
            cells: <Cell>[for (int c = 0; c < size; c++) Cell(r, c)],
          ),
        );
      }
    }

    for (int c = 0; c < size; c++) {
      bool full = true;
      for (int r = 0; r < size; r++) {
        if (!isFilled(r, c)) {
          full = false;
          break;
        }
      }
      if (full) {
        groups.add(
          ClearGroup(
            type: ClearType.column,
            index: c,
            cells: <Cell>[for (int r = 0; r < size; r++) Cell(r, c)],
          ),
        );
      }
    }

    for (final BoardRegion region in regions) {
      bool full = true;
      final List<Cell> cells = <Cell>[];
      for (int r = region.topRow; r < region.topRow + region.size; r++) {
        for (int c = region.leftCol; c < region.leftCol + region.size; c++) {
          cells.add(Cell(r, c));
          if (!isFilled(r, c)) full = false;
        }
        if (!full) break;
      }
      if (full) {
        groups.add(
          ClearGroup(
            type: ClearType.region,
            index: region.index,
            cells: cells,
          ),
        );
      }
    }

    return groups;
  }

  /// Empties every cell covered by [groups] and returns the distinct set that
  /// actually changed, so the renderer does not animate a cell twice when a row
  /// and a column intersect.
  Set<Cell> applyClears(List<ClearGroup> groups) {
    final Set<Cell> cleared = <Cell>{};
    for (final ClearGroup group in groups) {
      for (final Cell cell in group.cells) {
        if (isFilled(cell.row, cell.col)) {
          clearCell(cell.row, cell.col);
          cleared.add(cell);
        }
      }
    }
    return cleared;
  }

  @override
  String toString() {
    final StringBuffer sb = StringBuffer();
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        sb.write(isFilled(r, c) ? 'X' : '.');
      }
      if (r < size - 1) sb.writeln();
    }
    return sb.toString();
  }
}

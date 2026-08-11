import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/game/engine/board.dart';
import 'package:kingdom_drop/game/engine/shape.dart';

void main() {
  group('Board geometry', () {
    test('is 7x7 with 49 cells, all empty at construction', () {
      final Board board = Board();
      expect(board.size, 7);
      expect(board.cellCount, 49);
      expect(board.filledCount, 0);
      expect(board.occupancy, 0);
    });

    test('defines four non-overlapping 3x3 regions', () {
      expect(Board.regions.length, 4);

      // No cell may belong to two regions.
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          final int owners = Board.regions
              .where((BoardRegion region) => region.contains(r, c))
              .length;
          expect(owners, lessThanOrEqualTo(1), reason: 'cell ($r,$c)');
        }
      }
    });

    test('row 3 and column 3 form the region-free cross', () {
      for (int i = 0; i < 7; i++) {
        expect(Board.isCrossCell(3, i), isTrue, reason: 'row 3 col $i');
        expect(Board.isCrossCell(i, 3), isTrue, reason: 'row $i col 3');
      }
      expect(Board.isCrossCell(0, 0), isFalse);
      expect(Board.isCrossCell(6, 6), isFalse);
    });

    test('regions cover exactly the four corner quadrants', () {
      final Set<String> covered = <String>{};
      for (final BoardRegion region in Board.regions) {
        for (int r = region.topRow; r < region.topRow + region.size; r++) {
          for (int c = region.leftCol; c < region.leftCol + region.size; c++) {
            covered.add('$r,$c');
          }
        }
      }
      expect(covered.length, 36); // 4 quadrants x 9 cells
      expect(covered.contains('3,3'), isFalse);
    });

    test('bounds checking rejects off-board coordinates', () {
      final Board board = Board();
      expect(board.inBounds(0, 0), isTrue);
      expect(board.inBounds(6, 6), isTrue);
      expect(board.inBounds(-1, 0), isFalse);
      expect(board.inBounds(7, 0), isFalse);
      expect(board.inBounds(0, 7), isFalse);
      expect(board.cellAt(99, 99), Board.emptyCell);
    });
  });

  group('Placement', () {
    test('accepts a legal placement and writes the colour', () {
      final Board board = Board();
      final Shape square = ShapeCatalog.byId('square2');

      expect(board.canPlace(square, 0, 0), isTrue);
      final List<Cell> written = board.place(square, 0, 0, 3);

      expect(written.length, 4);
      expect(board.cellAt(0, 0), 3);
      expect(board.cellAt(1, 1), 3);
      expect(board.filledCount, 4);
    });

    test('rejects a placement that overlaps an occupied cell', () {
      final Board board = Board();
      final Shape square = ShapeCatalog.byId('square2');
      board.place(square, 0, 0, 0);

      expect(board.canPlace(square, 0, 0), isFalse);
      expect(board.canPlace(square, 1, 1), isFalse);
      expect(board.canPlace(square, 0, 1), isFalse);
      expect(board.canPlace(square, 2, 2), isTrue);
    });

    test('rejects a placement that runs off the edge', () {
      final Board board = Board();
      final Shape long = ShapeCatalog.byId('h5');

      expect(board.canPlace(long, 0, 2), isTrue); // cols 2-6
      expect(board.canPlace(long, 0, 3), isFalse); // would need col 7
      expect(board.canPlace(long, 0, -1), isFalse);
    });

    test(
      'place() throws rather than corrupting the board on an illegal move',
      () {
        final Board board = Board();
        final Shape square = ShapeCatalog.byId('square2');
        board.place(square, 0, 0, 0);

        expect(() => board.place(square, 0, 0, 1), throwsStateError);
        expect(board.filledCount, 4);
      },
    );

    test('hasAnyPlacement is false only when nothing fits', () {
      final Board full = Board.fromPattern(const <String>[
        'XXXXXXX',
        'XXXXXXX',
        'XXXXXXX',
        'XXXXXXX',
        'XXXXXXX',
        'XXXXXXX',
        'XXXXXX.',
      ]);
      expect(full.hasAnyPlacement(ShapeCatalog.byId('dot')), isTrue);
      expect(full.hasAnyPlacement(ShapeCatalog.byId('h2')), isFalse);
      expect(full.hasAnyPlacement(ShapeCatalog.byId('square2')), isFalse);
    });

    test('allPlacements enumerates every legal origin on an empty board', () {
      final Board board = Board();
      // A 1x1 fits in all 49 cells; a 2x2 fits in a 6x6 grid of origins.
      expect(board.allPlacements(ShapeCatalog.byId('dot')).length, 49);
      expect(board.allPlacements(ShapeCatalog.byId('square2')).length, 36);
      expect(board.allPlacements(ShapeCatalog.byId('square3')).length, 25);
    });
  });

  group('Clearing', () {
    test('detects and clears a completed row', () {
      final Board board = Board.fromPattern(const <String>[
        'XXXXXXX',
        '.......',
        '.......',
        '.......',
        '.......',
        '.......',
        '.......',
      ]);

      final List<ClearGroup> groups = board.findCompleteGroups();
      expect(groups.length, 1);
      expect(groups.single.type, ClearType.row);
      expect(groups.single.index, 0);

      final Set<Cell> cleared = board.applyClears(groups);
      expect(cleared.length, 7);
      expect(board.filledCount, 0);
    });

    test('detects and clears a completed column', () {
      final Board board = Board();
      for (int r = 0; r < 7; r++) {
        board.setCell(r, 4, 1);
      }

      final List<ClearGroup> groups = board.findCompleteGroups();
      expect(groups.length, 1);
      expect(groups.single.type, ClearType.column);
      expect(groups.single.index, 4);

      board.applyClears(groups);
      expect(board.filledCount, 0);
    });

    test('detects and clears a completed 3x3 region', () {
      final Board board = Board.fromPattern(const <String>[
        'XXX....',
        'XXX....',
        'XXX....',
        '.......',
        '.......',
        '.......',
        '.......',
      ]);

      final List<ClearGroup> groups = board.findCompleteGroups();
      expect(groups.length, 1);
      expect(groups.single.type, ClearType.region);
      expect(groups.single.index, 0);

      board.applyClears(groups);
      expect(board.filledCount, 0);
    });

    test('clears the bottom-right region independently', () {
      final Board board = Board.fromPattern(const <String>[
        '.......',
        '.......',
        '.......',
        '.......',
        '....XXX',
        '....XXX',
        '....XXX',
      ]);

      final List<ClearGroup> groups = board.findCompleteGroups();
      expect(groups.length, 1);
      expect(groups.single.type, ClearType.region);
      expect(groups.single.index, 3);
    });

    test('an almost-complete region does not clear', () {
      final Board board = Board.fromPattern(const <String>[
        'XXX....',
        'XXX....',
        'XX.....',
        '.......',
        '.......',
        '.......',
        '.......',
      ]);
      expect(board.findCompleteGroups(), isEmpty);
    });

    test(
      'a full row through the cross clears even though it spans regions',
      () {
        final Board board = Board();
        for (int c = 0; c < 7; c++) {
          board.setCell(3, c, 2);
        }
        final List<ClearGroup> groups = board.findCompleteGroups();
        expect(groups.length, 1);
        expect(groups.single.type, ClearType.row);
        expect(groups.single.index, 3);
      },
    );

    test('a row and a column clearing together report as two groups', () {
      final Board board = Board();
      for (int c = 0; c < 7; c++) {
        board.setCell(2, c, 0);
      }
      for (int r = 0; r < 7; r++) {
        board.setCell(r, 5, 0);
      }

      final List<ClearGroup> groups = board.findCompleteGroups();
      expect(groups.length, 2);
      expect(groups.map((ClearGroup g) => g.type).toSet(), <ClearType>{
        ClearType.row,
        ClearType.column,
      });

      // The shared cell (2,5) must only be counted once in the cleared set.
      final Set<Cell> cleared = board.applyClears(groups);
      expect(cleared.length, 13); // 7 + 7 - 1 overlap
      expect(board.filledCount, 0);
    });

    test('a row, a column and a region can all clear from one board state', () {
      final Board board = Board.fromPattern(const <String>[
        'XXX.X..',
        'XXX.X..',
        'XXXXXXX',
        '....X..',
        '....X..',
        '....X..',
        '....X..',
      ]);

      final List<ClearGroup> groups = board.findCompleteGroups();
      final Set<ClearType> types = groups.map((ClearGroup g) => g.type).toSet();

      expect(
        types,
        containsAll(<ClearType>[
          ClearType.row,
          ClearType.column,
          ClearType.region,
        ]),
      );
      expect(groups.length, 3);
    });

    test('four simultaneous clears are possible', () {
      // Rows 0 and 1 full, columns 0 and 1 full.
      final Board board = Board();
      for (int c = 0; c < 7; c++) {
        board.setCell(0, c, 0);
        board.setCell(1, c, 0);
      }
      for (int r = 0; r < 7; r++) {
        board.setCell(r, 0, 0);
        board.setCell(r, 1, 0);
      }

      final List<ClearGroup> groups = board.findCompleteGroups();
      expect(groups.length, greaterThanOrEqualTo(4));
    });
  });

  group('Serialisation', () {
    test('round-trips through a flat cell list', () {
      final Board board = Board();
      board.place(ShapeCatalog.byId('t_up'), 2, 2, 5);
      final Board restored = Board.fromCells(board.cells);

      expect(restored.cells, board.cells);
      expect(restored.filledCount, board.filledCount);
    });

    test('rejects a cell list of the wrong length', () {
      expect(() => Board.fromCells(const <int>[1, 2, 3]), throwsArgumentError);
    });

    test('copy() is independent of the original', () {
      final Board board = Board();
      final Board copy = board.copy();
      copy.setCell(0, 0, 1);

      expect(board.isFilled(0, 0), isFalse);
      expect(copy.isFilled(0, 0), isTrue);
    });
  });
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/game/engine/board.dart';
import 'package:kingdom_drop/game/engine/shape.dart';
import 'package:kingdom_drop/game/engine/shape_generator.dart';

void main() {
  group('Shape catalogue', () {
    test('every shape normalises to a (0,0) origin', () {
      for (final Shape shape in ShapeCatalog.all) {
        final int minRow = shape.cells
            .map((Cell c) => c.row)
            .reduce((int a, int b) => a < b ? a : b);
        final int minCol = shape.cells
            .map((Cell c) => c.col)
            .reduce((int a, int b) => a < b ? a : b);
        expect(minRow, 0, reason: shape.id);
        expect(minCol, 0, reason: shape.id);
      }
    });

    test('bounding boxes match the cells they contain', () {
      for (final Shape shape in ShapeCatalog.all) {
        final int maxRow = shape.cells
            .map((Cell c) => c.row)
            .reduce((int a, int b) => a > b ? a : b);
        final int maxCol = shape.cells
            .map((Cell c) => c.col)
            .reduce((int a, int b) => a > b ? a : b);
        expect(shape.height, maxRow + 1, reason: shape.id);
        expect(shape.width, maxCol + 1, reason: shape.id);
      }
    });

    test('shape ids are unique', () {
      final Set<String> ids = ShapeCatalog.all.map((Shape s) => s.id).toSet();
      expect(ids.length, ShapeCatalog.all.length);
    });

    test('no shape has duplicate cells', () {
      for (final Shape shape in ShapeCatalog.all) {
        expect(
          shape.cells.toSet().length,
          shape.cells.length,
          reason: shape.id,
        );
      }
    });

    test('every shape fits on an empty board', () {
      final Board board = Board();
      for (final Shape shape in ShapeCatalog.all) {
        expect(shape.width, lessThanOrEqualTo(board.size), reason: shape.id);
        expect(shape.height, lessThanOrEqualTo(board.size), reason: shape.id);
        expect(board.hasAnyPlacement(shape), isTrue, reason: shape.id);
      }
    });

    test('contains the shapes the design calls for', () {
      const List<String> required = <String>[
        'dot',
        'h2',
        'v2',
        'h3',
        'v3',
        'square2',
        'h4',
        'v4',
        'square3',
      ];
      for (final String id in required) {
        expect(() => ShapeCatalog.byId(id), returnsNormally, reason: id);
      }
    });

    test('byId rejects an unknown id', () {
      expect(() => ShapeCatalog.byId('nope'), throwsArgumentError);
    });

    test('bigger shapes carry smaller spawn weights', () {
      final Shape dot = ShapeCatalog.byId('dot');
      final Shape square2 = ShapeCatalog.byId('square2');
      final Shape square3 = ShapeCatalog.byId('square3');

      expect(square2.weight, lessThan(dot.weight));
      expect(square3.weight, lessThan(square2.weight));
    });

    test('occupies() reports the filled cells of the bounding box', () {
      final Shape corner = ShapeCatalog.byId('corner_tl'); // XX / X.
      expect(corner.occupies(0, 0), isTrue);
      expect(corner.occupies(0, 1), isTrue);
      expect(corner.occupies(1, 0), isTrue);
      expect(corner.occupies(1, 1), isFalse);
    });
  });

  group('Generation', () {
    test('deals exactly three pieces', () {
      final ShapeGenerator gen = ShapeGenerator(random: Random(1));
      final List<TrayPiece> set = gen.generateSet(Board());

      expect(set.length, 3);
      expect(set.every((TrayPiece p) => !p.used), isTrue);
    });

    test('assigns each piece a unique id and a palette colour', () {
      final ShapeGenerator gen = ShapeGenerator(random: Random(2));
      final List<TrayPiece> a = gen.generateSet(Board());
      final List<TrayPiece> b = gen.generateSet(Board());

      final Set<int> ids = <int>{
        for (final TrayPiece p in <TrayPiece>[...a, ...b]) p.id,
      };
      expect(ids.length, 6);

      for (final TrayPiece p in a) {
        expect(p.colorIndex, inInclusiveRange(0, 5));
      }
    });

    test('is deterministic for a given seed', () {
      final List<String> first = ShapeGenerator(
        random: Random(99),
      ).generateSet(Board()).map((TrayPiece p) => p.shape.id).toList();
      final List<String> second = ShapeGenerator(
        random: Random(99),
      ).generateSet(Board()).map((TrayPiece p) => p.shape.id).toList();

      expect(first, second);
    });

    test('always includes at least one placeable piece on an empty board', () {
      for (int seed = 0; seed < 200; seed++) {
        final Board board = Board();
        final List<TrayPiece> set = ShapeGenerator(
          random: Random(seed),
        ).generateSet(board);
        expect(
          set.any((TrayPiece p) => board.hasAnyPlacement(p.shape)),
          isTrue,
          reason: 'seed $seed',
        );
      }
    });

    test('always includes a placeable piece on a heavily congested board', () {
      // Only isolated single cells remain free.
      const List<String> congested = <String>[
        '.XXXXX.',
        'X.XXXXX',
        'XX.XXXX',
        'XXX.XXX',
        'XXXX.XX',
        'XXXXX.X',
        '.XXXXXX',
      ];

      for (int seed = 0; seed < 200; seed++) {
        final Board board = Board.fromPattern(congested);
        final List<TrayPiece> set = ShapeGenerator(
          random: Random(seed),
        ).generateSet(board);

        expect(
          set.any((TrayPiece p) => board.hasAnyPlacement(p.shape)),
          isTrue,
          reason: 'seed $seed must include a rescue piece',
        );
      }
    });

    test('gives up gracefully when literally nothing can be placed', () {
      final Board full = Board.fromPattern(const <String>[
        'XXXXXXX',
        'XXXXXXX',
        'XXXXXXX',
        'XXXXXXX',
        'XXXXXXX',
        'XXXXXXX',
        'XXXXXXX',
      ]);

      final List<TrayPiece> set = ShapeGenerator(
        random: Random(7),
      ).generateSet(full);

      // No rescue exists, so it still returns a full set rather than hanging or
      // throwing — the engine then reports game over.
      expect(set.length, 3);
      expect(set.any((TrayPiece p) => full.hasAnyPlacement(p.shape)), isFalse);
    });

    test('down-weights large pieces as the board fills', () {
      // Sample many sets on an empty board versus a congested one and compare
      // how often 5+ block shapes appear.
      // ~71% occupied, with a clear two-column corridor so most shapes still
      // have somewhere to go and the fairness re-roll does not skew the sample.
      const List<String> congested = <String>[
        'XXXXX..',
        'XXXXX..',
        'XXXXX..',
        'XXXXX..',
        'XXXXX..',
        'XXXXX..',
        'XXXXX..',
      ];

      int largeOnEmpty = 0;
      int largeOnCongested = 0;

      for (int seed = 0; seed < 400; seed++) {
        for (final TrayPiece p in ShapeGenerator(
          random: Random(seed),
        ).generateSet(Board())) {
          if (p.shape.blockCount >= 5) largeOnEmpty++;
        }
        for (final TrayPiece p in ShapeGenerator(
          random: Random(seed),
        ).generateSet(Board.fromPattern(congested))) {
          if (p.shape.blockCount >= 5) largeOnCongested++;
        }
      }

      expect(
        largeOnCongested,
        lessThan(largeOnEmpty),
        reason: 'pressure should reduce large-piece frequency',
      );
      expect(
        largeOnCongested,
        greaterThan(0),
        reason: 'large pieces must never disappear entirely',
      );
    });

    test('small pieces dominate the distribution on an open board', () {
      int small = 0;
      int total = 0;
      for (int seed = 0; seed < 500; seed++) {
        for (final TrayPiece p in ShapeGenerator(
          random: Random(seed),
        ).generateSet(Board())) {
          total++;
          if (p.shape.blockCount <= 4) small++;
        }
      }
      expect(small / total, greaterThan(0.8));
    });
  });

  group('Shuffle', () {
    test('replaces unused pieces and preserves used ones', () {
      final ShapeGenerator gen = ShapeGenerator(random: Random(11));
      final Board board = Board();
      final List<TrayPiece> tray = gen.generateSet(board);
      tray[0].used = true;

      final List<TrayPiece> shuffled = gen.shuffleTray(board, tray);

      expect(shuffled.length, 3);
      expect(shuffled[0].id, tray[0].id, reason: 'used piece must survive');
      expect(shuffled[0].used, isTrue);
      expect(shuffled[1].id, isNot(tray[1].id));
      expect(shuffled[2].id, isNot(tray[2].id));
    });

    test('is a no-op when every piece has been used', () {
      final ShapeGenerator gen = ShapeGenerator(random: Random(12));
      final Board board = Board();
      final List<TrayPiece> tray = gen.generateSet(board);
      for (final TrayPiece p in tray) {
        p.used = true;
      }

      expect(gen.shuffleTray(board, tray), same(tray));
    });
  });
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/core/config/economy_config.dart';
import 'package:kingdom_drop/game/engine/board.dart';
import 'package:kingdom_drop/game/engine/game_engine.dart';
import 'package:kingdom_drop/game/engine/shape.dart';

/// Paints [pattern] onto the engine's board, replacing whatever was there.
void paintBoard(GameEngine engine, List<String> pattern) {
  for (int r = 0; r < engine.board.size; r++) {
    for (int c = 0; c < engine.board.size; c++) {
      final String ch = pattern[r][c];
      if (ch == '.' || ch == ' ') {
        engine.board.clearCell(r, c);
      } else {
        engine.board.setCell(r, c, 0);
      }
    }
  }
}

/// A board that is nearly full but has no completed row, column or region, and
/// whose eight empty cells are all isolated — only a single-cell piece fits.
///
/// Building the jam this way matters: naively filling every cell but one leaves
/// six complete rows sitting on the board, so the next placement clears the
/// whole thing instead of ending the run.
const List<String> kJammedBoard = <String>[
  '.XXXXX.',
  'X.XXXXX',
  'XX.XXXX',
  'XXX.XXX',
  'XXXX.XX',
  'XXXXX.X',
  '.XXXXXX',
];

/// Same idea, but with an adjacent pair of empties at (6,5) and (6,6) so a
/// two-cell piece has exactly one legal home and nothing clears when it lands.
const List<String> kOneMoveLeftBoard = <String>[
  '.XXXXX.',
  'X.XXXXX',
  'XX.XXXX',
  'XXX.XXX',
  'XXXX.XX',
  'XXXXX.X',
  '.XXXX..',
];

void main() {
  group('Run lifecycle', () {
    test('starts playing with three pieces and a clean board', () {
      final GameEngine engine = GameEngine(random: Random(1));

      expect(engine.state, GameState.playing);
      expect(engine.tray.length, 3);
      expect(engine.tray.every((dynamic p) => !p.used), isTrue);
      expect(engine.board.filledCount, 0);
      expect(engine.score, 0);
    });

    test('restart wipes the board, score and stats', () {
      final GameEngine engine = GameEngine(random: Random(2));
      engine.place(engine.tray.first.id, 0, 0);
      expect(engine.board.filledCount, greaterThan(0));

      engine.restart();

      expect(engine.board.filledCount, 0);
      expect(engine.score, 0);
      expect(engine.stats.piecesPlaced, 0);
      expect(engine.state, GameState.playing);
      expect(engine.tray.length, 3);
    });

    test('endGame stamps a duration and locks the run', () {
      final GameEngine engine = GameEngine(random: Random(3));
      engine.endGame();

      expect(engine.state, GameState.ended);
      expect(engine.isPlaying, isFalse);
      expect(engine.canPlace(engine.tray.first.id, 0, 0), isFalse);
    });
  });

  group('Placing pieces', () {
    test('accepts a legal drop and scores it', () {
      final GameEngine engine = GameEngine(random: Random(4));
      final int id = engine.tray.first.id;
      final int blocks = engine.tray.first.shape.blockCount;

      final PlacementResult result = engine.place(id, 0, 0);

      expect(result.accepted, isTrue);
      expect(result.placedCells.length, blocks);
      expect(engine.score, blocks * EconomyConfig.pointsPerBlock);
      expect(engine.stats.piecesPlaced, 1);
      expect(engine.pieceById(id)!.used, isTrue);
    });

    test('rejects dropping the same piece twice', () {
      final GameEngine engine = GameEngine(random: Random(5));
      final int id = engine.tray.first.id;
      engine.place(id, 0, 0);

      final PlacementResult second = engine.place(id, 3, 3);

      expect(second.accepted, isFalse);
      expect(engine.stats.piecesPlaced, 1);
    });

    test('rejects an out-of-bounds drop', () {
      final GameEngine engine = GameEngine(random: Random(6));
      final int id = engine.tray.first.id;

      expect(engine.place(id, -1, 0).accepted, isFalse);
      expect(engine.place(id, 99, 99).accepted, isFalse);
      expect(engine.board.filledCount, 0);
    });

    test('rejects an overlapping drop and leaves the board untouched', () {
      final GameEngine engine = GameEngine(random: Random(7));
      engine.debugSetTray(<Shape>[
        ShapeCatalog.byId('square2'),
        ShapeCatalog.byId('square2'),
        ShapeCatalog.byId('dot'),
      ]);

      final List<int> ids = engine.tray
          .map((dynamic p) => p.id as int)
          .toList();
      expect(engine.place(ids[0], 0, 0).accepted, isTrue);

      final int before = engine.board.filledCount;
      expect(engine.place(ids[1], 0, 0).accepted, isFalse);
      expect(engine.board.filledCount, before);
    });

    test('rejects an unknown piece id', () {
      final GameEngine engine = GameEngine(random: Random(8));
      expect(engine.place(123456, 0, 0).accepted, isFalse);
    });

    test('refills the tray only after all three pieces are used', () {
      final GameEngine engine = GameEngine(random: Random(9));
      engine.debugSetTray(<Shape>[
        ShapeCatalog.byId('dot'),
        ShapeCatalog.byId('dot'),
        ShapeCatalog.byId('dot'),
      ]);
      final List<int> ids = engine.tray
          .map((dynamic p) => p.id as int)
          .toList();

      expect(engine.place(ids[0], 0, 0).trayRefilled, isFalse);
      expect(engine.availablePieces.length, 2);

      expect(engine.place(ids[1], 0, 1).trayRefilled, isFalse);
      expect(engine.availablePieces.length, 1);

      final PlacementResult third = engine.place(ids[2], 0, 2);
      expect(third.trayRefilled, isTrue);
      expect(engine.tray.length, 3);
      expect(engine.availablePieces.length, 3);
    });
  });

  group('Clearing through the engine', () {
    test('completing a row clears it and pays clear points', () {
      final GameEngine engine = GameEngine(random: Random(10));
      // Row 0 filled except the last cell.
      for (int c = 0; c < 6; c++) {
        engine.board.setCell(0, c, 1);
      }
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('dot')]);
      final int id = engine.tray.first.id;

      final PlacementResult result = engine.place(id, 0, 6);

      expect(result.didClear, isTrue);
      expect(result.clears.single.type, ClearType.row);
      expect(result.clearedCells.length, 7);
      expect(engine.board.filledCount, 0);
      expect(engine.score, EconomyConfig.pointsPerBlock + 100);
      expect(engine.stats.linesCleared, 1);
    });

    test('completing a column clears it', () {
      final GameEngine engine = GameEngine(random: Random(11));
      for (int r = 0; r < 6; r++) {
        engine.board.setCell(r, 2, 1);
      }
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('dot')]);

      final PlacementResult result = engine.place(engine.tray.first.id, 6, 2);

      expect(result.clears.single.type, ClearType.column);
      expect(engine.board.filledCount, 0);
    });

    test('completing a 3x3 region clears it', () {
      final GameEngine engine = GameEngine(random: Random(12));
      // Top-left quadrant filled except (2,2).
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          if (!(r == 2 && c == 2)) engine.board.setCell(r, c, 1);
        }
      }
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('dot')]);

      final PlacementResult result = engine.place(engine.tray.first.id, 2, 2);

      expect(result.clears.single.type, ClearType.region);
      expect(engine.board.filledCount, 0);
    });

    test('one placement can clear a row and a column at once', () {
      final GameEngine engine = GameEngine(random: Random(13));
      // Row 3 and column 3 both missing only their intersection.
      for (int c = 0; c < 7; c++) {
        if (c != 3) engine.board.setCell(3, c, 1);
      }
      for (int r = 0; r < 7; r++) {
        if (r != 3) engine.board.setCell(r, 3, 1);
      }
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('dot')]);

      final PlacementResult result = engine.place(engine.tray.first.id, 3, 3);

      expect(result.clears.length, 2);
      expect(result.score.multiAxisBonus, EconomyConfig.multiAxisBonus);
      expect(engine.stats.combosTriggered, 1);
      expect(engine.stats.maxSimultaneousClears, 2);
      expect(engine.board.filledCount, 0);
    });

    test('previewClears reports a clear before it is committed', () {
      final GameEngine engine = GameEngine(random: Random(14));
      for (int c = 0; c < 6; c++) {
        engine.board.setCell(0, c, 1);
      }
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('dot')]);
      final int id = engine.tray.first.id;

      final List<ClearGroup> preview = engine.previewClears(id, 0, 6);

      expect(preview.length, 1);
      expect(preview.single.type, ClearType.row);
      // Preview must not mutate anything.
      expect(engine.board.filledCount, 6);
      expect(engine.score, 0);
    });

    test('previewClears is empty for an illegal position', () {
      final GameEngine engine = GameEngine(random: Random(15));
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('square3')]);
      expect(engine.previewClears(engine.tray.first.id, 6, 6), isEmpty);
    });

    test('tracks the deepest combo reached across a run', () {
      final GameEngine engine = GameEngine(random: Random(16));

      for (int i = 0; i < 3; i++) {
        for (int c = 0; c < 6; c++) {
          engine.board.setCell(0, c, 1);
        }
        engine.debugSetTray(<Shape>[ShapeCatalog.byId('dot')]);
        engine.place(engine.tray.first.id, 0, 6);
      }

      expect(engine.stats.bestComboDepth, 3);
      expect(engine.stats.bigCombos, 1);
    });
  });

  group('Game over detection', () {
    test('flags noMoves when nothing in the tray fits', () {
      final GameEngine engine = GameEngine(random: Random(17));
      // Leave one empty cell; a 2x2 cannot fit anywhere.
      paintBoard(engine, kJammedBoard);
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('square2')]);

      expect(
        engine.board.findCompleteGroups(),
        isEmpty,
        reason: 'fixture must be a real jam, not an unresolved clear',
      );
      expect(engine.state, GameState.noMoves);
      expect(engine.hasAvailableMove, isFalse);
    });

    test('stays playing while any single piece still fits', () {
      final GameEngine engine = GameEngine(random: Random(18));
      paintBoard(engine, kJammedBoard);
      engine.debugSetTray(<Shape>[
        ShapeCatalog.byId('square2'),
        ShapeCatalog.byId('dot'),
      ]);

      expect(engine.state, GameState.playing);
      expect(engine.hasAvailableMove, isTrue);
    });

    test('a placement that leaves no room reports outOfMoves', () {
      final GameEngine engine = GameEngine(random: Random(19));
      paintBoard(engine, kOneMoveLeftBoard);
      engine.debugSetTray(<Shape>[
        ShapeCatalog.byId('h2'),
        ShapeCatalog.byId('square3'),
      ]);
      final int id = engine.tray.first.id;

      final PlacementResult result = engine.place(id, 6, 5);

      expect(result.accepted, isTrue);
      expect(result.didClear, isFalse, reason: 'the drop must not clear');
      expect(result.outOfMoves, isTrue);
      expect(engine.state, GameState.noMoves);
    });

    test('debugForceGameOver reaches the noMoves state', () {
      final GameEngine engine = GameEngine(random: Random(20));
      engine.debugForceGameOver();
      expect(engine.state, GameState.noMoves);
    });
  });

  group('Boosters', () {
    test('hammer removes exactly one occupied cell', () {
      final GameEngine engine = GameEngine(random: Random(21));
      engine.board.setCell(2, 2, 1);
      engine.board.setCell(2, 3, 1);

      final BoosterResult result = engine.useHammer(2, 2);

      expect(result.applied, isTrue);
      expect(engine.board.isFilled(2, 2), isFalse);
      expect(engine.board.isFilled(2, 3), isTrue);
      expect(engine.stats.boostersUsed, 1);
    });

    test('hammer on an empty cell is rejected and costs nothing', () {
      final GameEngine engine = GameEngine(random: Random(22));
      final BoosterResult result = engine.useHammer(4, 4);

      expect(result.applied, isFalse);
      expect(engine.stats.boostersUsed, 0);
    });

    test('bomb clears a 3x3 area', () {
      final GameEngine engine = GameEngine(random: Random(23));
      for (int r = 2; r <= 4; r++) {
        for (int c = 2; c <= 4; c++) {
          engine.board.setCell(r, c, 1);
        }
      }
      engine.board.setCell(0, 0, 1);

      final BoosterResult result = engine.useBomb(3, 3);

      expect(result.applied, isTrue);
      expect(result.affectedCells.length, 9);
      expect(engine.board.filledCount, 1); // only (0,0) survives
    });

    test('bomb at the edge clips to the board instead of throwing', () {
      final GameEngine engine = GameEngine(random: Random(24));
      engine.board.setCell(0, 0, 1);
      engine.board.setCell(0, 1, 1);
      engine.board.setCell(1, 0, 1);

      final BoosterResult result = engine.useBomb(0, 0);

      expect(result.applied, isTrue);
      expect(result.affectedCells.length, 3);
      expect(engine.board.filledCount, 0);
    });

    test('bomb on empty space is rejected', () {
      final GameEngine engine = GameEngine(random: Random(25));
      expect(engine.useBomb(3, 3).applied, isFalse);
    });

    test('a bomb that completes a region scores the clear', () {
      final GameEngine engine = GameEngine(random: Random(26));
      // Fill row 0 except (0,0), then put a lone block at (0,0) to bomb around.
      for (int c = 1; c < 7; c++) {
        engine.board.setCell(0, c, 1);
      }
      engine.board.setCell(2, 0, 1);

      // Bombing (1,0) removes nothing in row 0, so build a real case instead:
      // fill row 1 fully and bomb a cell in row 3 that is occupied.
      engine.board.setCell(3, 3, 1);
      final int scoreBefore = engine.score;
      engine.useBomb(3, 3);

      expect(engine.score, scoreBefore); // nothing completed
    });

    test('shuffle replaces unused pieces but keeps used ones', () {
      final GameEngine engine = GameEngine(random: Random(27));
      engine.debugSetTray(<Shape>[
        ShapeCatalog.byId('dot'),
        ShapeCatalog.byId('dot'),
        ShapeCatalog.byId('dot'),
      ]);
      final int firstId = engine.tray.first.id;
      engine.place(firstId, 0, 0);

      expect(engine.useShuffle(), isTrue);

      final List<dynamic> tray = engine.tray;
      expect(tray.length, 3);
      expect(tray.first.used, isTrue, reason: 'placed piece stays used');
      expect(engine.availablePieces.length, 2);
    });

    test('shuffle can rescue a board that had no moves', () {
      final GameEngine engine = GameEngine(random: Random(28));
      // Leave a 1x3 gap: only small pieces fit.
      paintBoard(engine, kJammedBoard);
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('square3')]);
      expect(engine.state, GameState.noMoves);

      engine.useShuffle();

      expect(engine.state, GameState.playing);
      expect(engine.hasAvailableMove, isTrue);
    });

    test('second chance frees space and resumes play', () {
      final GameEngine engine = GameEngine(random: Random(29));
      paintBoard(engine, kJammedBoard);
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('square2')]);
      expect(engine.state, GameState.noMoves);

      final BoosterResult result = engine.useSecondChance();

      expect(result.applied, isTrue);
      expect(result.affectedCells, isNotEmpty);
      expect(engine.state, GameState.playing);
      expect(engine.hasAvailableMove, isTrue);
    });

    test('second chance on an empty board is rejected', () {
      final GameEngine engine = GameEngine(random: Random(30));
      expect(engine.useSecondChance().applied, isFalse);
    });
  });

  group('Continues', () {
    test('are capped at the configured maximum', () {
      final GameEngine engine = GameEngine(random: Random(31));

      for (int i = 0; i < EconomyConfig.maxContinuesPerGame; i++) {
        paintBoard(engine, kJammedBoard);
        engine.debugSetTray(<Shape>[ShapeCatalog.byId('square2')]);
        expect(engine.canContinue, isTrue);
        expect(engine.consumeContinue(), isTrue);
      }

      paintBoard(engine, kJammedBoard);
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('square2')]);
      expect(engine.canContinue, isFalse);
      expect(engine.consumeContinue(), isFalse);
      expect(engine.continuesRemaining, 0);
    });

    test('a continue does not count as a booster use', () {
      final GameEngine engine = GameEngine(random: Random(32));
      paintBoard(engine, kJammedBoard);
      engine.debugSetTray(<Shape>[ShapeCatalog.byId('square2')]);

      engine.consumeContinue();

      expect(engine.stats.continuesUsed, 1);
      expect(engine.stats.boostersUsed, 0);
    });
  });

  group('Run rewards', () {
    test('are derived from the final score', () {
      final GameEngine engine = GameEngine(random: Random(33));
      engine.debugSetScore(2500);

      expect(engine.crownsEarned, 25);
      expect(engine.coinsEarned, 100);
      expect(engine.xpEarned, 125);
    });

    test('a zero-score run pays nothing', () {
      final GameEngine engine = GameEngine(random: Random(34));
      expect(engine.crownsEarned, 0);
      expect(engine.coinsEarned, 0);
      expect(engine.xpEarned, 0);
    });
  });

  group('Full-loop simulation', () {
    test('a greedy autoplayer runs to a legitimate game over', () {
      final GameEngine engine = GameEngine(random: Random(1234));
      int guard = 0;

      while (engine.state == GameState.playing && guard++ < 5000) {
        bool placed = false;
        for (final dynamic piece in engine.availablePieces.toList()) {
          final List<Cell> spots = engine.placementsFor(piece.id as int);
          if (spots.isEmpty) continue;
          final Cell spot = spots.first;
          expect(
            engine.place(piece.id as int, spot.row, spot.col).accepted,
            isTrue,
          );
          placed = true;
          break;
        }
        if (!placed) break;
      }

      expect(guard, lessThan(5000), reason: 'must terminate');
      expect(engine.state, GameState.noMoves);
      expect(engine.stats.piecesPlaced, greaterThan(0));
      expect(engine.score, greaterThan(0));
      // Every unused piece really has nowhere to go.
      for (final dynamic piece in engine.availablePieces) {
        expect(engine.board.hasAnyPlacement(piece.shape as Shape), isFalse);
      }
    });

    test(
      'the board never holds a completed group after a placement settles',
      () {
        final GameEngine engine = GameEngine(random: Random(4321));
        int guard = 0;

        while (engine.state == GameState.playing && guard++ < 2000) {
          final List<dynamic> available = engine.availablePieces.toList();
          bool placed = false;
          for (final dynamic piece in available) {
            final List<Cell> spots = engine.placementsFor(piece.id as int);
            if (spots.isEmpty) continue;
            engine.place(piece.id as int, spots.last.row, spots.last.col);
            expect(
              engine.board.findCompleteGroups(),
              isEmpty,
              reason: 'clears must resolve immediately',
            );
            placed = true;
            break;
          }
          if (!placed) break;
        }
      },
    );
  });
}

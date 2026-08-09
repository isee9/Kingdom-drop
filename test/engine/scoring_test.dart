import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/core/config/economy_config.dart';
import 'package:kingdom_drop/game/engine/board.dart';
import 'package:kingdom_drop/game/engine/scoring.dart';
import 'package:kingdom_drop/game/engine/shape.dart';

/// Builds a throwaway group list of [count] entries, all of [type] unless
/// [mixed] is set, in which case the second one is a column.
List<ClearGroup> groups(int count, {ClearType type = ClearType.row, bool mixed = false}) {
  return <ClearGroup>[
    for (int i = 0; i < count; i++)
      ClearGroup(
        type: mixed && i == 1 ? ClearType.column : type,
        index: i,
        cells: const <Cell>[],
      ),
  ];
}

void main() {
  group('Base clear points', () {
    test('follow the configured ladder', () {
      expect(ScoreCalculator.basePointsForClears(1), 100);
      expect(ScoreCalculator.basePointsForClears(2), 300);
      expect(ScoreCalculator.basePointsForClears(3), 600);
      expect(ScoreCalculator.basePointsForClears(4), 1000);
    });

    test('zero clears score nothing', () {
      expect(ScoreCalculator.basePointsForClears(0), 0);
      expect(ScoreCalculator.basePointsForClears(-1), 0);
    });

    test('grow past the end of the table instead of falling off', () {
      final int last = EconomyConfig.clearPoints.last;
      final int n = EconomyConfig.clearPoints.length;

      expect(
        ScoreCalculator.basePointsForClears(n + 1),
        last + EconomyConfig.clearPointsOverflowStep,
      );
      expect(
        ScoreCalculator.basePointsForClears(n + 3),
        last + 3 * EconomyConfig.clearPointsOverflowStep,
      );
    });

    test('each additional simultaneous clear is worth more than the last', () {
      int previousStep = 0;
      for (int n = 2; n <= 6; n++) {
        final int step = ScoreCalculator.basePointsForClears(n) -
            ScoreCalculator.basePointsForClears(n - 1);
        expect(step, greaterThan(previousStep));
        previousStep = step;
      }
    });
  });

  group('Placement scoring', () {
    test('pays per block when nothing clears', () {
      final ScoreCalculator calc = ScoreCalculator();
      final ScoreBreakdown result = calc.scorePlacement(
        blocksPlaced: 4,
        groups: const <ClearGroup>[],
      );

      expect(result.placementPoints, 4 * EconomyConfig.pointsPerBlock);
      expect(result.total, 40);
      expect(result.didClear, isFalse);
      expect(result.comboDepth, 0);
    });

    test('bigger pieces are worth more to place', () {
      final ScoreCalculator calc = ScoreCalculator();
      final int small = calc
          .scorePlacement(blocksPlaced: 1, groups: const <ClearGroup>[])
          .total;
      final int big = calc
          .scorePlacement(blocksPlaced: 9, groups: const <ClearGroup>[])
          .total;
      expect(big, greaterThan(small));
    });

    test('adds clear points on top of placement points', () {
      final ScoreCalculator calc = ScoreCalculator();
      final ScoreBreakdown result = calc.scorePlacement(
        blocksPlaced: 3,
        groups: groups(1),
      );

      expect(result.placementPoints, 30);
      expect(result.clearPoints, 100);
      expect(result.comboMultiplier, 1.0);
      expect(result.total, 130);
    });

    test('pays the multi-axis bonus when a row and column clear together', () {
      final ScoreCalculator calc = ScoreCalculator();
      final ScoreBreakdown result = calc.scorePlacement(
        blocksPlaced: 1,
        groups: groups(2, mixed: true),
      );

      expect(result.multiAxisBonus, EconomyConfig.multiAxisBonus);
      expect(result.total, 10 + 300 + EconomyConfig.multiAxisBonus);
    });

    test('does not pay the multi-axis bonus for two rows', () {
      final ScoreCalculator calc = ScoreCalculator();
      final ScoreBreakdown result = calc.scorePlacement(
        blocksPlaced: 1,
        groups: groups(2),
      );

      expect(result.multiAxisBonus, 0);
      expect(result.total, 310);
    });
  });

  group('Combo ladder', () {
    test('climbs one step per consecutive clearing placement', () {
      final ScoreCalculator calc = ScoreCalculator();
      expect(calc.currentMultiplier, 1.0);

      calc.scorePlacement(blocksPlaced: 1, groups: groups(1));
      expect(calc.currentMultiplier, 1.25);

      calc.scorePlacement(blocksPlaced: 1, groups: groups(1));
      expect(calc.currentMultiplier, 1.5);

      calc.scorePlacement(blocksPlaced: 1, groups: groups(1));
      expect(calc.currentMultiplier, 2.0);
    });

    test('the second consecutive clear scores at 1.25x', () {
      final ScoreCalculator calc = ScoreCalculator();
      calc.scorePlacement(blocksPlaced: 1, groups: groups(1));

      final ScoreBreakdown second = calc.scorePlacement(
        blocksPlaced: 1,
        groups: groups(1),
      );

      expect(second.comboMultiplier, 1.25);
      expect(second.total, 10 + (100 * 1.25).round());
    });

    test('caps at the top of the ladder', () {
      final ScoreCalculator calc = ScoreCalculator();
      for (int i = 0; i < 20; i++) {
        calc.scorePlacement(blocksPlaced: 1, groups: groups(1));
      }
      expect(calc.currentMultiplier, EconomyConfig.comboMultipliers.last);
    });

    test('survives the grace window of non-clearing placements', () {
      final ScoreCalculator calc = ScoreCalculator();
      calc.scorePlacement(blocksPlaced: 1, groups: groups(1));
      expect(calc.currentMultiplier, 1.25);

      for (int i = 0; i < EconomyConfig.comboGracePlacements; i++) {
        calc.scorePlacement(blocksPlaced: 1, groups: const <ClearGroup>[]);
      }
      expect(
        calc.currentMultiplier,
        1.25,
        reason: 'combo should survive the grace placements',
      );
    });

    test('resets once the grace window is exceeded', () {
      final ScoreCalculator calc = ScoreCalculator();
      calc.scorePlacement(blocksPlaced: 1, groups: groups(1));
      calc.scorePlacement(blocksPlaced: 1, groups: groups(1));
      expect(calc.comboActive, isTrue);

      for (int i = 0; i <= EconomyConfig.comboGracePlacements; i++) {
        calc.scorePlacement(blocksPlaced: 1, groups: const <ClearGroup>[]);
      }

      expect(calc.comboActive, isFalse);
      expect(calc.currentMultiplier, 1.0);
    });

    test('reset() returns the ladder to the bottom', () {
      final ScoreCalculator calc = ScoreCalculator();
      calc.scorePlacement(blocksPlaced: 1, groups: groups(1));
      calc.reset();
      expect(calc.comboIndex, 0);
      expect(calc.comboActive, isFalse);
    });

    test('restore() rebuilds combo state within valid bounds', () {
      final ScoreCalculator calc = ScoreCalculator();
      calc.restore(comboIndex: 99, placementsSinceClear: -5);
      expect(calc.comboIndex, EconomyConfig.comboMultipliers.length - 1);
    });
  });

  group('End-of-run rewards', () {
    test('converts score to crowns at the configured rate', () {
      expect(RewardCalculator.crownsFor(score: 1000, bigCombos: 0), 10);
      expect(RewardCalculator.crownsFor(score: 999, bigCombos: 0), 9);
      expect(RewardCalculator.crownsFor(score: 0, bigCombos: 0), 0);
    });

    test('pays bonus crowns for deep combos', () {
      expect(
        RewardCalculator.crownsFor(score: 1000, bigCombos: 4),
        10 + 4 * EconomyConfig.crownsPerBigCombo,
      );
    });

    test('caps crowns per run', () {
      expect(
        RewardCalculator.crownsFor(score: 10000000, bigCombos: 500),
        EconomyConfig.maxCrownsPerGame,
      );
    });

    test('converts score to coins and caps them', () {
      expect(RewardCalculator.coinsFor(score: 1000), 40);
      expect(
        RewardCalculator.coinsFor(score: 10000000),
        EconomyConfig.maxCoinsPerGame,
      );
    });

    test('converts score to XP', () {
      expect(RewardCalculator.xpFor(score: 1000), 50);
    });
  });
}

import 'dart:math' as math;

import '../../core/config/economy_config.dart';
import 'board.dart';

/// Score breakdown for a single placement. Kept as data so the HUD can show
/// each component floating away separately.
class ScoreBreakdown {
  const ScoreBreakdown({
    required this.placementPoints,
    required this.clearPoints,
    required this.multiAxisBonus,
    required this.comboMultiplier,
    required this.comboDepth,
    required this.total,
  });

  static const ScoreBreakdown zero = ScoreBreakdown(
    placementPoints: 0,
    clearPoints: 0,
    multiAxisBonus: 0,
    comboMultiplier: 1,
    comboDepth: 0,
    total: 0,
  );

  /// Points for the blocks themselves.
  final int placementPoints;

  /// Base points for the groups cleared, before the multiplier.
  final int clearPoints;

  /// Bonus for clearing in more than one direction at once.
  final int multiAxisBonus;

  /// Multiplier applied to clear points and the multi-axis bonus.
  final double comboMultiplier;

  /// Combo depth this placement scored at (0 when nothing cleared).
  final int comboDepth;

  /// Everything added together, already rounded.
  final int total;

  bool get didClear => clearPoints > 0;
}

/// Tracks combo state across a run and turns placements into points.
///
/// Pure and independently testable: it never touches the board, only counts.
class ScoreCalculator {
  /// How many consecutive clearing placements have happened. Index into the
  /// multiplier ladder for the *next* clear.
  int _comboIndex = 0;

  /// Placements since the last clear.
  int _placementsSinceClear = 0;

  int get comboIndex => _comboIndex;

  /// Multiplier the next clear would score at.
  double get currentMultiplier =>
      EconomyConfig.comboMultipliers[_comboIndex.clamp(
        0,
        EconomyConfig.comboMultipliers.length - 1,
      )];

  /// True once the player is on a streak worth showing in the HUD.
  bool get comboActive => _comboIndex > 0;

  void reset() {
    _comboIndex = 0;
    _placementsSinceClear = 0;
  }

  /// Base points for clearing [lineCount] groups at once.
  static int basePointsForClears(int lineCount) {
    if (lineCount <= 0) return 0;
    final List<int> table = EconomyConfig.clearPoints;
    if (lineCount <= table.length) return table[lineCount - 1];
    final int overflow = lineCount - table.length;
    return table.last + overflow * EconomyConfig.clearPointsOverflowStep;
  }

  /// True when [groups] span more than one kind of clear, which is the
  /// "clever placement" case the bonus rewards.
  static bool spansMultipleAxes(List<ClearGroup> groups) {
    if (groups.length < 2) return false;
    final Set<ClearType> types = <ClearType>{
      for (final ClearGroup g in groups) g.type,
    };
    return types.length > 1;
  }

  /// Scores one placement and advances combo state.
  ///
  /// [blocksPlaced] is the cell count of the shape; [groups] is whatever the
  /// board reported as complete after writing the shape.
  ScoreBreakdown scorePlacement({
    required int blocksPlaced,
    required List<ClearGroup> groups,
  }) {
    final int placementPoints = blocksPlaced * EconomyConfig.pointsPerBlock;

    if (groups.isEmpty) {
      _placementsSinceClear++;
      if (_placementsSinceClear > EconomyConfig.comboGracePlacements) {
        _comboIndex = 0;
        _placementsSinceClear = 0;
      }
      return ScoreBreakdown(
        placementPoints: placementPoints,
        clearPoints: 0,
        multiAxisBonus: 0,
        comboMultiplier: 1,
        comboDepth: 0,
        total: placementPoints,
      );
    }

    final double multiplier = currentMultiplier;
    final int base = basePointsForClears(groups.length);
    final int bonus = spansMultipleAxes(groups)
        ? EconomyConfig.multiAxisBonus
        : 0;
    final int multiplied = ((base + bonus) * multiplier).round();

    _comboIndex = math.min(
      _comboIndex + 1,
      EconomyConfig.comboMultipliers.length - 1,
    );
    _placementsSinceClear = 0;

    return ScoreBreakdown(
      placementPoints: placementPoints,
      clearPoints: base,
      multiAxisBonus: bonus,
      comboMultiplier: multiplier,
      comboDepth: _comboIndex,
      total: placementPoints + multiplied,
    );
  }

  /// Restores combo state after a load or a continue.
  void restore({required int comboIndex, required int placementsSinceClear}) {
    _comboIndex = comboIndex.clamp(
      0,
      EconomyConfig.comboMultipliers.length - 1,
    );
    _placementsSinceClear = math.max(0, placementsSinceClear);
  }
}

/// Converts an end-of-run score into meta-currency.
abstract final class RewardCalculator {
  static int crownsFor({required int score, required int bigCombos}) {
    final int fromScore = score ~/ EconomyConfig.pointsPerCrown;
    final int fromCombos = bigCombos * EconomyConfig.crownsPerBigCombo;
    return math.min(fromScore + fromCombos, EconomyConfig.maxCrownsPerGame);
  }

  static int coinsFor({required int score}) {
    return math.min(
      score ~/ EconomyConfig.pointsPerCoin,
      EconomyConfig.maxCoinsPerGame,
    );
  }

  static int xpFor({required int score}) => score ~/ EconomyConfig.pointsPerXp;
}

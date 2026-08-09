import '../../models/booster.dart';

/// ============================================================================
/// ECONOMY CONFIGURATION — every tunable number in one place
/// ============================================================================
///
/// Balance the game by editing this file. No gameplay or UI code should contain
/// a literal reward, price or rate; if you find one, move it here.
abstract final class EconomyConfig {
  // ------------------------------------------------------------- scoring
  /// Awarded per individual cell of a placed shape, so bigger pieces are worth
  /// more to place.
  static const int pointsPerBlock = 10;

  /// Points for simultaneous clears, indexed by (lines - 1). A "line" is any
  /// completed row, column or 3x3 region.
  static const List<int> clearPoints = <int>[100, 300, 600, 1000, 1500, 2100];

  /// Each clear beyond [clearPoints] adds this much on top of the last entry.
  static const int clearPointsOverflowStep = 700;

  /// Combo multiplier ladder. Index = current combo depth, capped at the end.
  static const List<double> comboMultipliers = <double>[
    1.0,
    1.25,
    1.5,
    2.0,
    2.5,
    3.0,
  ];

  /// Placements allowed without a clear before the combo resets. Two gives the
  /// player room to set up a bigger clear without punishing a single filler
  /// piece.
  static const int comboGracePlacements = 2;

  /// Bonus points for a placement that clears in more than one axis at once
  /// (for example a row and a column together).
  static const int multiAxisBonus = 150;

  // -------------------------------------------------------------- crowns
  /// Game points needed per crown earned at the end of a run.
  static const int pointsPerCrown = 100;

  /// Extra crowns granted per combo of depth 3 or more reached during a run.
  static const int crownsPerBigCombo = 1;

  /// Cap on the crowns a single run can pay out, so a very long session cannot
  /// trivialise kingdom progression.
  static const int maxCrownsPerGame = 250;

  // ---------------------------------------------------------------- coins
  /// Coins earned per game, scaled from score.
  static const int pointsPerCoin = 25;
  static const int maxCoinsPerGame = 600;

  // ------------------------------------------------------------------- XP
  static const int pointsPerXp = 20;

  /// XP required to reach level N is `xpBase * N^xpCurveExponent`, rounded.
  static const int xpBase = 120;
  static const double xpCurveExponent = 1.35;

  /// Every level-up pays this, plus a crown bonus on milestone levels.
  static const int levelUpCoins = 250;
  static const int levelUpCrowns = 10;

  /// Levels that additionally grant a booster.
  static const int boosterRewardLevelInterval = 3;

  // ------------------------------------------------------------ continues
  static const int continueCostCoins = 500;

  /// Continues allowed per run, counting both paid and ad-funded ones.
  static const int maxContinuesPerGame = 2;

  /// Cells a "second chance" clears, taken from the most crowded rows.
  static const int secondChanceCellsCleared = 18;

  // ------------------------------------------------------------- boosters
  static const Map<BoosterType, int> boosterCoinCost = <BoosterType, int>{
    BoosterType.hammer: 150,
    BoosterType.bomb: 250,
    BoosterType.shuffle: 200,
    BoosterType.secondChance: 500,
  };

  /// What a brand-new player starts with.
  static const Map<BoosterType, int> startingBoosters = <BoosterType, int>{
    BoosterType.hammer: 3,
    BoosterType.bomb: 2,
    BoosterType.shuffle: 3,
    BoosterType.secondChance: 1,
  };

  // ---------------------------------------------------------------- coins
  /// Store coin packs. Prices are display strings for mock mode only; in a real
  /// build the store returns localised prices and these are ignored.
  static const Map<String, int> coinPackAmounts = <String, int>{
    'coins_500': 500,
    'coins_1200': 1200,
    'coins_3000': 3000,
    'coins_8000': 8000,
    'coins_25000': 25000,
  };

  // --------------------------------------------------------- starter pack
  static const int starterPackCoins = 1500;
  static const Map<BoosterType, int> starterPackBoosters = <BoosterType, int>{
    BoosterType.hammer: 5,
    BoosterType.bomb: 5,
    BoosterType.secondChance: 3,
  };

  /// The starter offer is genuinely time-limited from the player's first open —
  /// there is no fake resetting timer. Once this elapses the offer disappears.
  static const Duration starterPackWindow = Duration(hours: 24);

  // --------------------------------------------------------- daily reward
  /// Seven-day streak. Cycles back to day 1 after day 7.
  static const List<DailyRewardConfig> dailyRewards = <DailyRewardConfig>[
    DailyRewardConfig(day: 1, coins: 100),
    DailyRewardConfig(day: 2, coins: 150),
    DailyRewardConfig(day: 3, booster: BoosterType.hammer, boosterCount: 1),
    DailyRewardConfig(day: 4, coins: 250),
    DailyRewardConfig(day: 5, booster: BoosterType.bomb, boosterCount: 1),
    DailyRewardConfig(day: 6, coins: 400),
    DailyRewardConfig(day: 7, coins: 250, crowns: 25, chest: true),
  ];

  /// Missing a day resets the streak to 1 rather than breaking it entirely.
  static const int dailyStreakLength = 7;

  // ------------------------------------------------------ daily challenge
  static const int challengeRewardCoins = 300;
  static const int challengeRewardCrowns = 15;

  // --------------------------------------------------------------- chests
  static const Map<String, ChestConfig> chests = <String, ChestConfig>{
    'common': ChestConfig(
      minCoins: 100,
      maxCoins: 300,
      minCrowns: 0,
      maxCrowns: 5,
      boosterCount: 1,
    ),
    'rare': ChestConfig(
      minCoins: 400,
      maxCoins: 900,
      minCrowns: 10,
      maxCrowns: 25,
      boosterCount: 2,
    ),
    'kingdom': ChestConfig(
      minCoins: 1000,
      maxCoins: 2000,
      minCrowns: 40,
      maxCrowns: 80,
      boosterCount: 3,
    ),
  };
}

/// One day of the daily-reward streak.
class DailyRewardConfig {
  const DailyRewardConfig({
    required this.day,
    this.coins = 0,
    this.crowns = 0,
    this.booster,
    this.boosterCount = 0,
    this.chest = false,
  });

  final int day;
  final int coins;
  final int crowns;
  final BoosterType? booster;
  final int boosterCount;
  final bool chest;
}

/// Reward band for a chest tier.
class ChestConfig {
  const ChestConfig({
    required this.minCoins,
    required this.maxCoins,
    required this.minCrowns,
    required this.maxCrowns,
    required this.boosterCount,
  });

  final int minCoins;
  final int maxCoins;
  final int minCrowns;
  final int maxCrowns;
  final int boosterCount;
}

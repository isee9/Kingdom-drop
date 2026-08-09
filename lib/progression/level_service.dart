import 'dart:math' as math;

import '../core/config/economy_config.dart';
import '../models/booster.dart';

/// What a level-up hands the player.
class LevelUpReward {
  const LevelUpReward({
    required this.level,
    required this.coins,
    required this.crowns,
    this.booster,
  });

  final int level;
  final int coins;
  final int crowns;
  final BoosterType? booster;
}

/// The XP curve. Pure functions so the curve can be reasoned about and tested
/// without touching player state.
abstract final class LevelService {
  /// XP needed to go from [level] to [level] + 1.
  ///
  /// `xpBase * level ^ exponent`, so early levels arrive quickly and later ones
  /// stretch out. At the shipped values that is 120 XP for level 2 and roughly
  /// 2,700 for level 21.
  static int xpForNextLevel(int level) {
    final int safe = math.max(1, level);
    return (EconomyConfig.xpBase *
            math.pow(safe, EconomyConfig.xpCurveExponent))
        .round();
  }

  /// Total XP a player has poured in to reach [level] with [xpIntoLevel] spare.
  static int lifetimeXp(int level, int xpIntoLevel) {
    int total = xpIntoLevel;
    for (int l = 1; l < level; l++) {
      total += xpForNextLevel(l);
    }
    return total;
  }

  /// Fraction of the way through the current level, 0..1.
  static double progress(int level, int xpIntoLevel) {
    final int needed = xpForNextLevel(level);
    if (needed <= 0) return 0;
    return (xpIntoLevel / needed).clamp(0.0, 1.0);
  }

  /// The reward for arriving at [level].
  ///
  /// Every level pays coins and crowns; every third also pays a booster, cycled
  /// so the player accumulates a spread rather than a pile of one kind.
  static LevelUpReward rewardForLevel(int level) {
    BoosterType? booster;
    if (level % EconomyConfig.boosterRewardLevelInterval == 0) {
      const List<BoosterType> cycle = <BoosterType>[
        BoosterType.hammer,
        BoosterType.shuffle,
        BoosterType.bomb,
        BoosterType.secondChance,
      ];
      booster =
          cycle[(level ~/ EconomyConfig.boosterRewardLevelInterval - 1) %
              cycle.length];
    }

    return LevelUpReward(
      level: level,
      coins: EconomyConfig.levelUpCoins,
      crowns: EconomyConfig.levelUpCrowns,
      booster: booster,
    );
  }
}

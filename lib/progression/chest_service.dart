import 'dart:math';

import '../core/config/economy_config.dart';
import '../models/booster.dart';

enum ChestTier { common, rare, kingdom }

extension ChestTierInfo on ChestTier {
  String get configKey => switch (this) {
    ChestTier.common => 'common',
    ChestTier.rare => 'rare',
    ChestTier.kingdom => 'kingdom',
  };

  String get displayName => switch (this) {
    ChestTier.common => 'Common Chest',
    ChestTier.rare => 'Rare Chest',
    ChestTier.kingdom => 'Kingdom Chest',
  };
}

/// The contents of one opened chest.
class ChestReward {
  const ChestReward({
    required this.tier,
    required this.coins,
    required this.crowns,
    required this.boosters,
  });

  final ChestTier tier;
  final int coins;
  final int crowns;
  final Map<BoosterType, int> boosters;

  bool get isEmpty => coins == 0 && crowns == 0 && boosters.isEmpty;
}

/// Rolls chest contents from the bands in [EconomyConfig].
class ChestService {
  ChestService({Random? random}) : _random = random ?? Random();

  final Random _random;

  ChestReward open(ChestTier tier) {
    final ChestConfig config =
        EconomyConfig.chests[tier.configKey] ?? EconomyConfig.chests['common']!;

    final int coins = _between(config.minCoins, config.maxCoins);
    final int crowns = _between(config.minCrowns, config.maxCrowns);

    final Map<BoosterType, int> boosters = <BoosterType, int>{};
    for (int i = 0; i < config.boosterCount; i++) {
      final BoosterType type = _rollBooster();
      boosters[type] = (boosters[type] ?? 0) + 1;
    }

    return ChestReward(
      tier: tier,
      coins: coins,
      crowns: crowns,
      boosters: boosters,
    );
  }

  int _between(int min, int max) {
    if (max <= min) return min;
    // Round to a tidy multiple of 10 so rewards read cleanly.
    final int raw = min + _random.nextInt(max - min + 1);
    return raw >= 50 ? (raw / 10).round() * 10 : raw;
  }

  /// Second Chance is the most valuable booster, so it is the rarest drop.
  BoosterType _rollBooster() {
    const Map<BoosterType, int> weights = <BoosterType, int>{
      BoosterType.hammer: 35,
      BoosterType.shuffle: 30,
      BoosterType.bomb: 25,
      BoosterType.secondChance: 10,
    };

    final int total = weights.values.reduce((int a, int b) => a + b);
    int roll = _random.nextInt(total);
    for (final MapEntry<BoosterType, int> entry in weights.entries) {
      roll -= entry.value;
      if (roll < 0) return entry.key;
    }
    return BoosterType.hammer;
  }
}

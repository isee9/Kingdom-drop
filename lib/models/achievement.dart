/// What an achievement counts. Each maps to a counter the meta layer updates.
enum AchievementMetric {
  linesCleared,
  bestScore,
  gamesPlayed,
  piecesPlaced,
  kingdomsCompleted,
  kingdomUpgrades,
  bestCombo,
}

/// A static achievement definition. Progress lives separately in [AchievementProgress]
/// so the catalogue can grow without invalidating saves.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    this.rewardCoins = 0,
    this.rewardCrowns = 0,
  });

  final String id;
  final String title;
  final String description;
  final AchievementMetric metric;
  final int target;
  final int rewardCoins;
  final int rewardCrowns;
}

/// Saved state for one achievement.
class AchievementProgress {
  AchievementProgress({
    this.progress = 0,
    this.unlocked = false,
    this.claimed = false,
  });

  factory AchievementProgress.fromJson(Map<String, dynamic> json) =>
      AchievementProgress(
        progress: (json['p'] as num?)?.toInt() ?? 0,
        unlocked: json['u'] as bool? ?? false,
        claimed: json['c'] as bool? ?? false,
      );

  int progress;
  bool unlocked;

  /// Rewards are granted on unlock, so this exists to stop the "new!" badge
  /// reappearing once the player has seen it.
  bool claimed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'p': progress,
    'u': unlocked,
    'c': claimed,
  };
}

/// The shipped achievement list.
abstract final class AchievementCatalog {
  static const List<Achievement> all = <Achievement>[
    Achievement(
      id: 'first_clear',
      title: 'First Clear',
      description: 'Clear your first line.',
      metric: AchievementMetric.linesCleared,
      target: 1,
      rewardCoins: 100,
    ),
    Achievement(
      id: 'lines_100',
      title: 'Line Breaker',
      description: 'Clear 100 lines in total.',
      metric: AchievementMetric.linesCleared,
      target: 100,
      rewardCoins: 500,
      rewardCrowns: 10,
    ),
    Achievement(
      id: 'combo_king',
      title: 'Combo King',
      description: 'Reach a x3 combo.',
      metric: AchievementMetric.bestCombo,
      target: 5,
      rewardCoins: 400,
      rewardCrowns: 10,
    ),
    Achievement(
      id: 'score_5000',
      title: 'Rising Star',
      description: 'Score 5,000 in a single run.',
      metric: AchievementMetric.bestScore,
      target: 5000,
      rewardCoins: 300,
    ),
    Achievement(
      id: 'score_10000',
      title: 'Master Builder',
      description: 'Score 10,000 in a single run.',
      metric: AchievementMetric.bestScore,
      target: 10000,
      rewardCoins: 600,
      rewardCrowns: 15,
    ),
    Achievement(
      id: 'score_25000',
      title: 'Legend of the Drop',
      description: 'Score 25,000 in a single run.',
      metric: AchievementMetric.bestScore,
      target: 25000,
      rewardCoins: 1500,
      rewardCrowns: 40,
    ),
    Achievement(
      id: 'kingdom_builder',
      title: 'Kingdom Builder',
      description: 'Complete 10 kingdom upgrades.',
      metric: AchievementMetric.kingdomUpgrades,
      target: 10,
      rewardCoins: 500,
      rewardCrowns: 10,
    ),
    Achievement(
      id: 'first_kingdom',
      title: 'Crowned',
      description: 'Restore your first kingdom completely.',
      metric: AchievementMetric.kingdomsCompleted,
      target: 1,
      rewardCoins: 1000,
      rewardCrowns: 25,
    ),
    Achievement(
      id: 'games_100',
      title: 'Regular',
      description: 'Play 100 games.',
      metric: AchievementMetric.gamesPlayed,
      target: 100,
      rewardCoins: 750,
      rewardCrowns: 15,
    ),
    Achievement(
      id: 'pieces_1000',
      title: 'Thousand Blocks',
      description: 'Place 1,000 pieces.',
      metric: AchievementMetric.piecesPlaced,
      target: 1000,
      rewardCoins: 800,
      rewardCrowns: 20,
    ),
  ];

  static Achievement? byId(String id) {
    for (final Achievement a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}

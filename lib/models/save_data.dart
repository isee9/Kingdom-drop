import '../core/config/economy_config.dart';
import '../core/config/kingdom_config.dart';
import 'achievement.dart';
import 'booster.dart';
import 'daily_state.dart';

/// Toggles from the settings screen.
class GameSettings {
  GameSettings({
    this.musicEnabled = true,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
    musicEnabled: json['music'] as bool? ?? true,
    soundEnabled: json['sound'] as bool? ?? true,
    hapticsEnabled: json['haptics'] as bool? ?? true,
  );

  bool musicEnabled;
  bool soundEnabled;
  bool hapticsEnabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'music': musicEnabled,
    'sound': soundEnabled,
    'haptics': hapticsEnabled,
  };
}

/// Lifetime counters, used by achievements and the profile screen.
class PlayerStats {
  PlayerStats({
    this.gamesPlayed = 0,
    this.piecesPlaced = 0,
    this.linesCleared = 0,
    this.totalScore = 0,
    this.bestCombo = 0,
    this.kingdomsCompleted = 0,
    this.kingdomUpgradesBought = 0,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
    gamesPlayed: (json['games'] as num?)?.toInt() ?? 0,
    piecesPlaced: (json['pieces'] as num?)?.toInt() ?? 0,
    linesCleared: (json['lines'] as num?)?.toInt() ?? 0,
    totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
    bestCombo: (json['bestCombo'] as num?)?.toInt() ?? 0,
    kingdomsCompleted: (json['kingdomsDone'] as num?)?.toInt() ?? 0,
    kingdomUpgradesBought: (json['upgrades'] as num?)?.toInt() ?? 0,
  );

  int gamesPlayed;
  int piecesPlaced;
  int linesCleared;
  int totalScore;
  int bestCombo;
  int kingdomsCompleted;
  int kingdomUpgradesBought;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'games': gamesPlayed,
    'pieces': piecesPlaced,
    'lines': linesCleared,
    'totalScore': totalScore,
    'bestCombo': bestCombo,
    'kingdomsDone': kingdomsCompleted,
    'upgrades': kingdomUpgradesBought,
  };
}

/// How far the player has rebuilt each kingdom.
class KingdomProgress {
  KingdomProgress({this.currentIndex = 0, Map<String, int>? completedUpgrades})
    : completedUpgrades = completedUpgrades ?? <String, int>{};

  factory KingdomProgress.fromJson(Map<String, dynamic> json) =>
      KingdomProgress(
        currentIndex: (json['current'] as num?)?.toInt() ?? 0,
        completedUpgrades: <String, int>{
          for (final MapEntry<String, dynamic> e
              in (json['upgrades'] as Map<String, dynamic>? ??
                      <String, dynamic>{})
                  .entries)
            e.key: (e.value as num).toInt(),
        },
      );

  /// Index into [KingdomConfig.kingdoms] of the kingdom being worked on.
  int currentIndex;

  /// Kingdom id to number of upgrades bought. Keyed by id rather than index so
  /// reordering the config never corrupts a save.
  final Map<String, int> completedUpgrades;

  int upgradesFor(String kingdomId) => completedUpgrades[kingdomId] ?? 0;

  bool isComplete(KingdomDefinition kingdom) =>
      upgradesFor(kingdom.id) >= kingdom.upgradeCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'current': currentIndex,
    'upgrades': completedUpgrades,
  };
}

/// The entire persisted player profile.
///
/// Everything lives in one JSON document written under a single key, so a save
/// is atomic: the app can never come back up with, say, crowns spent but the
/// upgrade not recorded.
class SaveData {
  SaveData({
    required this.installedAt,
    this.schemaVersion = currentSchemaVersion,
    this.bestScore = 0,
    this.coins = 0,
    this.crowns = 0,
    this.xp = 0,
    this.level = 1,
    KingdomProgress? kingdom,
    Map<BoosterType, int>? boosters,
    PlayerStats? stats,
    Map<String, AchievementProgress>? achievements,
    DailyRewardState? dailyReward,
    DailyChallengeState? dailyChallenge,
    Set<String>? ownedProducts,
    this.adsRemoved = false,
    this.tutorialCompleted = false,
    this.introSeen = false,
    GameSettings? settings,
  }) : kingdom = kingdom ?? KingdomProgress(),
       boosters = boosters ?? <BoosterType, int>{},
       stats = stats ?? PlayerStats(),
       achievements = achievements ?? <String, AchievementProgress>{},
       dailyReward = dailyReward ?? DailyRewardState(),
       dailyChallenge = dailyChallenge ?? DailyChallengeState(),
       ownedProducts = ownedProducts ?? <String>{};

  /// A brand-new player: starting boosters, nothing else.
  factory SaveData.fresh({DateTime? now}) => SaveData(
    installedAt: now ?? DateTime.now(),
    coins: 0,
    boosters: Map<BoosterType, int>.of(EconomyConfig.startingBoosters),
  );

  factory SaveData.fromJson(Map<String, dynamic> json) {
    return SaveData(
      schemaVersion: (json['v'] as num?)?.toInt() ?? 1,
      installedAt:
          DateTime.tryParse(json['installedAt'] as String? ?? '') ??
          DateTime.now(),
      bestScore: (json['bestScore'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      crowns: (json['crowns'] as num?)?.toInt() ?? 0,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      kingdom: KingdomProgress.fromJson(
        json['kingdom'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      boosters: <BoosterType, int>{
        for (final MapEntry<String, dynamic> e
            in (json['boosters'] as Map<String, dynamic>? ??
                    <String, dynamic>{})
                .entries)
          if (BoosterType.fromKey(e.key) case final BoosterType t)
            t: (e.value as num).toInt(),
      },
      stats: PlayerStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      achievements: <String, AchievementProgress>{
        for (final MapEntry<String, dynamic> e
            in (json['achievements'] as Map<String, dynamic>? ??
                    <String, dynamic>{})
                .entries)
          e.key: AchievementProgress.fromJson(e.value as Map<String, dynamic>),
      },
      dailyReward: DailyRewardState.fromJson(
        json['daily'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      dailyChallenge: DailyChallengeState.fromJson(
        json['challenge'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      ownedProducts: <String>{
        for (final dynamic p in json['products'] as List<dynamic>? ?? <dynamic>[])
          p as String,
      },
      adsRemoved: json['adsRemoved'] as bool? ?? false,
      tutorialCompleted: json['tutorial'] as bool? ?? false,
      introSeen: json['intro'] as bool? ?? false,
      settings: GameSettings.fromJson(
        json['settings'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }

  /// Bump this whenever the shape of the document changes, and add a step to
  /// [SaveMigrations].
  static const int currentSchemaVersion = 1;

  int schemaVersion;

  /// First app open. The starter-pack offer window is measured from this, which
  /// is why the offer is genuinely time-limited rather than a repeating fake.
  final DateTime installedAt;

  int bestScore;
  int coins;
  int crowns;
  int xp;
  int level;

  final KingdomProgress kingdom;
  final Map<BoosterType, int> boosters;
  final PlayerStats stats;
  final Map<String, AchievementProgress> achievements;
  final DailyRewardState dailyReward;
  final DailyChallengeState dailyChallenge;

  /// Non-consumable product ids the player owns.
  final Set<String> ownedProducts;

  bool adsRemoved;
  bool tutorialCompleted;
  bool introSeen;
  GameSettings settings = GameSettings();

  int boosterCount(BoosterType type) => boosters[type] ?? 0;

  AchievementProgress achievementProgress(String id) =>
      achievements.putIfAbsent(id, AchievementProgress.new);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': schemaVersion,
    'installedAt': installedAt.toIso8601String(),
    'bestScore': bestScore,
    'coins': coins,
    'crowns': crowns,
    'xp': xp,
    'level': level,
    'kingdom': kingdom.toJson(),
    'boosters': <String, int>{
      for (final MapEntry<BoosterType, int> e in boosters.entries)
        e.key.name: e.value,
    },
    'stats': stats.toJson(),
    'achievements': <String, dynamic>{
      for (final MapEntry<String, AchievementProgress> e
          in achievements.entries)
        e.key: e.value.toJson(),
    },
    'daily': dailyReward.toJson(),
    'challenge': dailyChallenge.toJson(),
    'products': ownedProducts.toList(),
    'adsRemoved': adsRemoved,
    'tutorial': tutorialCompleted,
    'intro': introSeen,
    'settings': settings.toJson(),
  };
}

/// Forward-only save migrations.
///
/// Each step upgrades the raw JSON by exactly one version. Running them in
/// sequence means a player who skips several app updates still lands on the
/// current schema without losing anything.
abstract final class SaveMigrations {
  /// Migration functions keyed by the version they upgrade *from*.
  static final Map<int, Map<String, dynamic> Function(Map<String, dynamic>)>
  steps = <int, Map<String, dynamic> Function(Map<String, dynamic>)>{
    // Example of the shape a future migration takes:
    //
    // 1: (Map<String, dynamic> json) {
    //   json['newField'] = defaultValue;
    //   json['v'] = 2;
    //   return json;
    // },
  };

  /// Walks [json] up to [SaveData.currentSchemaVersion].
  ///
  /// A save from a *newer* build (possible if the player downgrades) is left
  /// alone; [SaveData.fromJson] tolerates unknown keys and fills in defaults
  /// for anything missing, which is safer than refusing to load.
  static Map<String, dynamic> migrate(Map<String, dynamic> json) {
    Map<String, dynamic> current = json;
    int version = (current['v'] as num?)?.toInt() ?? 1;

    while (version < SaveData.currentSchemaVersion) {
      final Map<String, dynamic> Function(Map<String, dynamic>)? step =
          steps[version];
      if (step == null) {
        // No migration registered: stamp the version and let fromJson's
        // defaults cover any new fields.
        current['v'] = SaveData.currentSchemaVersion;
        break;
      }
      current = step(current);
      final int next = (current['v'] as num?)?.toInt() ?? version + 1;
      if (next <= version) break; // Defensive: never loop forever.
      version = next;
    }

    return current;
  }
}

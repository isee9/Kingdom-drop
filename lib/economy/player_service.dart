import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/config/economy_config.dart';
import '../core/config/kingdom_config.dart';
import '../models/achievement.dart';
import '../models/booster.dart';
import '../models/save_data.dart';
import '../progression/level_service.dart';
import '../services/analytics_service.dart';
import '../storage/storage_repository.dart';

/// Something worth showing the player after an action resolved.
sealed class PlayerEvent {
  const PlayerEvent();
}

class LevelUpEvent extends PlayerEvent {
  const LevelUpEvent(this.rewards);

  /// One entry per level gained; a huge run can cross several at once.
  final List<LevelUpReward> rewards;
}

class AchievementUnlockedEvent extends PlayerEvent {
  const AchievementUnlockedEvent(this.achievements);

  final List<Achievement> achievements;
}

/// Owns the player profile and is the only thing that mutates it.
///
/// Every screen listens to this one notifier, which keeps currency displays,
/// kingdom progress and booster counts consistent without a state-management
/// package. Mutations persist through the injected [StorageRepository]; the
/// repository is expected to debounce, so callers can save freely.
class PlayerService extends ChangeNotifier {
  PlayerService({
    required StorageRepository storage,
    required AnalyticsService analytics,
    SaveData? initial,
  }) : _storage = storage,
       _analytics = analytics,
       _data = initial ?? SaveData.fresh();

  final StorageRepository _storage;
  final AnalyticsService _analytics;

  SaveData _data;

  /// Events raised by the last mutation, drained by the UI to show popups.
  final List<PlayerEvent> _pendingEvents = <PlayerEvent>[];

  /// Loads from storage, falling back to a fresh profile on a first run or an
  /// unreadable save.
  static Future<PlayerService> load({
    required StorageRepository storage,
    required AnalyticsService analytics,
  }) async {
    final SaveData? existing = await storage.load();
    final PlayerService service = PlayerService(
      storage: storage,
      analytics: analytics,
      initial: existing ?? SaveData.fresh(),
    );
    if (existing == null) {
      // Persist immediately so installedAt is pinned to the real first open,
      // which is what the starter-pack window is measured against.
      await storage.save(service._data);
    }
    return service;
  }

  // ------------------------------------------------------------------ reads
  SaveData get data => _data;

  int get coins => _data.coins;
  int get crowns => _data.crowns;
  int get level => _data.level;
  int get xp => _data.xp;
  int get bestScore => _data.bestScore;
  bool get adsRemoved => _data.adsRemoved;
  bool get tutorialCompleted => _data.tutorialCompleted;
  bool get introSeen => _data.introSeen;
  GameSettings get settings => _data.settings;
  PlayerStats get stats => _data.stats;
  KingdomProgress get kingdomProgress => _data.kingdom;

  int get xpForNextLevel => LevelService.xpForNextLevel(_data.level);
  double get levelProgress => LevelService.progress(_data.level, _data.xp);

  int boosterCount(BoosterType type) => _data.boosterCount(type);

  bool ownsProduct(String productId) => _data.ownedProducts.contains(productId);

  /// True while the genuine 24-hour starter window is still open and the pack
  /// has not been bought. There is no fake resetting timer anywhere.
  bool starterPackAvailable({DateTime? now}) {
    if (ownsProduct('starter_pack')) return false;
    final Duration elapsed = (now ?? DateTime.now()).difference(
      _data.installedAt,
    );
    return elapsed < EconomyConfig.starterPackWindow;
  }

  Duration starterPackRemaining({DateTime? now}) {
    final Duration elapsed = (now ?? DateTime.now()).difference(
      _data.installedAt,
    );
    final Duration left = EconomyConfig.starterPackWindow - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Drains queued events. The caller is responsible for presenting them.
  List<PlayerEvent> takeEvents() {
    if (_pendingEvents.isEmpty) return const <PlayerEvent>[];
    final List<PlayerEvent> events = List<PlayerEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    return events;
  }

  // --------------------------------------------------------------- currency
  void addCoins(int amount) {
    if (amount <= 0) return;
    _data.coins += amount;
    _commit();
  }

  /// Deducts [amount] if affordable. Returns false and changes nothing if not.
  bool spendCoins(int amount) {
    if (amount <= 0) return true;
    if (_data.coins < amount) return false;
    _data.coins -= amount;
    _commit();
    return true;
  }

  void addCrowns(int amount) {
    if (amount <= 0) return;
    _data.crowns += amount;
    _commit();
  }

  bool spendCrowns(int amount) {
    if (amount <= 0) return true;
    if (_data.crowns < amount) return false;
    _data.crowns -= amount;
    _commit();
    return true;
  }

  // --------------------------------------------------------------- boosters
  void grantBooster(BoosterType type, [int count = 1]) {
    if (count <= 0) return;
    _data.boosters[type] = _data.boosterCount(type) + count;
    _commit();
  }

  void grantBoosters(Map<BoosterType, int> boosters) {
    boosters.forEach((BoosterType type, int count) {
      if (count > 0) _data.boosters[type] = _data.boosterCount(type) + count;
    });
    _commit();
  }

  /// Uses one booster of [type]. False when the player has none.
  bool consumeBooster(BoosterType type) {
    final int have = _data.boosterCount(type);
    if (have <= 0) return false;
    _data.boosters[type] = have - 1;
    _commit();
    return true;
  }

  /// Buys one booster with coins.
  bool buyBooster(BoosterType type) {
    final int cost = EconomyConfig.boosterCoinCost[type] ?? 0;
    if (!spendCoins(cost)) return false;
    grantBooster(type);
    _analytics.log('booster_purchased', <String, Object?>{
      'booster': type.name,
      'cost': cost,
    });
    return true;
  }

  // --------------------------------------------------------------------- XP
  /// Adds XP and resolves any level-ups, queueing a [LevelUpEvent].
  void addXp(int amount) {
    if (amount <= 0) return;
    _data.xp += amount;

    final List<LevelUpReward> gained = <LevelUpReward>[];
    // Bounded so a corrupted XP value cannot spin forever.
    int guard = 0;
    while (_data.xp >= LevelService.xpForNextLevel(_data.level) &&
        guard++ < 500) {
      _data.xp -= LevelService.xpForNextLevel(_data.level);
      _data.level++;
      final LevelUpReward reward = LevelService.rewardForLevel(_data.level);
      gained.add(reward);

      _data.coins += reward.coins;
      _data.crowns += reward.crowns;
      if (reward.booster != null) {
        _data.boosters[reward.booster!] =
            _data.boosterCount(reward.booster!) + 1;
      }
      _analytics.log('level_up', <String, Object?>{'level': _data.level});
    }

    if (gained.isNotEmpty) _pendingEvents.add(LevelUpEvent(gained));
    _commit();
  }

  // ------------------------------------------------------------ run results
  /// Records a finished run: best score, lifetime stats and achievements.
  ///
  /// Currency is *not* granted here — the summary screen hands out crowns and
  /// coins after the player claims, optionally doubled by a rewarded ad.
  void recordGameFinished({
    required int score,
    required int linesCleared,
    required int piecesPlaced,
    required int bestComboDepth,
  }) {
    final PlayerStats s = _data.stats;
    s.gamesPlayed++;
    s.piecesPlaced += piecesPlaced;
    s.linesCleared += linesCleared;
    s.totalScore += score;
    if (bestComboDepth > s.bestCombo) s.bestCombo = bestComboDepth;
    if (score > _data.bestScore) _data.bestScore = score;

    _evaluateAchievements();
    _commit();
  }

  /// Applies the end-of-run payout.
  void grantRunRewards({required int crowns, required int coins, required int xp}) {
    if (crowns > 0) _data.crowns += crowns;
    if (coins > 0) _data.coins += coins;
    notifyListeners();
    addXp(xp); // commits
  }

  // --------------------------------------------------------------- kingdoms
  KingdomDefinition get currentKingdom =>
      KingdomConfig.byIndex(_data.kingdom.currentIndex);

  int get currentKingdomUpgradesDone =>
      _data.kingdom.upgradesFor(currentKingdom.id);

  /// The next upgrade to buy in the current kingdom, or null when it is done.
  KingdomUpgrade? get nextUpgrade {
    final KingdomDefinition kingdom = currentKingdom;
    final int done = _data.kingdom.upgradesFor(kingdom.id);
    if (done >= kingdom.upgradeCount) return null;
    return kingdom.upgrades[done];
  }

  bool get canAffordNextUpgrade {
    final KingdomUpgrade? next = nextUpgrade;
    return next != null && _data.crowns >= next.cost;
  }

  /// Spends crowns on the next upgrade.
  ///
  /// Returns the outcome so the UI knows whether to play the upgrade animation,
  /// the kingdom-complete celebration, or a "not enough crowns" nudge.
  UpgradeOutcome buyNextUpgrade() {
    final KingdomDefinition kingdom = currentKingdom;
    final KingdomUpgrade? next = nextUpgrade;
    if (next == null) return UpgradeOutcome.alreadyComplete;
    if (_data.crowns < next.cost) return UpgradeOutcome.notEnoughCrowns;

    _data.crowns -= next.cost;
    _data.kingdom.completedUpgrades[kingdom.id] =
        _data.kingdom.upgradesFor(kingdom.id) + 1;
    _data.stats.kingdomUpgradesBought++;

    _analytics.log('kingdom_upgrade', <String, Object?>{
      'kingdom': kingdom.id,
      'upgrade': next.index,
      'cost': next.cost,
    });

    final bool complete =
        _data.kingdom.upgradesFor(kingdom.id) >= kingdom.upgradeCount;
    if (complete) {
      _data.stats.kingdomsCompleted++;
      _analytics.log('kingdom_completed', <String, Object?>{
        'kingdom': kingdom.id,
      });
    }

    _evaluateAchievements();
    _commit();
    return complete ? UpgradeOutcome.kingdomComplete : UpgradeOutcome.bought;
  }

  /// Moves to the next kingdom after the completion celebration. Stops at the
  /// last one, which then stays as the player's finished realm.
  bool advanceToNextKingdom() {
    final int next = _data.kingdom.currentIndex + 1;
    if (next >= KingdomConfig.kingdomCount) return false;
    _data.kingdom.currentIndex = next;
    _commit();
    return true;
  }

  /// True once every kingdom in the config is fully restored.
  bool get allKingdomsComplete {
    for (final KingdomDefinition k in KingdomConfig.kingdoms) {
      if (_data.kingdom.upgradesFor(k.id) < k.upgradeCount) return false;
    }
    return true;
  }

  // ----------------------------------------------------------- achievements
  /// Recomputes every achievement against current counters and queues an event
  /// for any that just unlocked.
  void _evaluateAchievements() {
    final List<Achievement> unlocked = <Achievement>[];

    for (final Achievement achievement in AchievementCatalog.all) {
      final AchievementProgress progress = _data.achievementProgress(
        achievement.id,
      );
      final int value = _metricValue(achievement.metric);
      progress.progress = value;

      if (!progress.unlocked && value >= achievement.target) {
        progress.unlocked = true;
        _data.coins += achievement.rewardCoins;
        _data.crowns += achievement.rewardCrowns;
        unlocked.add(achievement);
        _analytics.log('achievement_unlocked', <String, Object?>{
          'id': achievement.id,
        });
      }
    }

    if (unlocked.isNotEmpty) {
      _pendingEvents.add(AchievementUnlockedEvent(unlocked));
    }
  }

  int _metricValue(AchievementMetric metric) => switch (metric) {
    AchievementMetric.linesCleared => _data.stats.linesCleared,
    AchievementMetric.bestScore => _data.bestScore,
    AchievementMetric.gamesPlayed => _data.stats.gamesPlayed,
    AchievementMetric.piecesPlaced => _data.stats.piecesPlaced,
    AchievementMetric.kingdomsCompleted => _data.stats.kingdomsCompleted,
    AchievementMetric.kingdomUpgrades => _data.stats.kingdomUpgradesBought,
    AchievementMetric.bestCombo => _data.stats.bestCombo,
  };

  /// Marks the "new" badge as seen.
  void markAchievementSeen(String id) {
    _data.achievementProgress(id).claimed = true;
    _commit();
  }

  int get unseenAchievementCount => _data.achievements.values
      .where((AchievementProgress p) => p.unlocked && !p.claimed)
      .length;

  // ------------------------------------------------------------- purchases
  void grantProduct(String productId) {
    _data.ownedProducts.add(productId);
    if (productId == 'remove_ads') _data.adsRemoved = true;
    _commit();
  }

  /// Re-applies non-consumables reported by the store during a restore.
  void restoreProducts(Iterable<String> productIds) {
    for (final String id in productIds) {
      _data.ownedProducts.add(id);
      if (id == 'remove_ads') _data.adsRemoved = true;
    }
    _commit();
  }

  // --------------------------------------------------------------- settings
  void setMusicEnabled(bool value) {
    _data.settings.musicEnabled = value;
    _commit();
  }

  void setSoundEnabled(bool value) {
    _data.settings.soundEnabled = value;
    _commit();
  }

  void setHapticsEnabled(bool value) {
    _data.settings.hapticsEnabled = value;
    _commit();
  }

  void markTutorialCompleted() {
    if (_data.tutorialCompleted) return;
    _data.tutorialCompleted = true;
    _analytics.log('tutorial_completed');
    _commit();
  }

  void markIntroSeen() {
    if (_data.introSeen) return;
    _data.introSeen = true;
    _commit();
  }

  // ------------------------------------------------------------------ admin
  /// Wipes everything back to a fresh install. Confirmed in the UI first.
  Future<void> resetProgress() async {
    await _storage.clear();
    _data = SaveData.fresh();
    _pendingEvents.clear();
    await _storage.save(_data);
    notifyListeners();
  }

  /// Forces an immediate write. Call when the app goes to the background.
  Future<void> flush() => _storage.save(_data).then((_) {});

  void _commit() {
    notifyListeners();
    unawaited(_storage.save(_data));
  }

  // ------------------------------------------------------------------ debug
  void debugAddCoins(int amount) {
    _data.coins = math.max(0, _data.coins + amount);
    _commit();
  }

  void debugAddCrowns(int amount) {
    _data.crowns = math.max(0, _data.crowns + amount);
    _commit();
  }

  void debugUnlockNextKingdom() {
    final KingdomDefinition kingdom = currentKingdom;
    _data.kingdom.completedUpgrades[kingdom.id] = kingdom.upgradeCount;
    _data.stats.kingdomsCompleted++;
    advanceToNextKingdom();
    _commit();
  }

  void debugSetBestScore(int score) {
    _data.bestScore = score;
    _commit();
  }
}

enum UpgradeOutcome { bought, kingdomComplete, notEnoughCrowns, alreadyComplete }

/// Local `unawaited` so this file does not need dart:async just for it.
void unawaited(Future<void> future) {
  future.catchError((Object error) {
    debugPrint('[player] background save failed: $error');
  });
}

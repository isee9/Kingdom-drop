import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/core/config/economy_config.dart';
import 'package:kingdom_drop/core/config/kingdom_config.dart';
import 'package:kingdom_drop/economy/player_service.dart';
import 'package:kingdom_drop/models/achievement.dart';
import 'package:kingdom_drop/models/booster.dart';
import 'package:kingdom_drop/models/save_data.dart';
import 'package:kingdom_drop/progression/level_service.dart';
import 'package:kingdom_drop/services/analytics_service.dart';
import 'package:kingdom_drop/storage/storage_repository.dart';

/// Builds a service backed by in-memory storage.
({PlayerService player, InMemoryStorage storage}) makePlayer({
  SaveData? initial,
}) {
  final InMemoryStorage storage = InMemoryStorage();
  final PlayerService player = PlayerService(
    storage: storage,
    analytics: const NoopAnalyticsService(),
    initial: initial ?? SaveData.fresh(),
  );
  return (player: player, storage: storage);
}

void main() {
  group('Coins', () {
    test('start at zero and can be added', () {
      final PlayerService player = makePlayer().player;
      expect(player.coins, 0);

      player.addCoins(250);
      expect(player.coins, 250);
    });

    test('ignore non-positive amounts', () {
      final PlayerService player = makePlayer().player;
      player
        ..addCoins(100)
        ..addCoins(0)
        ..addCoins(-50);
      expect(player.coins, 100);
    });

    test('spending succeeds when affordable and deducts exactly', () {
      final PlayerService player = makePlayer().player;
      player.addCoins(500);

      expect(player.spendCoins(300), isTrue);
      expect(player.coins, 200);
    });

    test('spending more than the balance changes nothing', () {
      final PlayerService player = makePlayer().player;
      player.addCoins(100);

      expect(player.spendCoins(101), isFalse);
      expect(player.coins, 100);
    });

    test('spending the exact balance is allowed', () {
      final PlayerService player = makePlayer().player;
      player.addCoins(150);

      expect(player.spendCoins(150), isTrue);
      expect(player.coins, 0);
    });
  });

  group('Crowns', () {
    test('accumulate and can be spent', () {
      final PlayerService player = makePlayer().player;
      player.addCrowns(60);

      expect(player.crowns, 60);
      expect(player.spendCrowns(25), isTrue);
      expect(player.crowns, 35);
      expect(player.spendCrowns(100), isFalse);
      expect(player.crowns, 35);
    });
  });

  group('Boosters', () {
    test('a new player gets the configured starting set', () {
      final PlayerService player = makePlayer().player;
      for (final MapEntry<BoosterType, int> e
          in EconomyConfig.startingBoosters.entries) {
        expect(player.boosterCount(e.key), e.value, reason: e.key.name);
      }
    });

    test('consuming reduces the count by one', () {
      final PlayerService player = makePlayer().player;
      final int before = player.boosterCount(BoosterType.hammer);

      expect(player.consumeBooster(BoosterType.hammer), isTrue);
      expect(player.boosterCount(BoosterType.hammer), before - 1);
    });

    test('consuming with none left fails and stays at zero', () {
      final PlayerService player = makePlayer().player;
      while (player.boosterCount(BoosterType.bomb) > 0) {
        player.consumeBooster(BoosterType.bomb);
      }

      expect(player.consumeBooster(BoosterType.bomb), isFalse);
      expect(player.boosterCount(BoosterType.bomb), 0);
    });

    test('buying spends coins and grants one booster', () {
      final PlayerService player = makePlayer().player;
      final int cost = EconomyConfig.boosterCoinCost[BoosterType.hammer]!;
      player.addCoins(cost);
      final int before = player.boosterCount(BoosterType.hammer);

      expect(player.buyBooster(BoosterType.hammer), isTrue);
      expect(player.coins, 0);
      expect(player.boosterCount(BoosterType.hammer), before + 1);
    });

    test('buying without enough coins changes nothing', () {
      final PlayerService player = makePlayer().player;
      final int before = player.boosterCount(BoosterType.secondChance);

      expect(player.buyBooster(BoosterType.secondChance), isFalse);
      expect(player.coins, 0);
      expect(player.boosterCount(BoosterType.secondChance), before);
    });
  });

  group('XP and levels', () {
    test('the curve grows with level', () {
      int previous = 0;
      for (int level = 1; level <= 20; level++) {
        final int needed = LevelService.xpForNextLevel(level);
        expect(needed, greaterThan(previous), reason: 'level $level');
        previous = needed;
      }
    });

    test('XP below the threshold does not level up', () {
      final PlayerService player = makePlayer().player;
      player.addXp(LevelService.xpForNextLevel(1) - 1);

      expect(player.level, 1);
      expect(player.levelProgress, lessThan(1));
    });

    test('crossing the threshold levels up and pays the reward', () {
      final PlayerService player = makePlayer().player;
      final int coinsBefore = player.coins;

      player.addXp(LevelService.xpForNextLevel(1));

      expect(player.level, 2);
      expect(player.coins, coinsBefore + EconomyConfig.levelUpCoins);
      expect(player.crowns, EconomyConfig.levelUpCrowns);
    });

    test('a huge XP grant crosses several levels at once', () {
      final PlayerService player = makePlayer().player;
      player.addXp(100000);

      expect(player.level, greaterThan(5));
      expect(player.xp, lessThan(LevelService.xpForNextLevel(player.level)));
    });

    test('level-ups are reported as an event', () {
      final PlayerService player = makePlayer().player;
      player.addXp(LevelService.xpForNextLevel(1));

      final List<PlayerEvent> events = player.takeEvents();
      final LevelUpEvent levelUp = events.whereType<LevelUpEvent>().single;

      expect(levelUp.rewards.single.level, 2);
      // Draining clears the queue.
      expect(player.takeEvents().whereType<LevelUpEvent>(), isEmpty);
    });

    test('every third level also grants a booster', () {
      expect(
        LevelService.rewardForLevel(
          EconomyConfig.boosterRewardLevelInterval,
        ).booster,
        isNotNull,
      );
      expect(LevelService.rewardForLevel(2).booster, isNull);
    });
  });

  group('Kingdom progression', () {
    test('a new player starts on the first kingdom with nothing built', () {
      final PlayerService player = makePlayer().player;

      expect(player.currentKingdom.id, 'forgotten_keep');
      expect(player.currentKingdomUpgradesDone, 0);
      expect(player.nextUpgrade!.name, 'Repair Castle Gate');
      expect(player.nextUpgrade!.cost, 25);
    });

    test('an unaffordable upgrade is refused and costs nothing', () {
      final PlayerService player = makePlayer().player;

      expect(player.buyNextUpgrade(), UpgradeOutcome.notEnoughCrowns);
      expect(player.currentKingdomUpgradesDone, 0);
      expect(player.crowns, 0);
    });

    test('buying deducts the cost and advances the ladder', () {
      final PlayerService player = makePlayer().player;
      player.addCrowns(100);

      expect(player.buyNextUpgrade(), UpgradeOutcome.bought);
      expect(player.crowns, 75);
      expect(player.currentKingdomUpgradesDone, 1);
      expect(player.nextUpgrade!.name, 'Repair Bridge');
    });

    test('the final upgrade reports kingdom completion', () {
      final PlayerService player = makePlayer().player;
      player.addCrowns(1000);

      final KingdomDefinition kingdom = player.currentKingdom;
      for (int i = 0; i < kingdom.upgradeCount - 1; i++) {
        expect(player.buyNextUpgrade(), UpgradeOutcome.bought);
      }

      expect(player.buyNextUpgrade(), UpgradeOutcome.kingdomComplete);
      expect(player.nextUpgrade, isNull);
      expect(player.buyNextUpgrade(), UpgradeOutcome.alreadyComplete);
      expect(player.data.stats.kingdomsCompleted, 1);
    });

    test('advancing moves to the next realm and stops at the last', () {
      final PlayerService player = makePlayer().player;

      for (int i = 0; i < KingdomConfig.kingdomCount - 1; i++) {
        expect(player.advanceToNextKingdom(), isTrue, reason: 'step $i');
      }
      expect(player.currentKingdom.id, 'star_kingdom');
      expect(player.advanceToNextKingdom(), isFalse);
    });

    test('progress is keyed by kingdom id, so it survives reordering', () {
      final PlayerService player = makePlayer().player;
      player.addCrowns(100);
      player.buyNextUpgrade();

      expect(player.data.kingdom.completedUpgrades['forgotten_keep'], 1);
    });

    test('costs rise from one kingdom to the next', () {
      int previous = 0;
      for (final KingdomDefinition kingdom in KingdomConfig.kingdoms) {
        expect(kingdom.totalCost, greaterThan(previous), reason: kingdom.name);
        previous = kingdom.totalCost;
      }
    });

    test('upgrade costs rise within a kingdom', () {
      for (final KingdomDefinition kingdom in KingdomConfig.kingdoms) {
        for (int i = 1; i < kingdom.upgrades.length; i++) {
          expect(
            kingdom.upgrades[i].cost,
            greaterThan(kingdom.upgrades[i - 1].cost),
            reason: '${kingdom.name} step $i',
          );
        }
      }
    });
  });

  group('Run results', () {
    test('record stats and raise the best score', () {
      final PlayerService player = makePlayer().player;

      player.recordGameFinished(
        score: 1500,
        linesCleared: 12,
        piecesPlaced: 40,
        bestComboDepth: 3,
      );

      expect(player.bestScore, 1500);
      expect(player.stats.gamesPlayed, 1);
      expect(player.stats.linesCleared, 12);
      expect(player.stats.piecesPlaced, 40);
      expect(player.stats.bestCombo, 3);
    });

    test('a worse run does not lower the best score', () {
      final PlayerService player = makePlayer().player;
      player.recordGameFinished(
        score: 2000,
        linesCleared: 1,
        piecesPlaced: 1,
        bestComboDepth: 1,
      );
      player.recordGameFinished(
        score: 500,
        linesCleared: 1,
        piecesPlaced: 1,
        bestComboDepth: 1,
      );

      expect(player.bestScore, 2000);
      expect(player.stats.gamesPlayed, 2);
    });

    test('rewards are credited to the wallet', () {
      final PlayerService player = makePlayer().player;
      player.grantRunRewards(crowns: 12, coins: 80, xp: 30);

      expect(player.crowns, 12);
      expect(player.coins, 80);
      expect(player.xp, 30);
    });
  });

  group('Achievements', () {
    test('unlock when their metric passes the target and pay out', () {
      final PlayerService player = makePlayer().player;

      player.recordGameFinished(
        score: 100,
        linesCleared: 1,
        piecesPlaced: 1,
        bestComboDepth: 1,
      );

      final AchievementProgress first = player.data.achievementProgress(
        'first_clear',
      );
      expect(first.unlocked, isTrue);
      expect(player.coins, AchievementCatalog.byId('first_clear')!.rewardCoins);
    });

    test('do not pay out twice', () {
      final PlayerService player = makePlayer().player;
      for (int i = 0; i < 3; i++) {
        player.recordGameFinished(
          score: 100,
          linesCleared: 1,
          piecesPlaced: 1,
          bestComboDepth: 1,
        );
      }

      expect(player.coins, AchievementCatalog.byId('first_clear')!.rewardCoins);
    });

    test('stay locked until the target is reached', () {
      final PlayerService player = makePlayer().player;
      player.recordGameFinished(
        score: 4999,
        linesCleared: 1,
        piecesPlaced: 1,
        bestComboDepth: 1,
      );

      expect(player.data.achievementProgress('score_5000').unlocked, isFalse);

      player.recordGameFinished(
        score: 5000,
        linesCleared: 1,
        piecesPlaced: 1,
        bestComboDepth: 1,
      );
      expect(player.data.achievementProgress('score_5000').unlocked, isTrue);
    });

    test('the unseen badge count clears once seen', () {
      final PlayerService player = makePlayer().player;
      player.recordGameFinished(
        score: 100,
        linesCleared: 1,
        piecesPlaced: 1,
        bestComboDepth: 1,
      );

      expect(player.unseenAchievementCount, greaterThan(0));
      player.markAchievementSeen('first_clear');
      expect(player.unseenAchievementCount, 0);
    });
  });

  group('Starter pack window', () {
    test('is open immediately after install', () {
      final DateTime now = DateTime(2026, 1, 1, 12);
      final PlayerService player = makePlayer(
        initial: SaveData.fresh(now: now),
      ).player;

      expect(player.starterPackAvailable(now: now), isTrue);
      expect(
        player.starterPackRemaining(now: now),
        EconomyConfig.starterPackWindow,
      );
    });

    test('closes permanently once the window elapses', () {
      final DateTime installed = DateTime(2026, 1, 1, 12);
      final PlayerService player = makePlayer(
        initial: SaveData.fresh(now: installed),
      ).player;

      final DateTime after = installed.add(
        EconomyConfig.starterPackWindow + const Duration(minutes: 1),
      );

      expect(player.starterPackAvailable(now: after), isFalse);
      expect(player.starterPackRemaining(now: after), Duration.zero);
    });

    test('closes once the pack is owned, even inside the window', () {
      final DateTime now = DateTime(2026, 1, 1, 12);
      final PlayerService player = makePlayer(
        initial: SaveData.fresh(now: now),
      ).player;

      player.grantProduct('starter_pack');
      expect(player.starterPackAvailable(now: now), isFalse);
    });
  });

  group('Purchases and settings', () {
    test('remove ads is recorded as an entitlement', () {
      final PlayerService player = makePlayer().player;
      expect(player.adsRemoved, isFalse);

      player.grantProduct('remove_ads');

      expect(player.adsRemoved, isTrue);
      expect(player.ownsProduct('remove_ads'), isTrue);
    });

    test('restoring re-applies non-consumables', () {
      final PlayerService player = makePlayer().player;
      player.restoreProducts(<String>['remove_ads', 'starter_pack']);

      expect(player.adsRemoved, isTrue);
      expect(player.ownsProduct('starter_pack'), isTrue);
    });

    test('settings toggles persist to the model', () {
      final PlayerService player = makePlayer().player;

      player
        ..setMusicEnabled(false)
        ..setSoundEnabled(false)
        ..setHapticsEnabled(false);

      expect(player.settings.musicEnabled, isFalse);
      expect(player.settings.soundEnabled, isFalse);
      expect(player.settings.hapticsEnabled, isFalse);
    });

    test('tutorial completion is recorded once', () {
      final PlayerService player = makePlayer().player;
      expect(player.tutorialCompleted, isFalse);

      player.markTutorialCompleted();
      expect(player.tutorialCompleted, isTrue);
    });
  });

  group('Reset', () {
    test('wipes the profile back to a fresh install', () async {
      final ({PlayerService player, InMemoryStorage storage}) setup =
          makePlayer();
      final PlayerService player = setup.player;

      player
        ..addCoins(5000)
        ..addCrowns(500)
        ..addXp(10000);
      player.recordGameFinished(
        score: 9000,
        linesCleared: 50,
        piecesPlaced: 200,
        bestComboDepth: 4,
      );

      await player.resetProgress();

      expect(player.coins, 0);
      expect(player.crowns, 0);
      expect(player.level, 1);
      expect(player.bestScore, 0);
      expect(player.stats.gamesPlayed, 0);
      expect(
        player.boosterCount(BoosterType.hammer),
        EconomyConfig.startingBoosters[BoosterType.hammer],
      );
    });
  });

  group('Persistence', () {
    test('every mutation writes through to storage', () async {
      final ({PlayerService player, InMemoryStorage storage}) setup =
          makePlayer();
      setup.player.addCoins(100);

      // The write is fire-and-forget; let the microtask queue drain.
      await Future<void>.delayed(Duration.zero);
      expect(setup.storage.saveCount, greaterThan(0));

      final SaveData? saved = await setup.storage.load();
      expect(saved!.coins, 100);
    });
  });
}

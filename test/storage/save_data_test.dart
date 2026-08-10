import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/core/config/economy_config.dart';
import 'package:kingdom_drop/models/achievement.dart';
import 'package:kingdom_drop/models/booster.dart';
import 'package:kingdom_drop/models/daily_state.dart';
import 'package:kingdom_drop/models/save_data.dart';

/// Encodes and decodes through real JSON, which is what actually happens on
/// disk — a model that only round-trips through a Dart map can still break.
SaveData roundTrip(SaveData original) =>
    SaveData.fromJson(jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);

void main() {
  group('Fresh save', () {
    test('starts empty apart from the configured starting boosters', () {
      final SaveData data = SaveData.fresh();

      expect(data.coins, 0);
      expect(data.crowns, 0);
      expect(data.level, 1);
      expect(data.bestScore, 0);
      expect(data.tutorialCompleted, isFalse);
      expect(data.introSeen, isFalse);
      expect(data.adsRemoved, isFalse);
      expect(data.schemaVersion, SaveData.currentSchemaVersion);
      expect(
        data.boosters[BoosterType.hammer],
        EconomyConfig.startingBoosters[BoosterType.hammer],
      );
    });

    test('pins the install timestamp', () {
      final DateTime now = DateTime(2026, 4, 4, 10, 30);
      expect(SaveData.fresh(now: now).installedAt, now);
    });
  });

  group('Round trip', () {
    test('preserves every scalar field', () {
      final SaveData original = SaveData.fresh(now: DateTime(2026, 1, 2, 3, 4))
        ..coins = 4321
        ..crowns = 765
        ..xp = 88
        ..level = 7
        ..bestScore = 19450
        ..adsRemoved = true
        ..tutorialCompleted = true
        ..introSeen = true;

      final SaveData restored = roundTrip(original);

      expect(restored.coins, 4321);
      expect(restored.crowns, 765);
      expect(restored.xp, 88);
      expect(restored.level, 7);
      expect(restored.bestScore, 19450);
      expect(restored.adsRemoved, isTrue);
      expect(restored.tutorialCompleted, isTrue);
      expect(restored.introSeen, isTrue);
      expect(
        restored.installedAt.toIso8601String(),
        original.installedAt.toIso8601String(),
      );
    });

    test('preserves boosters keyed by name', () {
      final SaveData original = SaveData.fresh();
      original.boosters[BoosterType.bomb] = 12;
      original.boosters[BoosterType.secondChance] = 3;

      final SaveData restored = roundTrip(original);

      expect(restored.boosterCount(BoosterType.bomb), 12);
      expect(restored.boosterCount(BoosterType.secondChance), 3);
    });

    test('preserves kingdom progress', () {
      final SaveData original = SaveData.fresh();
      original.kingdom
        ..currentIndex = 3
        ..completedUpgrades['forgotten_keep'] = 5
        ..completedUpgrades['desert_citadel'] = 2;

      final SaveData restored = roundTrip(original);

      expect(restored.kingdom.currentIndex, 3);
      expect(restored.kingdom.upgradesFor('forgotten_keep'), 5);
      expect(restored.kingdom.upgradesFor('desert_citadel'), 2);
      expect(restored.kingdom.upgradesFor('never_visited'), 0);
    });

    test('preserves lifetime stats', () {
      final SaveData original = SaveData.fresh();
      original.stats
        ..gamesPlayed = 42
        ..piecesPlaced = 1337
        ..linesCleared = 260
        ..totalScore = 500000
        ..bestCombo = 5
        ..kingdomsCompleted = 2
        ..kingdomUpgradesBought = 11;

      final SaveData restored = roundTrip(original);

      expect(restored.stats.gamesPlayed, 42);
      expect(restored.stats.piecesPlaced, 1337);
      expect(restored.stats.linesCleared, 260);
      expect(restored.stats.totalScore, 500000);
      expect(restored.stats.bestCombo, 5);
      expect(restored.stats.kingdomsCompleted, 2);
      expect(restored.stats.kingdomUpgradesBought, 11);
    });

    test('preserves achievements', () {
      final SaveData original = SaveData.fresh();
      original.achievements['first_clear'] = AchievementProgress(
        progress: 9,
        unlocked: true,
        claimed: true,
      );

      final SaveData restored = roundTrip(original);
      final AchievementProgress p = restored.achievementProgress('first_clear');

      expect(p.progress, 9);
      expect(p.unlocked, isTrue);
      expect(p.claimed, isTrue);
    });

    test('preserves the daily reward streak', () {
      final SaveData original = SaveData.fresh();
      original.dailyReward
        ..lastClaimedDay = const DayKey(2026, 2, 14)
        ..streakDay = 5;

      final SaveData restored = roundTrip(original);

      expect(restored.dailyReward.lastClaimedDay, const DayKey(2026, 2, 14));
      expect(restored.dailyReward.streakDay, 5);
    });

    test('preserves the daily challenge', () {
      final SaveData original = SaveData.fresh();
      original.dailyChallenge
        ..day = const DayKey(2026, 2, 14)
        ..type = ChallengeType.triggerCombos
        ..target = 6
        ..progress = 4
        ..claimed = false;

      final SaveData restored = roundTrip(original);

      expect(restored.dailyChallenge.type, ChallengeType.triggerCombos);
      expect(restored.dailyChallenge.target, 6);
      expect(restored.dailyChallenge.progress, 4);
    });

    test('preserves owned products and settings', () {
      final SaveData original = SaveData.fresh();
      original.ownedProducts.addAll(<String>['remove_ads', 'starter_pack']);
      original.settings
        ..musicEnabled = false
        ..soundEnabled = true
        ..hapticsEnabled = false;

      final SaveData restored = roundTrip(original);

      expect(restored.ownedProducts, containsAll(<String>['remove_ads', 'starter_pack']));
      expect(restored.settings.musicEnabled, isFalse);
      expect(restored.settings.soundEnabled, isTrue);
      expect(restored.settings.hapticsEnabled, isFalse);
    });
  });

  group('Tolerating bad data', () {
    test('an empty document loads as a usable default profile', () {
      final SaveData data = SaveData.fromJson(<String, dynamic>{});

      expect(data.coins, 0);
      expect(data.level, 1);
      expect(data.settings.soundEnabled, isTrue);
      expect(data.kingdom.currentIndex, 0);
    });

    test('missing sections fall back to defaults instead of throwing', () {
      final SaveData data = SaveData.fromJson(<String, dynamic>{
        'v': 1,
        'coins': 500,
        // stats, kingdom, boosters, settings all absent.
      });

      expect(data.coins, 500);
      expect(data.stats.gamesPlayed, 0);
      expect(data.kingdom.currentIndex, 0);
      expect(data.settings.hapticsEnabled, isTrue);
    });

    test('an unparsable install date falls back to now rather than failing', () {
      final SaveData data = SaveData.fromJson(<String, dynamic>{
        'installedAt': 'not a date',
      });
      expect(data.installedAt, isNotNull);
    });

    test('an unknown booster key is dropped, not fatal', () {
      final SaveData data = SaveData.fromJson(<String, dynamic>{
        'boosters': <String, dynamic>{'hammer': 4, 'teleporter': 9},
      });

      expect(data.boosterCount(BoosterType.hammer), 4);
      expect(data.boosters.length, 1);
    });

    test('an out-of-range challenge type is clamped', () {
      final SaveData data = SaveData.fromJson(<String, dynamic>{
        'challenge': <String, dynamic>{'type': 999},
      });
      expect(ChallengeType.values, contains(data.dailyChallenge.type));
    });

    test('a corrupt day string leaves the streak unclaimed', () {
      final SaveData data = SaveData.fromJson(<String, dynamic>{
        'daily': <String, dynamic>{'last': 'garbage', 'streak': 3},
      });
      expect(data.dailyReward.lastClaimedDay, isNull);
    });
  });

  group('Migrations', () {
    test('a document already at the current version is unchanged', () {
      final Map<String, dynamic> json = SaveData.fresh().toJson();
      final Map<String, dynamic> migrated = SaveMigrations.migrate(
        Map<String, dynamic>.of(json),
      );

      expect(migrated['v'], SaveData.currentSchemaVersion);
      expect(migrated['coins'], json['coins']);
    });

    test('a versionless document is stamped and still loads', () {
      final Map<String, dynamic> legacy = <String, dynamic>{
        'coins': 900,
        'crowns': 12,
      };

      final SaveData data = SaveData.fromJson(SaveMigrations.migrate(legacy));

      expect(data.schemaVersion, SaveData.currentSchemaVersion);
      expect(data.coins, 900);
      expect(data.crowns, 12);
    });

    test('a save from a newer build is left alone rather than rejected', () {
      final Map<String, dynamic> future = <String, dynamic>{
        'v': SaveData.currentSchemaVersion + 5,
        'coins': 77,
        'somethingNew': true,
      };

      final SaveData data = SaveData.fromJson(SaveMigrations.migrate(future));

      expect(data.coins, 77, reason: 'a downgrade must not wipe progress');
    });

    test('migration terminates even with a misbehaving step', () {
      // A step that forgets to advance the version must not spin forever.
      SaveMigrations.steps[0] = (Map<String, dynamic> json) => json;
      addTearDown(() => SaveMigrations.steps.remove(0));

      final Map<String, dynamic> result = SaveMigrations.migrate(
        <String, dynamic>{'v': 0, 'coins': 1},
      );

      expect(result['coins'], 1);
    });
  });
}

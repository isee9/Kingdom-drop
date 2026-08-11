import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/core/config/economy_config.dart';
import 'package:kingdom_drop/economy/player_service.dart';
import 'package:kingdom_drop/game/engine/game_engine.dart';
import 'package:kingdom_drop/models/daily_state.dart';
import 'package:kingdom_drop/models/save_data.dart';
import 'package:kingdom_drop/progression/chest_service.dart';
import 'package:kingdom_drop/progression/daily_service.dart';
import 'package:kingdom_drop/services/analytics_service.dart';
import 'package:kingdom_drop/storage/storage_repository.dart';

({PlayerService player, DailyService daily}) makeDaily() {
  final PlayerService player = PlayerService(
    storage: InMemoryStorage(),
    analytics: const NoopAnalyticsService(),
    initial: SaveData.fresh(),
  );
  final DailyService daily = DailyService(
    player: player,
    analytics: const NoopAnalyticsService(),
    chests: ChestService(random: Random(1)),
    random: Random(1),
  );
  return (player: player, daily: daily);
}

void main() {
  group('DayKey', () {
    test('formats as yyyy-mm-dd with padding', () {
      expect(const DayKey(2026, 3, 7).toString(), '2026-03-07');
      expect(const DayKey(2026, 12, 25).toString(), '2026-12-25');
    });

    test('round-trips through parsing', () {
      const DayKey day = DayKey(2026, 8, 9);
      expect(DayKey.tryParse(day.toString()), day);
    });

    test('rejects malformed values instead of throwing', () {
      expect(DayKey.tryParse(null), isNull);
      expect(DayKey.tryParse(''), isNull);
      expect(DayKey.tryParse('not-a-date'), isNull);
      expect(DayKey.tryParse('2026-13-01'), isNull);
      expect(DayKey.tryParse('2026-01-99'), isNull);
      expect(DayKey.tryParse('2026/01/01'), isNull);
    });

    test('counts whole days, including across a month boundary', () {
      expect(const DayKey(2026, 1, 31).daysUntil(const DayKey(2026, 2, 1)), 1);
      expect(const DayKey(2026, 2, 28).daysUntil(const DayKey(2026, 3, 3)), 3);
      expect(
        const DayKey(2026, 1, 1).daysUntil(const DayKey(2025, 12, 31)),
        -1,
      );
    });

    test('handles a leap day', () {
      expect(
        const DayKey(2028, 2, 28).daysUntil(const DayKey(2028, 3, 1)),
        2,
        reason: '2028 is a leap year',
      );
    });

    test('ignores the time of day', () {
      final DayKey morning = DayKey.fromDateTime(DateTime(2026, 5, 4, 1, 30));
      final DayKey night = DayKey.fromDateTime(DateTime(2026, 5, 4, 23, 59));
      expect(morning, night);
    });
  });

  group('Daily reward streak', () {
    test('day one is claimable on a fresh install', () {
      final DailyService daily = makeDaily().daily;
      final DailyRewardStatus status = daily.statusFor(
        now: DateTime(2026, 1, 1),
      );

      expect(status.canClaim, isTrue);
      expect(status.claimableDay, 1);
      expect(status.streakBroken, isFalse);
    });

    test('claiming pays out and blocks a second claim the same day', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      final DateTime day1 = DateTime(2026, 1, 1, 9);

      final DailyRewardConfig? reward = setup.daily.claimDailyReward(now: day1);

      expect(reward, isNotNull);
      expect(setup.player.coins, EconomyConfig.dailyRewards[0].coins);

      // Later the same day.
      expect(
        setup.daily.canClaimDailyReward(now: DateTime(2026, 1, 1, 23)),
        isFalse,
      );
      expect(
        setup.daily.claimDailyReward(now: DateTime(2026, 1, 1, 23)),
        isNull,
      );
      expect(setup.player.coins, EconomyConfig.dailyRewards[0].coins);
    });

    test('the next day advances the streak', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      setup.daily.claimDailyReward(now: DateTime(2026, 1, 1));

      final DailyRewardStatus status = setup.daily.statusFor(
        now: DateTime(2026, 1, 2),
      );

      expect(status.canClaim, isTrue);
      expect(status.claimableDay, 2);
      expect(status.streakBroken, isFalse);
    });

    test('a full week runs day one through seven in order', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();

      for (int day = 1; day <= EconomyConfig.dailyStreakLength; day++) {
        final DateTime now = DateTime(2026, 1, day);
        expect(
          setup.daily.statusFor(now: now).claimableDay,
          day,
          reason: 'day $day',
        );
        expect(setup.daily.claimDailyReward(now: now), isNotNull);
      }
    });

    test('the streak cycles back to day one after day seven', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      for (int day = 1; day <= 7; day++) {
        setup.daily.claimDailyReward(now: DateTime(2026, 1, day));
      }

      expect(setup.daily.statusFor(now: DateTime(2026, 1, 8)).claimableDay, 1);
    });

    test('missing a day restarts the streak and says so', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      setup.daily.claimDailyReward(now: DateTime(2026, 1, 1));
      setup.daily.claimDailyReward(now: DateTime(2026, 1, 2));

      // Skip 3 January entirely.
      final DailyRewardStatus status = setup.daily.statusFor(
        now: DateTime(2026, 1, 4),
      );

      expect(status.canClaim, isTrue);
      expect(status.claimableDay, 1);
      expect(status.streakBroken, isTrue);
    });

    test('a clock moved backwards cannot farm a second reward', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      setup.daily.claimDailyReward(now: DateTime(2026, 6, 10));
      final int coinsAfterClaim = setup.player.coins;

      // Device clock rolled back a week.
      expect(
        setup.daily.canClaimDailyReward(now: DateTime(2026, 6, 3)),
        isFalse,
      );
      expect(setup.daily.claimDailyReward(now: DateTime(2026, 6, 3)), isNull);
      expect(setup.player.coins, coinsAfterClaim);
    });

    test('booster days grant the booster', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      final DailyRewardConfig boosterDay = EconomyConfig.dailyRewards
          .firstWhere((DailyRewardConfig d) => d.booster != null);

      final int before = setup.player.boosterCount(boosterDay.booster!);
      for (int day = 1; day <= boosterDay.day; day++) {
        setup.daily.claimDailyReward(now: DateTime(2026, 2, day));
      }

      expect(
        setup.player.boosterCount(boosterDay.booster!),
        before + boosterDay.boosterCount,
      );
    });

    test('the day seven chest pays crowns as well as coins', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      for (int day = 1; day <= 7; day++) {
        setup.daily.claimDailyReward(now: DateTime(2026, 3, day));
      }

      expect(setup.player.crowns, greaterThan(0));
    });

    test('debug reset makes the reward claimable again', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      setup.daily.claimDailyReward(now: DateTime(2026, 4, 1));
      expect(
        setup.daily.canClaimDailyReward(now: DateTime(2026, 4, 1)),
        isFalse,
      );

      setup.daily.debugResetDailyReward();
      expect(
        setup.daily.canClaimDailyReward(now: DateTime(2026, 4, 1)),
        isTrue,
      );
    });
  });

  group('Daily challenge', () {
    test('is generated for today and has a positive target', () {
      final DailyService daily = makeDaily().daily;
      final DailyChallengeState state = daily.challengeFor(
        now: DateTime(2026, 5, 1),
      );

      expect(state.day, DayKey(2026, 5, 1));
      expect(state.target, greaterThan(0));
      expect(state.progress, 0);
      expect(state.claimed, isFalse);
    });

    test('is stable within a day and cannot be re-rolled', () {
      final DailyService daily = makeDaily().daily;
      final DailyChallengeState first = daily.challengeFor(
        now: DateTime(2026, 5, 1, 8),
      );
      final ChallengeType type = first.type;
      final int target = first.target;

      final DailyChallengeState second = daily.challengeFor(
        now: DateTime(2026, 5, 1, 20),
      );

      expect(second.type, type);
      expect(second.target, target);
    });

    test('is seeded by the date, so every device agrees', () {
      final DailyService a = makeDaily().daily;
      final DailyService b = makeDaily().daily;

      final DailyChallengeState fromA = a.challengeFor(
        now: DateTime(2026, 7, 14),
      );
      final DailyChallengeState fromB = b.challengeFor(
        now: DateTime(2026, 7, 14),
      );

      expect(fromA.type, fromB.type);
      expect(fromA.target, fromB.target);
    });

    test('regenerates on a new day and resets progress', () {
      final DailyService daily = makeDaily().daily;
      final DailyChallengeState today = daily.challengeFor(
        now: DateTime(2026, 5, 1),
      );
      today.progress = today.target;

      final DailyChallengeState tomorrow = daily.challengeFor(
        now: DateTime(2026, 5, 2),
      );

      expect(tomorrow.day, DayKey(2026, 5, 2));
      expect(tomorrow.progress, 0);
      expect(tomorrow.claimed, isFalse);
    });

    test('cumulative challenges add run totals together', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      final DateTime now = DateTime(2026, 5, 1);
      final DailyChallengeState state = setup.daily.challengeFor(now: now);

      // Force a cumulative type so the assertion is about accumulation.
      state
        ..type = ChallengeType.clearRows
        ..target = 20
        ..progress = 0;

      final GameStats run = GameStats()..linesCleared = 6;
      setup.daily.applyRunToChallenge(run, now: now);
      setup.daily.applyRunToChallenge(run, now: now);

      expect(state.progress, 12);
      expect(state.complete, isFalse);
    });

    test('best-in-one-run challenges take the maximum', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      final DateTime now = DateTime(2026, 5, 1);
      final DailyChallengeState state = setup.daily.challengeFor(now: now);
      state
        ..type = ChallengeType.scorePoints
        ..target = 5000
        ..progress = 0;

      setup.daily.applyRunToChallenge(GameStats()..score = 3000, now: now);
      setup.daily.applyRunToChallenge(GameStats()..score = 1200, now: now);

      expect(state.progress, 3000, reason: 'a worse run must not reduce it');
    });

    test('completing then claiming pays out exactly once', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      final DateTime now = DateTime(2026, 5, 1);
      final DailyChallengeState state = setup.daily.challengeFor(now: now);
      state
        ..type = ChallengeType.clearRows
        ..target = 5
        ..progress = 0;

      expect(setup.daily.canClaimChallenge(now: now), isFalse);

      setup.daily.applyRunToChallenge(GameStats()..linesCleared = 5, now: now);
      expect(setup.daily.canClaimChallenge(now: now), isTrue);

      expect(setup.daily.claimChallenge(now: now), isTrue);
      expect(setup.player.coins, EconomyConfig.challengeRewardCoins);
      expect(setup.player.crowns, EconomyConfig.challengeRewardCrowns);

      expect(setup.daily.claimChallenge(now: now), isFalse);
      expect(setup.player.coins, EconomyConfig.challengeRewardCoins);
    });

    test('progress stops accruing once complete', () {
      final ({PlayerService player, DailyService daily}) setup = makeDaily();
      final DateTime now = DateTime(2026, 5, 1);
      final DailyChallengeState state = setup.daily.challengeFor(now: now);
      state
        ..type = ChallengeType.placePieces
        ..target = 10
        ..progress = 10;

      setup.daily.applyRunToChallenge(GameStats()..piecesPlaced = 50, now: now);
      expect(state.progress, 10);
    });

    test('every challenge type produces readable text', () {
      for (final ChallengeType type in ChallengeType.values) {
        final DailyChallengeState state = DailyChallengeState(
          type: type,
          target: 10,
        );
        final String text = DailyService.describe(state);
        expect(text, isNotEmpty, reason: type.name);
        expect(text.trim(), text);
      }
    });

    test('fraction is clamped to 0..1', () {
      final DailyChallengeState state = DailyChallengeState(
        target: 10,
        progress: 25,
      );
      expect(state.fraction, 1.0);

      state.progress = 0;
      expect(state.fraction, 0.0);
    });
  });
}

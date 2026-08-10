import 'dart:math';

import '../core/config/economy_config.dart';
import '../economy/player_service.dart';
import '../game/engine/game_engine.dart';
import '../models/daily_state.dart';
import '../services/analytics_service.dart';
import 'chest_service.dart';

/// What the daily reward panel should show right now.
class DailyRewardStatus {
  const DailyRewardStatus({
    required this.claimableDay,
    required this.canClaim,
    required this.streakDay,
    required this.streakBroken,
  });

  /// The day slot (1..7) the player would claim.
  final int claimableDay;

  /// False when today's reward has already been taken.
  final bool canClaim;

  /// Current position in the streak, 0 before the first ever claim.
  final int streakDay;

  /// True when a missed day reset the run back to day 1.
  final bool streakBroken;
}

/// Daily login streak and the daily challenge.
///
/// Every date decision takes an explicit `now`, defaulting to the device clock.
/// That keeps the logic testable and means moving to a server-supplied date
/// later is a change of argument, not a change of design.
class DailyService {
  DailyService({
    required PlayerService player,
    required AnalyticsService analytics,
    ChestService? chests,
    Random? random,
  }) : _player = player,
       _analytics = analytics,
       _chests = chests ?? ChestService(random: random),
       _random = random ?? Random();

  final PlayerService _player;
  final AnalyticsService _analytics;
  final ChestService _chests;
  final Random _random;

  // ------------------------------------------------------------ daily reward
  /// Works out where the player stands without changing anything.
  DailyRewardStatus statusFor({DateTime? now}) {
    final DayKey today = DayKey.fromDateTime(now ?? DateTime.now());
    final DailyRewardState state = _player.data.dailyReward;
    final DayKey? last = state.lastClaimedDay;

    if (last == null) {
      return const DailyRewardStatus(
        claimableDay: 1,
        canClaim: true,
        streakDay: 0,
        streakBroken: false,
      );
    }

    final int daysSince = last.daysUntil(today);

    if (daysSince <= 0) {
      // Already claimed today. A negative value means the device clock moved
      // backwards; treat that as "already claimed" rather than handing out a
      // second reward.
      return DailyRewardStatus(
        claimableDay: state.streakDay,
        canClaim: false,
        streakDay: state.streakDay,
        streakBroken: false,
      );
    }

    if (daysSince == 1) {
      final int next = state.streakDay >= EconomyConfig.dailyStreakLength
          ? 1
          : state.streakDay + 1;
      return DailyRewardStatus(
        claimableDay: next,
        canClaim: true,
        streakDay: state.streakDay,
        streakBroken: false,
      );
    }

    // Two or more days missed: the streak restarts.
    return DailyRewardStatus(
      claimableDay: 1,
      canClaim: true,
      streakDay: state.streakDay,
      streakBroken: true,
    );
  }

  bool canClaimDailyReward({DateTime? now}) => statusFor(now: now).canClaim;

  /// Claims today's reward. Returns null if it was already taken.
  DailyRewardConfig? claimDailyReward({DateTime? now}) {
    final DateTime timestamp = now ?? DateTime.now();
    final DailyRewardStatus status = statusFor(now: timestamp);
    if (!status.canClaim) return null;

    final DailyRewardConfig reward =
        EconomyConfig.dailyRewards[(status.claimableDay - 1).clamp(
          0,
          EconomyConfig.dailyRewards.length - 1,
        )];

    if (reward.coins > 0) _player.addCoins(reward.coins);
    if (reward.crowns > 0) _player.addCrowns(reward.crowns);
    if (reward.booster != null && reward.boosterCount > 0) {
      _player.grantBooster(reward.booster!, reward.boosterCount);
    }
    if (reward.chest) {
      final ChestReward chest = _chests.open(ChestTier.rare);
      _player.addCoins(chest.coins);
      _player.addCrowns(chest.crowns);
      _player.grantBoosters(chest.boosters);
    }

    final DailyRewardState state = _player.data.dailyReward;
    state.lastClaimedDay = DayKey.fromDateTime(timestamp);
    state.streakDay = status.claimableDay;
    _player.flush();

    _analytics.log('daily_reward_claimed', <String, Object?>{
      'day': status.claimableDay,
      'streak_broken': status.streakBroken,
    });

    return reward;
  }

  // --------------------------------------------------------- daily challenge
  /// Returns today's challenge, generating a new one if the date rolled over.
  DailyChallengeState challengeFor({DateTime? now}) {
    final DayKey today = DayKey.fromDateTime(now ?? DateTime.now());
    final DailyChallengeState state = _player.data.dailyChallenge;

    if (state.day != today) {
      _regenerate(state, today);
      _player.flush();
    }
    return state;
  }

  /// Seeded by the date so every device gets the same challenge on a given day
  /// and it cannot be re-rolled by restarting the app.
  void _regenerate(DailyChallengeState state, DayKey day) {
    final Random seeded = Random(day.year * 10000 + day.month * 100 + day.day);
    final ChallengeType type =
        ChallengeType.values[seeded.nextInt(ChallengeType.values.length)];

    state
      ..day = day
      ..type = type
      ..target = _targetFor(type, seeded)
      ..progress = 0
      ..claimed = false;
  }

  int _targetFor(ChallengeType type, Random rng) => switch (type) {
    ChallengeType.clearRows => 8 + rng.nextInt(8), // 8-15
    ChallengeType.scorePoints => 3000 + rng.nextInt(5) * 500, // 3000-5000
    ChallengeType.triggerCombos => 3 + rng.nextInt(4), // 3-6
    ChallengeType.simultaneousClears => 1 + rng.nextInt(3), // 1-3
    ChallengeType.placePieces => 40 + rng.nextInt(4) * 10, // 40-70
  };

  /// Folds a finished run into today's challenge progress.
  ///
  /// Cumulative challenges add up across runs; "best in one run" challenges
  /// (like a triple clear) take the maximum instead.
  void applyRunToChallenge(GameStats stats, {DateTime? now}) {
    final DailyChallengeState state = challengeFor(now: now);
    if (state.complete) return;

    switch (state.type) {
      case ChallengeType.clearRows:
        state.progress += stats.linesCleared;
      case ChallengeType.scorePoints:
        state.progress = max(state.progress, stats.score);
      case ChallengeType.triggerCombos:
        state.progress += stats.combosTriggered;
      case ChallengeType.simultaneousClears:
        state.progress = max(state.progress, stats.maxSimultaneousClears);
      case ChallengeType.placePieces:
        state.progress += stats.piecesPlaced;
    }

    _player.flush();
  }

  bool canClaimChallenge({DateTime? now}) {
    final DailyChallengeState state = challengeFor(now: now);
    return state.complete && !state.claimed;
  }

  /// Pays out the challenge reward once.
  bool claimChallenge({DateTime? now}) {
    final DailyChallengeState state = challengeFor(now: now);
    if (!state.complete || state.claimed) return false;

    state.claimed = true;
    _player.addCoins(EconomyConfig.challengeRewardCoins);
    _player.addCrowns(EconomyConfig.challengeRewardCrowns);
    _player.flush();

    _analytics.log('challenge_completed', <String, Object?>{
      'type': state.type.name,
      'target': state.target,
    });
    return true;
  }

  /// Human-readable challenge text.
  static String describe(DailyChallengeState state) => switch (state.type) {
    ChallengeType.clearRows => 'Clear ${state.target} lines',
    ChallengeType.scorePoints => 'Score ${_thousands(state.target)} points',
    ChallengeType.triggerCombos => 'Trigger ${state.target} combos',
    ChallengeType.simultaneousClears =>
      state.target == 1
          ? 'Clear 2 lines at once'
          : 'Clear ${state.target + 1} lines at once',
    ChallengeType.placePieces => 'Place ${state.target} pieces',
  };

  static String _thousands(int value) {
    final String s = value.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  /// Debug helper: forgets today's claim so the reward can be taken again.
  void debugResetDailyReward() {
    _player.data.dailyReward
      ..lastClaimedDay = null
      ..streakDay = 0;
    _player.flush();
  }

  /// Debug helper: force a specific challenge to completion.
  void debugCompleteChallenge() {
    final DailyChallengeState state = challengeFor();
    state.progress = state.target;
    _player.flush();
  }

  Random get random => _random;
}

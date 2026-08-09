/// The kinds of daily challenge the generator can produce. Adding a value here
/// plus a case in the challenge service is all a new challenge needs.
enum ChallengeType {
  clearRows,
  scorePoints,
  triggerCombos,
  simultaneousClears,
  placePieces,
}

/// A calendar day, stored as `yyyy-mm-dd` so comparisons are timezone-stable
/// against the device's own local date.
class DayKey implements Comparable<DayKey> {
  const DayKey(this.year, this.month, this.day);

  factory DayKey.fromDateTime(DateTime dt) => DayKey(dt.year, dt.month, dt.day);

  factory DayKey.today() => DayKey.fromDateTime(DateTime.now());

  /// Parses `yyyy-mm-dd`. Returns null for anything malformed rather than
  /// throwing, so a corrupted save degrades to "never claimed".
  static DayKey? tryParse(String? value) {
    if (value == null) return null;
    final List<String> parts = value.split('-');
    if (parts.length != 3) return null;
    final int? y = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    final int? d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DayKey(y, m, d);
  }

  final int year;
  final int month;
  final int day;

  DateTime toDateTime() => DateTime(year, month, day);

  /// Whole days from this day to [other]. Positive when [other] is later.
  int daysUntil(DayKey other) =>
      other.toDateTime().difference(toDateTime()).inDays;

  DayKey addDays(int days) =>
      DayKey.fromDateTime(toDateTime().add(Duration(days: days)));

  @override
  int compareTo(DayKey other) => toDateTime().compareTo(other.toDateTime());

  @override
  bool operator ==(Object other) =>
      other is DayKey &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// Persisted state of the seven-day login streak.
///
/// Written against the device clock, but every decision runs through
/// [DailyRewardState.evaluate] with an injected "today", so swapping in a
/// server-supplied date later means changing one call site.
class DailyRewardState {
  DailyRewardState({this.lastClaimedDay, this.streakDay = 0});

  factory DailyRewardState.fromJson(Map<String, dynamic> json) =>
      DailyRewardState(
        lastClaimedDay: DayKey.tryParse(json['last'] as String?),
        streakDay: (json['streak'] as num?)?.toInt() ?? 0,
      );

  /// Null until the player has claimed at least once.
  DayKey? lastClaimedDay;

  /// 0 before the first claim, then 1..7 cycling.
  int streakDay;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'last': lastClaimedDay?.toString(),
    'streak': streakDay,
  };
}

/// Persisted state of today's challenge.
class DailyChallengeState {
  DailyChallengeState({
    this.day,
    this.type = ChallengeType.clearRows,
    this.target = 10,
    this.progress = 0,
    this.claimed = false,
  });

  factory DailyChallengeState.fromJson(Map<String, dynamic> json) {
    final int typeIndex = (json['type'] as num?)?.toInt() ?? 0;
    return DailyChallengeState(
      day: DayKey.tryParse(json['day'] as String?),
      type: ChallengeType.values[typeIndex.clamp(
        0,
        ChallengeType.values.length - 1,
      )],
      target: (json['target'] as num?)?.toInt() ?? 10,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      claimed: json['claimed'] as bool? ?? false,
    );
  }

  DayKey? day;
  ChallengeType type;
  int target;
  int progress;
  bool claimed;

  bool get complete => progress >= target;

  double get fraction => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'day': day?.toString(),
    'type': type.index,
    'target': target,
    'progress': progress,
    'claimed': claimed,
  };
}

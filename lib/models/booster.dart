/// The four boosters. The enum name is the persistence key, so renaming a value
/// requires a save migration.
enum BoosterType {
  /// Removes one chosen occupied cell.
  hammer,

  /// Clears a 3x3 area centred on the chosen cell.
  bomb,

  /// Replaces the three pieces currently in the tray.
  shuffle,

  /// After a loss, clears space so the run can continue.
  secondChance;

  static BoosterType? fromKey(String key) {
    for (final BoosterType t in BoosterType.values) {
      if (t.name == key) return t;
    }
    return null;
  }
}

extension BoosterTypeDisplay on BoosterType {
  String get displayName => switch (this) {
    BoosterType.hammer => 'Hammer',
    BoosterType.bomb => 'Bomb',
    BoosterType.shuffle => 'Shuffle',
    BoosterType.secondChance => 'Second Chance',
  };

  String get description => switch (this) {
    BoosterType.hammer => 'Remove any single block from the board.',
    BoosterType.bomb => 'Blast a 3x3 area clear.',
    BoosterType.shuffle => 'Swap your three current pieces for new ones.',
    BoosterType.secondChance => 'Clear space and keep playing after a loss.',
  };

  /// Boosters aimed at the board are armed first, then applied to a tapped
  /// cell. Shuffle and second chance take effect immediately.
  bool get requiresCellTarget =>
      this == BoosterType.hammer || this == BoosterType.bomb;
}

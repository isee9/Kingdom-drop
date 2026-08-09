import '../models/save_data.dart';

/// Persistence boundary.
///
/// The rest of the app only ever sees this interface, so swapping
/// SharedPreferences for a file, a database or a cloud save later is a
/// one-class change.
abstract interface class StorageRepository {
  /// Loads the saved profile, or null if this is a first run.
  ///
  /// Implementations must never throw: a corrupted or unreadable save returns
  /// null so the game can start fresh instead of crashing on launch.
  Future<SaveData?> load();

  /// Writes the profile. Returns false if the write failed, so callers can warn
  /// rather than silently losing progress.
  Future<bool> save(SaveData data);

  /// Wipes everything. Used by "Reset Progress" in settings.
  Future<void> clear();
}

/// In-memory implementation for tests and previews.
class InMemoryStorage implements StorageRepository {
  InMemoryStorage([this._data]);

  SaveData? _data;

  /// Number of writes performed. Handy for asserting debounce behaviour.
  int saveCount = 0;

  @override
  Future<SaveData?> load() async => _data;

  @override
  Future<bool> save(SaveData data) async {
    _data = data;
    saveCount++;
    return true;
  }

  @override
  Future<void> clear() async => _data = null;
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/save_data.dart';
import 'storage_repository.dart';

/// SharedPreferences-backed persistence.
///
/// ## Not losing progress
///
/// Three things protect the save:
///
/// 1. The whole profile is one JSON document under one key, so a write is
///    all-or-nothing.
/// 2. Before overwriting, the previous document is copied to a backup key. If
///    the primary ever fails to parse, [load] falls back to the backup.
/// 3. Nothing throws out of this class. A failed read returns null (fresh
///    start) and a failed write returns false, which the caller surfaces.
class PrefsStorage implements StorageRepository {
  PrefsStorage._(this._prefs);

  static const String _primaryKey = 'kingdom_drop.save.v1';
  static const String _backupKey = 'kingdom_drop.save.backup.v1';

  static Future<PrefsStorage> create() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return PrefsStorage._(prefs);
  }

  final SharedPreferences _prefs;

  @override
  Future<SaveData?> load() async {
    final SaveData? primary = _read(_primaryKey);
    if (primary != null) return primary;

    final SaveData? backup = _read(_backupKey);
    if (backup != null) {
      debugPrint('[storage] primary save unreadable, recovered from backup');
      return backup;
    }
    return null;
  }

  SaveData? _read(String key) {
    final String? raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SaveData.fromJson(SaveMigrations.migrate(decoded));
    } catch (error, stack) {
      debugPrint('[storage] failed to parse "$key": $error');
      if (kDebugMode) debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  @override
  Future<bool> save(SaveData data) async {
    try {
      final String encoded = jsonEncode(data.toJson());

      // Keep the last known-good document before replacing it.
      final String? previous = _prefs.getString(_primaryKey);
      if (previous != null && previous.isNotEmpty && previous != encoded) {
        await _prefs.setString(_backupKey, previous);
      }

      return await _prefs.setString(_primaryKey, encoded);
    } catch (error, stack) {
      debugPrint('[storage] save failed: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stack);
      return false;
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _prefs.remove(_primaryKey);
      await _prefs.remove(_backupKey);
    } catch (error) {
      debugPrint('[storage] clear failed: $error');
    }
  }
}

/// Coalesces rapid saves into one write.
///
/// Gameplay mutates the profile often (every placement can move a challenge
/// counter). Writing on each change would hammer the disk mid-drag, so writes
/// are debounced and any pending write is flushed when the app backgrounds.
class DebouncedStorage implements StorageRepository {
  DebouncedStorage(this._inner, {this.debounce = const Duration(seconds: 2)});

  final StorageRepository _inner;
  final Duration debounce;

  Timer? _timer;
  SaveData? _pending;
  Future<bool>? _inFlight;

  @override
  Future<SaveData?> load() => _inner.load();

  @override
  Future<bool> save(SaveData data) async {
    _pending = data;
    _timer?.cancel();
    _timer = Timer(debounce, flush);
    return true;
  }

  /// Writes immediately if anything is pending. Call on app pause/detach.
  Future<bool> flush() async {
    _timer?.cancel();
    _timer = null;

    final SaveData? data = _pending;
    if (data == null) return true;
    _pending = null;

    // Serialise overlapping flushes so two writes cannot interleave.
    final Future<bool> write = _inFlight == null
        ? _inner.save(data)
        : _inFlight!.then((_) => _inner.save(data));
    _inFlight = write;
    final bool ok = await write;
    if (identical(_inFlight, write)) _inFlight = null;
    return ok;
  }

  @override
  Future<void> clear() async {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    await _inner.clear();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

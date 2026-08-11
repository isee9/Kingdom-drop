import 'package:flutter/foundation.dart';

/// Timestamped progress logging for the parts of startup that can stall.
///
/// Consent, the ad SDK and store billing all cross a platform channel to code
/// this app does not own, and when one of them never calls back there is
/// nothing in a stack trace to see — the app simply stops. A stage log turns
/// that into something readable: the last line printed is the call that never
/// returned.
///
/// Every line carries a wall-clock time and the elapsed time since the log was
/// created, because the interesting question is usually "how long has it been
/// sitting there".
///
/// Lines are prefixed `[kd:<tag>]` so they can be filtered out of a noisy
/// logcat:
///
/// ```
/// adb logcat | findstr kd:          # Windows
/// adb logcat | grep kd:             # macOS / Linux
/// ```
class StageLog {
  StageLog(this.tag);

  final String tag;

  final Stopwatch _elapsed = Stopwatch()..start();

  /// Records that a stage happened.
  ///
  /// [detail] is appended as `key=value` pairs, which keeps the output greppable
  /// rather than turning into prose.
  void stage(String name, [Map<String, Object?>? detail]) {
    final DateTime now = DateTime.now();
    final String clock =
        '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}'
        '.${now.millisecond.toString().padLeft(3, '0')}';
    final String since = (_elapsed.elapsedMilliseconds / 1000).toStringAsFixed(
      3,
    );

    final StringBuffer line = StringBuffer(
      '[kd:$tag] $clock +${since}s  $name',
    );
    if (detail != null) {
      for (final MapEntry<String, Object?> entry in detail.entries) {
        line.write(' ${entry.key}=${entry.value}');
      }
    }
    debugPrint(line.toString());
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

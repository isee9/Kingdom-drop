import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptic feedback, gated on the player's setting.
///
/// Uses Flutter's built-in [HapticFeedback], which no-ops on devices and
/// platforms without a vibrator, so nothing here needs a plugin or a
/// permission. Every call is wrapped because some Android OEM implementations
/// throw when the vibrator is unavailable.
class HapticService {
  HapticService({this.enabled = true});

  /// Mirrors the player's Haptics toggle in settings.
  bool enabled;

  /// Picking a piece up out of the tray.
  void pickup() => _run(HapticFeedback.selectionClick);

  /// A piece landing on the board.
  void place() => _run(HapticFeedback.lightImpact);

  /// A drop that was refused.
  void invalid() => _run(HapticFeedback.mediumImpact);

  /// A line clearing. Scaled by how many groups went at once so a big combo
  /// genuinely feels bigger in the hand.
  void clear(int groupCount) {
    if (groupCount >= 3) {
      _run(HapticFeedback.heavyImpact);
    } else if (groupCount == 2) {
      _run(HapticFeedback.mediumImpact);
    } else {
      _run(HapticFeedback.lightImpact);
    }
  }

  /// Buttons and taps.
  void tap() => _run(HapticFeedback.selectionClick);

  /// Reward moments: level up, kingdom upgrade, chest.
  void reward() => _run(HapticFeedback.heavyImpact);

  /// Losing.
  void gameOver() => _run(HapticFeedback.heavyImpact);

  void _run(Future<void> Function() action) {
    if (!enabled) return;
    try {
      action();
    } catch (error) {
      debugPrint('[haptics] unavailable: $error');
    }
  }
}

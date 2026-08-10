/// Display formatting helpers.
///
/// Written by hand rather than pulling in `intl`: the game only needs thousands
/// separators and a countdown, and the whole UI is English-only for the MVP.
/// Swapping to `intl` later is contained to this file.
abstract final class Formatters {
  /// 12345 becomes "12,345".
  static String number(int value) {
    final bool negative = value < 0;
    final String digits = value.abs().toString();
    final StringBuffer out = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }

    return negative ? '-$out' : out.toString();
  }

  /// Large values shortened for tight spaces: 12345 becomes "12.3K".
  static String compact(int value) {
    if (value.abs() < 1000) return value.toString();
    if (value.abs() < 1000000) {
      final double k = value / 1000;
      return '${k.toStringAsFixed(k.abs() < 10 ? 1 : 0)}K';
    }
    final double m = value / 1000000;
    return '${m.toStringAsFixed(m.abs() < 10 ? 1 : 0)}M';
  }

  /// "5h 12m" / "12m 30s" / "45s" — used for the genuine starter-pack window.
  static String countdown(Duration duration) {
    if (duration.isNegative || duration == Duration.zero) return '0s';

    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  /// "2:41" for a run duration.
  static String duration(Duration value) {
    final int minutes = value.inMinutes;
    final int seconds = value.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// "x1.25" with the trailing zero trimmed.
  static String multiplier(double value) {
    final String text = value.toStringAsFixed(2);
    return 'x${text.endsWith('0') ? text.substring(0, text.length - 1) : text}'
        .replaceAll('.00', '');
  }
}

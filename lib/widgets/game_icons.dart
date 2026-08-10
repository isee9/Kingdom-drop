import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/booster.dart';
import '../theme/app_art.dart';
import '../theme/app_colors.dart';

/// The game's icon set.
///
/// Each icon is the painted asset from `assets/art/icons/` with a code-drawn
/// version behind it. The painted ones are what ship; the painters are the
/// fallback for a build without the pack, and they are why the widget tests can
/// render these without an asset bundle.
///
/// Both are deliberately chunky: thick dark outlines, a lit top and a shaded
/// bottom. A thin line icon next to a chunky button looks borrowed from a
/// settings screen, which is exactly the impression to avoid here.

/// Draws a painted icon, falling back to a painter if the asset is missing.
class _ArtIcon extends StatelessWidget {
  const _ArtIcon({
    required this.asset,
    required this.size,
    required this.fallback,
  });

  final String asset;
  final double size;

  /// Drawn when [asset] cannot be loaded. Built lazily — an icon that loads
  /// never constructs its fallback.
  final Widget Function() fallback;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        // Icons are 144px painted and are drawn as small as 12, so this is
        // always a downscale.
        filterQuality: FilterQuality.medium,
        errorBuilder: (BuildContext _, Object _, StackTrace? _) => fallback(),
      ),
    );
  }
}

/// Shared helper: a dark outline behind a filled path.
void _outlined(
  Canvas canvas,
  Path path,
  Paint fill, {
  double stroke = 3,
  Color color = AppColors.textOutline,
}) {
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..color = color,
  );
  canvas.drawPath(path, fill);
}

/// Crowns: the currency that rebuilds the kingdom.
class CrownIcon extends StatelessWidget {
  const CrownIcon({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ArtIcon(
      asset: AppArt.iconCrown,
      size: size,
      fallback: () => const CustomPaint(
        painter: _CrownPainter(color: AppColors.crown, shadow: true),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter({required this.color, required this.shadow});

  final Color color;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double stroke = math.max(1.2, w * 0.09);

    final Path crown = Path()
      ..moveTo(w * 0.10, h * 0.76)
      ..lineTo(w * 0.04, h * 0.28)
      ..lineTo(w * 0.29, h * 0.50)
      ..lineTo(w * 0.50, h * 0.16)
      ..lineTo(w * 0.71, h * 0.50)
      ..lineTo(w * 0.96, h * 0.28)
      ..lineTo(w * 0.90, h * 0.76)
      ..close();

    if (shadow) {
      canvas.drawPath(
        crown.shift(Offset(0, h * 0.06)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
      );
    }

    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.lerp(color, Colors.white, 0.5)!,
          color,
          Color.lerp(color, Colors.black, 0.25)!,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    _outlined(canvas, crown, fill, stroke: stroke);

    // Band across the base.
    final RRect band = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.74, w * 0.80, h * 0.18),
      Radius.circular(h * 0.06),
    );
    canvas.drawRRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.textOutline,
    );
    canvas.drawRRect(band, fill);

    // Gems.
    for (final double x in <double>[0.30, 0.50, 0.70]) {
      canvas.drawCircle(
        Offset(w * x, h * 0.83),
        h * 0.048,
        Paint()..color = const Color(0xFFFF5C7A),
      );
    }

    // Highlight along the top of the band.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.755, w * 0.68, h * 0.035),
        Radius.circular(h * 0.02),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shadow != shadow;
}

/// Gold coins: the currency that buys boosters and continues.
class CoinIcon extends StatelessWidget {
  const CoinIcon({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ArtIcon(
      asset: AppArt.iconCoins,
      size: size,
      fallback: () => const CustomPaint(painter: _CoinPainter()),
    );
  }
}

/// The XP gem, shown wherever a run's experience is reported.
class XpIcon extends StatelessWidget {
  const XpIcon({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ArtIcon(
      asset: AppArt.iconXp,
      size: size,
      fallback: () => Icon(
        Icons.auto_awesome_rounded,
        size: size,
        color: AppColors.primaryLight,
      ),
    );
  }
}

/// A treasure chest. [mystery] swaps in the closed, glowing variant used for
/// rewards the player has not opened yet.
class ChestIcon extends StatelessWidget {
  const ChestIcon({this.size = 26, this.mystery = false, super.key});

  final double size;
  final bool mystery;

  @override
  Widget build(BuildContext context) {
    return _ArtIcon(
      asset: mystery ? AppArt.iconMysteryChest : AppArt.iconChest,
      size: size,
      fallback: () =>
          Icon(Icons.inventory_2_rounded, size: size, color: AppColors.gold),
    );
  }
}

/// The daily calendar, used on the daily reward and the daily challenge.
class CalendarIcon extends StatelessWidget {
  const CalendarIcon({this.size = 26, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _ArtIcon(
      asset: AppArt.iconCalendar,
      size: size,
      fallback: () =>
          Icon(Icons.calendar_month_rounded, size: size, color: AppColors.gold),
    );
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final Offset c = Offset(r, r);
    final double stroke = math.max(1.2, size.width * 0.08);

    canvas.drawCircle(
      c.translate(0, r * 0.12),
      r * 0.95,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );

    // Rim.
    canvas.drawCircle(
      c,
      r - stroke / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.textOutline,
    );
    canvas.drawCircle(
      c,
      r - stroke / 2,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFE9A0), Color(0xFFD98F0B)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Inner disc, slightly darker, so the coin has a face.
    canvas.drawCircle(
      c,
      r * 0.70,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFD470), Color(0xFFE8A21A)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.7)),
    );

    // Struck crown.
    final double w = size.width * 0.46;
    final double h = size.height * 0.34;
    final double left = c.dx - w / 2;
    final double top = c.dy - h / 2;
    final Path mark = Path()
      ..moveTo(left, top + h)
      ..lineTo(left, top + h * 0.22)
      ..lineTo(left + w * 0.3, top + h * 0.62)
      ..lineTo(left + w * 0.5, top)
      ..lineTo(left + w * 0.7, top + h * 0.62)
      ..lineTo(left + w, top + h * 0.22)
      ..lineTo(left + w, top + h)
      ..close();

    canvas.drawPath(
      mark,
      Paint()..color = AppColors.textOnGold.withValues(alpha: 0.62),
    );

    // Specular glint.
    canvas.drawCircle(
      Offset(c.dx - r * 0.38, c.dy - r * 0.42),
      r * 0.13,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) => false;
}

/// Chunky booster icons: hammer, bomb, shuffle and second chance.
class BoosterIcon extends StatelessWidget {
  const BoosterIcon({required this.type, this.size = 28, super.key});

  final BoosterType type;
  final double size;

  static String _asset(BoosterType type) => switch (type) {
    BoosterType.hammer => AppArt.iconHammer,
    BoosterType.bomb => AppArt.iconBomb,
    BoosterType.shuffle => AppArt.iconShuffle,
    BoosterType.secondChance => AppArt.iconSecondChance,
  };

  @override
  Widget build(BuildContext context) {
    return _ArtIcon(
      asset: _asset(type),
      size: size,
      fallback: () => CustomPaint(painter: _BoosterPainter(type)),
    );
  }
}

class _BoosterPainter extends CustomPainter {
  const _BoosterPainter(this.type);

  final BoosterType type;

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case BoosterType.hammer:
        _hammer(canvas, size);
      case BoosterType.bomb:
        _bomb(canvas, size);
      case BoosterType.shuffle:
        _shuffle(canvas, size);
      case BoosterType.secondChance:
        _heart(canvas, size);
    }
  }

  void _hammer(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double stroke = math.max(1.4, w * 0.085);

    // Handle, running corner to corner.
    final Path handle = Path()
      ..moveTo(w * 0.30, h * 0.86)
      ..lineTo(w * 0.62, h * 0.50)
      ..lineTo(w * 0.76, h * 0.62)
      ..lineTo(w * 0.44, h * 0.96)
      ..close();
    _outlined(
      canvas,
      handle,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFB9793E), Color(0xFF7A4A1C)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
      stroke: stroke,
    );

    // Head.
    final Path head = Path()
      ..moveTo(w * 0.46, h * 0.26)
      ..lineTo(w * 0.86, h * 0.10)
      ..lineTo(w * 0.98, h * 0.38)
      ..lineTo(w * 0.58, h * 0.54)
      ..close();
    _outlined(
      canvas,
      head,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE8EFFA), Color(0xFF8095B5)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
      stroke: stroke,
    );

    // Impact sparks.
    final Paint spark = Paint()
      ..color = AppColors.gold
      ..strokeWidth = math.max(1.2, w * 0.065)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.10, h * 0.30),
      Offset(w * 0.26, h * 0.22),
      spark,
    );
    canvas.drawLine(
      Offset(w * 0.10, h * 0.56),
      Offset(w * 0.26, h * 0.50),
      spark,
    );
  }

  void _bomb(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double stroke = math.max(1.4, w * 0.085);
    final Offset centre = Offset(w * 0.46, h * 0.62);
    final double r = w * 0.32;

    // Fuse.
    final Path fuse = Path()
      ..moveTo(w * 0.62, h * 0.34)
      ..quadraticBezierTo(w * 0.84, h * 0.22, w * 0.76, h * 0.06);
    canvas.drawPath(
      fuse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB98A4A),
    );

    // Spark at the tip.
    canvas.drawCircle(
      Offset(w * 0.76, h * 0.06),
      w * 0.11,
      Paint()..color = AppColors.gold,
    );
    canvas.drawCircle(
      Offset(w * 0.76, h * 0.06),
      w * 0.055,
      Paint()..color = Colors.white,
    );

    // Body.
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.textOutline,
    );
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: <Color>[const Color(0xFF6B7A93), const Color(0xFF1B2436)],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );

    // Highlight.
    canvas.drawCircle(
      centre.translate(-r * 0.36, -r * 0.4),
      r * 0.19,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  void _shuffle(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double stroke = math.max(2.0, w * 0.13);

    final Paint outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + math.max(1.4, w * 0.07)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.textOutline;

    final Paint arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.secondary;

    // Two crossing arrows.
    for (final Path p in <Path>[
      Path()
        ..moveTo(w * 0.14, h * 0.26)
        ..lineTo(w * 0.86, h * 0.76),
      Path()
        ..moveTo(w * 0.14, h * 0.76)
        ..lineTo(w * 0.86, h * 0.26),
    ]) {
      canvas.drawPath(p, outline);
    }
    for (final Path p in <Path>[
      Path()
        ..moveTo(w * 0.14, h * 0.26)
        ..lineTo(w * 0.86, h * 0.76),
      Path()
        ..moveTo(w * 0.14, h * 0.76)
        ..lineTo(w * 0.86, h * 0.26),
    ]) {
      canvas.drawPath(p, arrow);
    }

    // Arrow heads on the right.
    for (final double y in <double>[0.76, 0.26]) {
      final Path head = Path()
        ..moveTo(w * 0.86, h * y)
        ..lineTo(w * 0.62, h * (y > 0.5 ? 0.74 : 0.28))
        ..moveTo(w * 0.86, h * y)
        ..lineTo(w * 0.84, h * (y > 0.5 ? 0.50 : 0.52));
      canvas.drawPath(head, outline);
      canvas.drawPath(head, arrow);
    }
  }

  void _heart(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double stroke = math.max(1.4, w * 0.09);

    final Path heart = Path()
      ..moveTo(w * 0.5, h * 0.88)
      ..cubicTo(w * 0.05, h * 0.58, w * 0.12, h * 0.14, w * 0.5, h * 0.32)
      ..cubicTo(w * 0.88, h * 0.14, w * 0.95, h * 0.58, w * 0.5, h * 0.88)
      ..close();

    _outlined(
      canvas,
      heart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFF8A9E), Color(0xFFD22B47)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
      stroke: stroke,
    );

    // Shine.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.34, h * 0.40),
        width: w * 0.18,
        height: h * 0.13,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_BoosterPainter oldDelegate) => oldDelegate.type != type;
}

/// The accent each booster is tinted with: glow when armed, wash behind its
/// shop row. The icon itself is painted art, so this is only ever the
/// surrounding colour.
Color boosterColor(BoosterType type) => switch (type) {
  BoosterType.hammer => AppColors.info,
  BoosterType.bomb => AppColors.danger,
  BoosterType.shuffle => AppColors.secondary,
  BoosterType.secondChance => AppColors.success,
};

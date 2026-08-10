import 'package:flutter/material.dart';

import '../models/booster.dart';
import '../theme/app_colors.dart';

/// Original vector icons drawn in code.
///
/// Drawing the crown and coin rather than shipping images keeps the bundle
/// small, makes them crisp at any density, and means there is no third-party
/// artwork anywhere in the project. Swapping in finished art later is a matter
/// of replacing these widgets.

/// The game's crown mark: a chunky five-point crown with a gem band.
class CrownIcon extends StatelessWidget {
  const CrownIcon({this.size = 20, this.color, this.shadow = true, super.key});

  final double size;
  final Color? color;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrownPainter(
          color: color ?? AppColors.crown,
          shadow: shadow,
        ),
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

    // Crown silhouette: three peaks over a solid band.
    final Path crown = Path()
      ..moveTo(w * 0.08, h * 0.74)
      ..lineTo(w * 0.02, h * 0.30)
      ..lineTo(w * 0.27, h * 0.50)
      ..lineTo(w * 0.50, h * 0.18)
      ..lineTo(w * 0.73, h * 0.50)
      ..lineTo(w * 0.98, h * 0.30)
      ..lineTo(w * 0.92, h * 0.74)
      ..close();

    final Rect band = Rect.fromLTWH(w * 0.08, h * 0.74, w * 0.84, h * 0.16);
    final RRect bandRect = RRect.fromRectAndRadius(
      band,
      Radius.circular(h * 0.05),
    );

    if (shadow) {
      canvas.drawPath(
        crown.shift(Offset(0, h * 0.045)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.lerp(color, Colors.white, 0.35)!,
          color,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(crown, fill);
    canvas.drawRRect(bandRect, fill);

    // Three gems on the band.
    final Paint gem = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (final double x in <double>[0.28, 0.5, 0.72]) {
      canvas.drawCircle(Offset(w * x, h * 0.82), h * 0.045, gem);
    }
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shadow != shadow;
}

/// A gold coin with a struck crown motif.
class CoinIcon extends StatelessWidget {
  const CoinIcon({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: const _CoinPainter()),
    );
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final Offset centre = Offset(r, r);

    canvas.drawCircle(
      centre.translate(0, r * 0.09),
      r * 0.96,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFE9A8), AppColors.goldDark],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );

    canvas.drawCircle(
      centre,
      r * 0.76,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Small struck crown in the middle.
    final double w = size.width * 0.44;
    final double h = size.height * 0.34;
    final double left = centre.dx - w / 2;
    final double top = centre.dy - h / 2;
    final Path mark = Path()
      ..moveTo(left, top + h)
      ..lineTo(left, top + h * 0.25)
      ..lineTo(left + w * 0.3, top + h * 0.6)
      ..lineTo(left + w * 0.5, top)
      ..lineTo(left + w * 0.7, top + h * 0.6)
      ..lineTo(left + w, top + h * 0.25)
      ..lineTo(left + w, top + h)
      ..close();

    canvas.drawPath(
      mark,
      Paint()..color = AppColors.textOnGold.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) => false;
}

/// Icon for each booster. Material glyphs are used deliberately: they are
/// instantly legible and carry no licensing question.
IconData boosterIcon(BoosterType type) => switch (type) {
  BoosterType.hammer => Icons.gavel_rounded,
  BoosterType.bomb => Icons.brightness_7_rounded,
  BoosterType.shuffle => Icons.shuffle_rounded,
  BoosterType.secondChance => Icons.favorite_rounded,
};

Color boosterColor(BoosterType type) => switch (type) {
  BoosterType.hammer => AppColors.info,
  BoosterType.bomb => AppColors.danger,
  BoosterType.shuffle => AppColors.secondary,
  BoosterType.secondChance => AppColors.success,
};

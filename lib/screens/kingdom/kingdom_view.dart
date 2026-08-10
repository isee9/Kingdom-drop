import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/kingdom_config.dart';
import '../../theme/app_spacing.dart';

/// Renders a kingdom as original vector art.
///
/// Each kingdom is a [KingdomPalette] plus a count of completed upgrades — the
/// same five structures are drawn for every realm, recoloured and re-lit. That
/// keeps ten kingdoms as ten rows of data instead of ten art files, and when
/// finished artwork arrives only this painter changes.
///
/// A structure the player has not paid for yet is drawn cracked and unlit; once
/// bought it straightens up, brightens, and (for the tower and keep) raises a
/// banner.
class KingdomView extends StatelessWidget {
  const KingdomView({
    required this.kingdom,
    required this.upgradesDone,
    this.animateTo,
    super.key,
  });

  final KingdomDefinition kingdom;
  final int upgradesDone;

  /// When set, the structure at this index animates from ruined to restored.
  final int? animateTo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: animateTo == null
            ? CustomPaint(
                painter: _KingdomPainter(
                  palette: kingdom.palette,
                  upgradesDone: upgradesDone,
                ),
              )
            : TweenAnimationBuilder<double>(
                key: ValueKey<int>(animateTo!),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (BuildContext context, double t, _) => CustomPaint(
                  painter: _KingdomPainter(
                    palette: kingdom.palette,
                    upgradesDone: upgradesDone,
                    animatingIndex: animateTo,
                    animationValue: t,
                  ),
                ),
              ),
      ),
    );
  }
}

class _KingdomPainter extends CustomPainter {
  const _KingdomPainter({
    required this.palette,
    required this.upgradesDone,
    this.animatingIndex,
    this.animationValue = 1,
  });

  final KingdomPalette palette;
  final int upgradesDone;
  final int? animatingIndex;
  final double animationValue;

  /// Ground line, as a fraction of height.
  static const double _groundY = 0.80;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    _paintClouds(canvas, size);
    _paintRidges(canvas, size);
    _paintHills(canvas, size);
    _paintGround(canvas, size);
    _paintTrees(canvas, size);
    _paintPath(canvas, size);

    // Back to front.
    _paintCastle(canvas, size, _restoration(4));
    _paintTower(canvas, size, _restoration(3));
    _paintMarket(canvas, size, _restoration(2));
    _paintBridge(canvas, size, _restoration(1));
    _paintGate(canvas, size, _restoration(0));
  }

  /// 0 = ruined, 1 = fully restored, with the in-flight upgrade tweened.
  double _restoration(int index) {
    if (animatingIndex == index) return animationValue;
    return index < upgradesDone ? 1 : 0;
  }

  Color _structureColour(double restoration) =>
      Color.lerp(palette.structure, palette.structureLit, restoration)!;

  void _paintSky(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.sky,
        ).createShader(rect),
    );

    // A scatter of stars, deterministic so the scene does not shimmer between
    // rebuilds.
    final math.Random rng = math.Random(palette.ground.toARGB32());
    final Paint star = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (int i = 0; i < 26; i++) {
      canvas.drawCircle(
        Offset(
          rng.nextDouble() * size.width,
          rng.nextDouble() * size.height * 0.5,
        ),
        rng.nextDouble() * 1.4 + 0.4,
        star,
      );
    }
  }

  /// Soft cloud banks, so the sky is not an empty gradient.
  void _paintClouds(Canvas canvas, Size size) {
    final math.Random rng = math.Random(palette.structure.toARGB32());
    final Paint cloud = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.012);

    for (int i = 0; i < 3; i++) {
      final double cx = size.width * (0.12 + rng.nextDouble() * 0.76);
      final double cy = size.height * (0.10 + rng.nextDouble() * 0.28);
      final double w = size.width * (0.14 + rng.nextDouble() * 0.12);
      final double h = size.height * 0.055;
      for (int b = 0; b < 3; b++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              cx + (b - 1) * w * 0.42,
              cy + (b == 1 ? -h * 0.3 : 0),
            ),
            width: w * (b == 1 ? 1.1 : 0.85),
            height: h * (b == 1 ? 1.3 : 1),
          ),
          cloud,
        );
      }
    }
  }

  /// Distant mountain silhouettes, darker than the hills in front of them.
  void _paintRidges(Canvas canvas, Size size) {
    final double y = size.height * _groundY;
    final Paint far = Paint()
      ..color = Color.lerp(
        palette.sky.last,
        Colors.black,
        0.35,
      )!.withValues(alpha: 0.75);

    final Path ridge = Path()..moveTo(0, y);
    double x = 0;
    final math.Random rng = math.Random(palette.accent.toARGB32());
    while (x < size.width) {
      final double peakW = size.width * (0.16 + rng.nextDouble() * 0.12);
      final double peakH = size.height * (0.14 + rng.nextDouble() * 0.16);
      ridge.lineTo(x + peakW / 2, y - peakH);
      ridge.lineTo(x + peakW, y);
      x += peakW;
    }
    ridge
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ridge, far);
  }

  /// A treeline along the ground, which is what stops the scene reading as
  /// geometry floating on a gradient.
  void _paintTrees(Canvas canvas, Size size) {
    final double y = size.height * _groundY;
    final math.Random rng = math.Random(7);
    final Color trunk = Color.lerp(palette.ground, Colors.black, 0.45)!;
    final Color foliage = Color.lerp(palette.ground, Colors.white, 0.16)!;

    // Left cluster and right cluster, kept clear of the structures.
    for (final double band in <double>[0.02, 0.86]) {
      for (int i = 0; i < 3; i++) {
        final double tx =
            size.width * (band + i * 0.045 + rng.nextDouble() * 0.02);
        final double th = size.height * (0.10 + rng.nextDouble() * 0.06);
        final double tw = th * 0.55;

        canvas.drawRect(
          Rect.fromLTWH(tx - tw * 0.08, y - th * 0.25, tw * 0.16, th * 0.3),
          Paint()..color = trunk,
        );
        for (int layer = 0; layer < 3; layer++) {
          final double lw = tw * (1 - layer * 0.22);
          final double ly = y - th * (0.22 + layer * 0.26);
          canvas.drawPath(
            Path()
              ..moveTo(tx, ly - th * 0.34)
              ..lineTo(tx - lw / 2, ly)
              ..lineTo(tx + lw / 2, ly)
              ..close(),
            Paint()..color = foliage,
          );
        }
      }
    }
  }

  /// A lit path leading to the gate, drawing the eye to the castle.
  void _paintPath(Canvas canvas, Size size) {
    final double y = size.height * _groundY;
    final Path path = Path()
      ..moveTo(size.width * 0.42, y)
      ..lineTo(size.width * 0.58, y)
      ..lineTo(size.width * 0.72, size.height)
      ..lineTo(size.width * 0.28, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Color.lerp(palette.ground, Colors.white, 0.13)!,
    );
  }

  void _paintHills(Canvas canvas, Size size) {
    final double y = size.height * _groundY;
    final Paint far = Paint()
      ..color = Color.lerp(
        palette.ground,
        Colors.white,
        0.10,
      )!.withValues(alpha: 0.55);

    final Path hills = Path()..moveTo(0, y);
    hills.quadraticBezierTo(
      size.width * 0.18,
      y - size.height * 0.22,
      size.width * 0.38,
      y,
    );
    hills.quadraticBezierTo(
      size.width * 0.62,
      y - size.height * 0.28,
      size.width * 0.9,
      y,
    );
    hills.lineTo(size.width, y);
    hills.lineTo(size.width, size.height);
    hills.lineTo(0, size.height);
    hills.close();
    canvas.drawPath(hills, far);
  }

  void _paintGround(Canvas canvas, Size size) {
    final double y = size.height * _groundY;
    canvas.drawRect(
      Rect.fromLTWH(0, y, size.width, size.height - y),
      Paint()..color = palette.ground,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, y, size.width, size.height * 0.012),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
  }

  // ------------------------------------------------------------- structures
  /// The central keep: the fifth and final upgrade.
  void _paintCastle(Canvas canvas, Size size, double restoration) {
    final double y = size.height * _groundY;
    final double w = size.width * 0.26;
    final double h = size.height * 0.46;
    final double left = size.width * 0.37;
    final Color colour = _structureColour(restoration);

    final Rect body = Rect.fromLTWH(left, y - h, w, h);
    _paintWall(canvas, body, colour, restoration);
    _paintBattlements(canvas, body, colour, count: 5);

    // Two flanking turrets.
    for (final double x in <double>[left - w * 0.22, left + w * 0.98]) {
      final Rect turret = Rect.fromLTWH(x, y - h * 0.82, w * 0.24, h * 0.82);
      _paintWall(canvas, turret, colour, restoration);
      _paintRoof(canvas, turret, restoration);
    }

    if (restoration > 0.5) {
      _paintBanner(
        canvas,
        Offset(body.center.dx, body.top - size.height * 0.02),
        size.height * 0.1,
        restoration,
      );
    }
  }

  /// Tall thin tower: the fourth upgrade.
  void _paintTower(Canvas canvas, Size size, double restoration) {
    final double y = size.height * _groundY;
    final double w = size.width * 0.09;
    final double h = size.height * 0.40 * (0.55 + 0.45 * restoration);
    final Rect tower = Rect.fromLTWH(size.width * 0.72, y - h, w, h);

    _paintWall(canvas, tower, _structureColour(restoration), restoration);
    if (restoration > 0.4) _paintRoof(canvas, tower, restoration);
  }

  /// Market stall: the third upgrade.
  void _paintMarket(Canvas canvas, Size size, double restoration) {
    final double y = size.height * _groundY;
    final double w = size.width * 0.15;
    final double h = size.height * 0.16;
    final Rect stall = Rect.fromLTWH(size.width * 0.16, y - h, w, h);

    _paintWall(canvas, stall, _structureColour(restoration), restoration);

    if (restoration > 0.3) {
      // Striped awning, in the kingdom's accent colour.
      final double awningH = h * 0.42;
      final Rect awning = Rect.fromLTWH(
        stall.left - w * 0.1,
        stall.top - awningH * 0.5,
        w * 1.2,
        awningH,
      );
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(awning, Radius.circular(awningH * 0.3)),
      );
      canvas.drawRect(awning, Paint()..color = palette.accent);
      final Paint stripe = Paint()
        ..color = Colors.white.withValues(alpha: 0.55);
      for (double x = awning.left; x < awning.right; x += awning.width / 6) {
        canvas.drawRect(
          Rect.fromLTWH(x, awning.top, awning.width / 12, awning.height),
          stripe,
        );
      }
      canvas.restore();
    }
  }

  /// Bridge over the gorge on the left: the second upgrade.
  void _paintBridge(Canvas canvas, Size size, double restoration) {
    final double y = size.height * _groundY;
    final double left = size.width * 0.015;
    final double right = size.width * 0.155;
    final double deckY = y - size.height * 0.055;
    final Color colour = _structureColour(restoration);

    // The gorge is a permanent feature of the landscape, so it is cut into the
    // ground as a tapering cleft rather than stamped on as a black rectangle.
    final double gorgeLeft = left + size.width * 0.012;
    final double gorgeRight = right - size.width * 0.012;
    final Path gorge = Path()
      ..moveTo(gorgeLeft, y)
      ..lineTo(gorgeRight, y)
      ..lineTo(gorgeRight - size.width * 0.018, size.height)
      ..lineTo(gorgeLeft + size.width * 0.014, size.height)
      ..close();

    canvas.drawPath(
      gorge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(palette.ground, Colors.black, 0.55)!,
            Color.lerp(palette.ground, Colors.black, 0.85)!,
          ],
        ).createShader(Rect.fromLTRB(gorgeLeft, y, gorgeRight, size.height)),
    );

    // A lip of lit ground along each edge so the cleft reads as depth.
    final Paint lip = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = math.max(1, size.height * 0.006);
    canvas.drawLine(Offset(gorgeLeft, y), Offset(gorgeRight, y), lip);

    final double deckThickness = size.height * 0.018;
    final Paint deck = Paint()
      ..color = colour
      ..strokeWidth = deckThickness
      ..strokeCap = StrokeCap.round;

    if (restoration >= 0.99) {
      canvas.drawLine(Offset(left, deckY), Offset(right, deckY), deck);

      // Railings only exist once the bridge is actually usable.
      final Paint rail = Paint()
        ..color = Color.lerp(colour, Colors.white, 0.25)!
        ..strokeWidth = math.max(1, size.height * 0.007)
        ..strokeCap = StrokeCap.round;
      final double railTop = deckY - size.height * 0.035;
      canvas.drawLine(Offset(left, railTop), Offset(right, railTop), rail);
      for (int i = 0; i <= 3; i++) {
        final double x = left + (right - left) * i / 3;
        canvas.drawLine(Offset(x, railTop), Offset(x, deckY), rail);
      }
    } else {
      // Broken: two stubs with a gap that closes as the repair lands, and a
      // couple of fallen planks in the cleft below.
      final double gap = (1 - restoration) * (right - left) * 0.5;
      final double mid = (left + right) / 2;
      canvas.drawLine(Offset(left, deckY), Offset(mid - gap / 2, deckY), deck);
      canvas.drawLine(Offset(mid + gap / 2, deckY), Offset(right, deckY), deck);

      final Paint plank = Paint()
        ..color = colour.withValues(alpha: 0.5)
        ..strokeWidth = math.max(1, size.height * 0.009)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(mid - size.width * 0.02, y + size.height * 0.05),
        Offset(mid + size.width * 0.01, y + size.height * 0.09),
        plank,
      );
    }

    // Support pier dropping into the cleft.
    canvas.drawLine(
      Offset((left + right) / 2, deckY),
      Offset((left + right) / 2, y + size.height * 0.10),
      Paint()
        ..color = colour.withValues(alpha: 0.6)
        ..strokeWidth = size.height * 0.012,
    );
  }

  /// The gate in front of the keep: the first upgrade.
  void _paintGate(Canvas canvas, Size size, double restoration) {
    final double y = size.height * _groundY;
    final double w = size.width * 0.13;
    final double h = size.height * 0.20;
    final Rect gate = Rect.fromLTWH(size.width * 0.435, y - h, w, h);
    final Color colour = _structureColour(restoration);

    // Arch.
    final Path arch = Path()
      ..moveTo(gate.left, gate.bottom)
      ..lineTo(gate.left, gate.top + gate.height * 0.35)
      ..arcToPoint(
        Offset(gate.right, gate.top + gate.height * 0.35),
        radius: Radius.circular(gate.width / 2),
      )
      ..lineTo(gate.right, gate.bottom)
      ..close();

    canvas.drawPath(
      arch,
      Paint()..color = Color.lerp(colour, Colors.black, 0.45)!,
    );

    // Doors, which swing shut as the gate is repaired.
    final double doorInset = gate.width * 0.12;
    final Rect doors = Rect.fromLTRB(
      gate.left + doorInset,
      gate.top + gate.height * 0.30,
      gate.right - doorInset,
      gate.bottom,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        doors.left,
        doors.top,
        doors.width * restoration.clamp(0.15, 1),
        doors.height,
      ),
      Paint()..color = colour,
    );

    if (restoration < 0.99) {
      // Rubble at the foot of a gate that has not been repaired.
      final Paint rubble = Paint()
        ..color = Color.lerp(palette.ground, Colors.black, 0.25)!;
      final math.Random rng = math.Random(11);
      for (int i = 0; i < 6; i++) {
        canvas.drawCircle(
          Offset(
            gate.left + rng.nextDouble() * gate.width,
            gate.bottom - rng.nextDouble() * size.height * 0.015,
          ),
          size.height * (0.008 + rng.nextDouble() * 0.01),
          rubble,
        );
      }
    }
  }

  // ------------------------------------------------------------------ parts
  void _paintWall(Canvas canvas, Rect rect, Color colour, double restoration) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(colour, Colors.white, 0.18)!,
            colour,
            Color.lerp(colour, Colors.black, 0.28)!,
          ],
        ).createShader(rect),
    );

    if (restoration > 0.6) {
      // Lit windows once the building is in use.
      final Paint glow = Paint()..color = palette.accent.withValues(alpha: 0.9);
      final int cols = math.max(1, (rect.width / (rect.width * 0.42)).floor());
      final int rows = math.max(
        1,
        (rect.height / (rect.height * 0.34)).floor(),
      );
      final double ww = rect.width * 0.16;
      final double wh = rect.height * 0.13;
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                rect.left + rect.width * (0.24 + c * 0.42),
                rect.top + rect.height * (0.22 + r * 0.34),
                ww,
                wh,
              ),
              Radius.circular(ww * 0.3),
            ),
            glow,
          );
        }
      }
    } else {
      // Cracks while it is still a ruin.
      final Paint crack = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..strokeWidth = math.max(1, rect.width * 0.03)
        ..style = PaintingStyle.stroke;
      final Path path = Path()
        ..moveTo(rect.left + rect.width * 0.3, rect.top)
        ..lineTo(rect.left + rect.width * 0.45, rect.top + rect.height * 0.4)
        ..lineTo(rect.left + rect.width * 0.28, rect.top + rect.height * 0.7);
      canvas.drawPath(path, crack);
    }
  }

  void _paintBattlements(
    Canvas canvas,
    Rect rect,
    Color colour, {
    required int count,
  }) {
    final double w = rect.width / (count * 2 - 1);
    final double h = rect.height * 0.09;
    final Paint paint = Paint()..color = Color.lerp(colour, Colors.white, 0.1)!;

    for (int i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left + i * w * 2, rect.top - h, w, h),
        paint,
      );
    }
  }

  void _paintRoof(Canvas canvas, Rect rect, double restoration) {
    final double h = rect.height * 0.22;
    final Path roof = Path()
      ..moveTo(rect.left - rect.width * 0.16, rect.top)
      ..lineTo(rect.center.dx, rect.top - h)
      ..lineTo(rect.right + rect.width * 0.16, rect.top)
      ..close();

    canvas.drawPath(
      roof,
      Paint()
        ..color = Color.lerp(
          palette.accent,
          palette.structureLit,
          1 - restoration,
        )!,
    );
  }

  void _paintBanner(
    Canvas canvas,
    Offset top,
    double height,
    double restoration,
  ) {
    final Paint pole = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    canvas.drawLine(top, top.translate(0, -height), pole);

    final double flagW = height * 0.7 * restoration;
    final Path flag = Path()
      ..moveTo(top.dx, top.dy - height)
      ..lineTo(top.dx + flagW, top.dy - height * 0.82)
      ..lineTo(top.dx, top.dy - height * 0.62)
      ..close();

    canvas.drawPath(flag, Paint()..color = palette.accent);
  }

  @override
  bool shouldRepaint(_KingdomPainter oldDelegate) =>
      oldDelegate.upgradesDone != upgradesDone ||
      oldDelegate.animationValue != animationValue ||
      oldDelegate.animatingIndex != animatingIndex ||
      oldDelegate.palette != palette;
}

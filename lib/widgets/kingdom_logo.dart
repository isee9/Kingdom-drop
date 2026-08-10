import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The Kingdom Drop mark: a crown built out of puzzle blocks.
///
/// This is the app's identity — it appears on the splash, in the icon, and as
/// the header on the home screen. Drawn in code so it stays sharp at any size
/// and can be rendered straight to PNG by `tool/generate_icons.dart`.
class KingdomLogo extends StatelessWidget {
  const KingdomLogo({this.size = 120, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: const KingdomLogoPainter()),
    );
  }
}

/// Paints the mark into any square canvas.
class KingdomLogoPainter extends CustomPainter {
  const KingdomLogoPainter({this.withBackground = false});

  /// Draws the dark royal plate behind the crown. Used for the app icon, where
  /// the mark needs its own ground; off in-app, where the screen provides it.
  final bool withBackground;

  /// Which grid cells are filled, as a 5-wide by 4-tall crown built from
  /// blocks. Row 0 is the top of the crown.
  ///
  /// ```
  ///   X . X . X     three points
  ///   X X X X X     the body
  ///   X X X X X
  ///   . X X X .     the tapered base
  /// ```
  static const List<String> _grid = <String>[
    'X.X.X',
    'XXXXX',
    'XXXXX',
    '.XXX.',
  ];

  /// Colour index per cell, so the crown reads as puzzle blocks rather than one
  /// solid shape. -1 means "use gold".
  static const List<String> _tint = <String>[
    '0.1.2',
    '33333',
    '44544',
    '.333.',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double side = size.shortestSide;

    if (withBackground) {
      final Rect rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF2A1F5E), Color(0xFF150F35)],
          ).createShader(rect),
      );
    }

    // The mark occupies the middle 76% of the canvas so an icon has breathing
    // room inside the platform's rounded mask.
    final double margin = side * (withBackground ? 0.14 : 0.02);
    final double usable = side - margin * 2;
    final double cell = usable / 5;
    final double gridHeight = cell * _grid.length;
    final double top = margin + (usable - gridHeight) / 2;

    for (int r = 0; r < _grid.length; r++) {
      for (int c = 0; c < 5; c++) {
        if (_grid[r][c] != 'X') continue;

        final Rect cellRect = Rect.fromLTWH(
          margin + c * cell,
          top + r * cell,
          cell,
          cell,
        );
        _paintBlock(canvas, cellRect, _colourFor(r, c));
      }
    }
  }

  Color _colourFor(int row, int col) {
    final String code = _tint[row][col];
    if (code == '5') return AppColors.gold;
    final int index = int.tryParse(code) ?? 0;
    return AppColors.blocks[index % AppColors.blocks.length];
  }

  void _paintBlock(Canvas canvas, Rect cell, Color colour) {
    final Rect rect = cell.deflate(cell.width * 0.06);
    final double radius = rect.width * 0.22;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.drawRRect(
      rrect.shift(Offset(0, rect.height * 0.05)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(colour, Colors.white, 0.28)!,
            colour,
            Color.lerp(colour, Colors.black, 0.22)!,
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(rect),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + rect.width * 0.16,
          rect.top + rect.height * 0.12,
          rect.width * 0.68,
          rect.height * 0.2,
        ),
        Radius.circular(radius * 0.6),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(KingdomLogoPainter oldDelegate) =>
      oldDelegate.withBackground != withBackground;
}

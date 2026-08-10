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
  const KingdomLogoPainter({this.withBackground = false, this.marginFraction});

  /// Draws the dark royal plate behind the crown. Used for the app icon, where
  /// the mark needs its own ground; off in-app, where the screen provides it.
  final bool withBackground;

  /// Overrides how much of the canvas is left empty around the mark, as a
  /// fraction of the shorter side. Android's adaptive icon crops to a centred
  /// safe zone, so its foreground layer needs a much larger margin than a
  /// square icon does.
  final double? marginFraction;

  /// Which grid cells are filled: a 5-wide, 4-tall crown built from blocks.
  ///
  /// ```
  ///   X . X . X     three spikes, the gaps reading as the crown's notches
  ///   X X X X X     body
  ///   X X X X X     body
  ///   X X X X X     full-width band
  /// ```
  ///
  /// The band runs the full width on purpose. An earlier version tapered it
  /// inwards, which made the whole mark read as a cross rather than a crown.
  static const List<String> _grid = <String>[
    'X.X.X',
    'XXXXX',
    'XXXXX',
    'XXXXX',
  ];

  /// Colour index per cell. The crown is mostly gold — it is a crown — with
  /// coloured spike tips and two gems in the band so it still reads as
  /// something built out of puzzle blocks.
  static const List<String> _tint = <String>[
    '0.1.2',
    '33333',
    '33333',
    '34343',
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
            colors: <Color>[Color(0xFF1B3A6B), Color(0xFF0A142E)],
          ).createShader(rect),
      );
    }

    // The mark occupies the middle of the canvas so an icon has breathing room
    // inside the platform's rounded mask.
    final double margin =
        side * (marginFraction ?? (withBackground ? 0.14 : 0.02));
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
      oldDelegate.withBackground != withBackground ||
      oldDelegate.marginFraction != marginFraction;
}

/// The wordmark: three-dimensional carved lettering.
///
/// The depth is faked the way sign painters fake it — the word is drawn several
/// times, each copy stepped further down and darker, then the lit face goes on
/// top with a metal gradient and a dark outline. Cheap, and it reads as carved
/// metal at any size, which a plain bold font never does.
class KingdomWordmark extends StatelessWidget {
  const KingdomWordmark({required this.fontSize, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ExtrudedWord(
          'KINGDOM',
          fontSize: fontSize,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFFFF0B8), Color(0xFFFFB61F)],
          ),
        ),
        SizedBox(height: fontSize * 0.14),
        _ExtrudedWord(
          'DROP',
          fontSize: fontSize,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFEAF2FF), Color(0xFF9FC0F5)],
          ),
        ),
      ],
    );
  }
}

class _ExtrudedWord extends StatelessWidget {
  const _ExtrudedWord(
    this.text, {
    required this.fontSize,
    required this.gradient,
  });

  final String text;
  final double fontSize;
  final Gradient gradient;

  /// How many shadow copies form the extrusion.
  static const int _depth = 5;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: fontSize * 0.06,
      height: 1,
    );

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        // Extrusion: darker copies stepping downward.
        for (int i = _depth; i >= 1; i--)
          Transform.translate(
            offset: Offset(0, i * (fontSize * 0.045)),
            child: Text(
              text,
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = fontSize * 0.16
                  ..strokeJoin = StrokeJoin.round
                  ..color = Color.lerp(
                    const Color(0xFF6B3E02),
                    const Color(0xFF2A1600),
                    i / _depth,
                  )!,
              ),
            ),
          ),
        // Dark outline around the lit face.
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.14
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF2A1600),
          ),
        ),
        // Lit face.
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) => gradient.createShader(bounds),
          child: Text(text, style: base.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}

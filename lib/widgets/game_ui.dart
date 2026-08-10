import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The visual language that makes Kingdom Drop read as a game rather than an
/// app.
///
/// Three ideas do most of the work, and everything here is one of them:
///
/// * **Physical slabs.** Buttons are solid objects with a visible bottom edge
///   that compresses when pressed, not tinted rectangles.
/// * **Framed panels.** Content sits inside a metal frame with a lit top edge
///   and a shadowed interior, so panels feel inset into the screen.
/// * **Outlined lettering.** Display text carries a dark stroke and a drop
///   shadow so it stays legible over colour and never looks like body copy.
///
/// All of it is painted in code: no nine-patch images, no raster frames, so it
/// stays sharp at any density and re-skins from [AppColors].

/// Display text with an outline and drop shadow.
///
/// Flutter cannot stroke and fill one [Text] at once, so this stacks two: the
/// lower one painted as a thick stroke, the upper one filled. That is the
/// standard trick and it is why casual-game headings pop off the background.
class StrokedText extends StatelessWidget {
  const StrokedText(
    this.text, {
    required this.style,
    this.strokeWidth = 4,
    this.strokeColor = AppColors.textOutline,
    this.fillGradient,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
    this.shadow = true,
    super.key,
  });

  final String text;
  final TextStyle style;
  final double strokeWidth;
  final Color strokeColor;

  /// Optional gradient for the fill, used for gold headings.
  final Gradient? fillGradient;

  final TextAlign textAlign;
  final int maxLines;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final TextStyle strokeStyle = style.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = strokeColor,
      shadows: shadow
          ? <Shadow>[
              Shadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );

    return Stack(
      children: <Widget>[
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: strokeStyle,
        ),
        if (fillGradient != null)
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (Rect bounds) => fillGradient!.createShader(bounds),
            child: Text(
              text,
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(color: Colors.white),
            ),
          )
        else
          Text(
            text,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
      ],
    );
  }
}

/// Paints the framed-panel treatment: a metal edge, a lit top bevel and a
/// gently graded interior.
class PanelFramePainter extends CustomPainter {
  const PanelFramePainter({
    required this.radius,
    this.frameColor = AppColors.gold,
    this.frameEdgeColor = AppColors.goldEdge,
    this.interior = AppColors.panelGradient,
    this.frameWidth = 3,
    this.studs = false,
  });

  final double radius;
  final Color frameColor;
  final Color frameEdgeColor;
  final Gradient interior;
  final double frameWidth;

  /// Small dots in the corners. Used on the most important panels only —
  /// everywhere would be fussy.
  final bool studs;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect outer = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Dark rim, so the frame is not floating on the background.
    canvas.drawRRect(
      outer,
      Paint()..color = frameEdgeColor.withValues(alpha: 0.95),
    );

    // The metal frame itself, brighter at the top where light would fall.
    final RRect frame = RRect.fromRectAndRadius(
      rect.deflate(1.5),
      Radius.circular(radius - 1.5),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(frameColor, Colors.white, 0.45)!,
            frameColor,
            Color.lerp(frameColor, Colors.black, 0.28)!,
          ],
          stops: const <double>[0, 0.4, 1],
        ).createShader(rect),
    );

    // Interior well.
    final Rect innerRect = rect.deflate(frameWidth + 1.5);
    final double innerRadius = (radius - frameWidth - 1.5).clamp(2.0, radius);
    final RRect inner = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(innerRadius),
    );
    canvas.drawRRect(inner, Paint()..shader = interior.createShader(innerRect));

    // Shadow cast by the frame onto the interior, which is what sells "inset".
    canvas.saveLayer(rect, Paint());
    canvas.drawRRect(
      inner,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawRRect(inner.deflate(3), Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    if (studs) {
      final Paint stud = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Color.lerp(frameColor, Colors.white, 0.6)!,
            frameColor,
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 4));
      final double inset = radius * 0.62;
      for (final Offset c in <Offset>[
        Offset(inset, inset),
        Offset(size.width - inset, inset),
        Offset(inset, size.height - inset),
        Offset(size.width - inset, size.height - inset),
      ]) {
        canvas.drawCircle(c, 2.6, stud);
      }
    }
  }

  @override
  bool shouldRepaint(PanelFramePainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.frameColor != frameColor ||
      oldDelegate.frameWidth != frameWidth ||
      oldDelegate.studs != studs;
}

/// A panel with a metal frame around it.
class GamePanel extends StatelessWidget {
  const GamePanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.radius = AppRadius.lg,
    this.frameColor = AppColors.gold,
    this.frameEdgeColor = AppColors.goldEdge,
    this.interior = AppColors.panelGradient,
    this.frameWidth = 3,
    this.studs = false,
    this.onTap,
    super.key,
  });

  /// A quieter frame for secondary content, so gold stays meaningful.
  const GamePanel.plain({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.radius = AppRadius.lg,
    this.interior = AppColors.panelGradient,
    this.onTap,
    super.key,
  }) : frameColor = AppColors.surfaceHigh,
       frameEdgeColor = AppColors.surfaceSunken,
       frameWidth = 2,
       studs = false;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color frameColor;
  final Color frameEdgeColor;
  final Gradient interior;
  final double frameWidth;
  final bool studs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(
        painter: PanelFramePainter(
          radius: radius,
          frameColor: frameColor,
          frameEdgeColor: frameEdgeColor,
          interior: interior,
          frameWidth: frameWidth,
          studs: studs,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (onTap != null) panel = _Pressable(onTap: onTap!, child: panel);
    return margin == null ? panel : Padding(padding: margin!, child: panel);
  }
}

/// Scale-on-press wrapper shared by panels and chips.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.instant,
    lowerBound: 0,
    upperBound: 0.035,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: _controller.reverse,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) =>
            Transform.scale(scale: 1 - _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Paints a chunky button slab: a dark outline, a coloured face with a gloss
/// highlight, and a solid bottom edge that reads as thickness.
class ButtonSlabPainter extends CustomPainter {
  const ButtonSlabPainter({
    required this.gradient,
    required this.edgeColor,
    required this.radius,
    required this.depth,
    required this.pressed,
    this.outlineColor = AppColors.textOutline,
  });

  final Gradient gradient;

  /// The colour of the slab's side, darker than the face.
  final Color edgeColor;
  final double radius;

  /// How thick the bottom edge is when the button is at rest.
  final double depth;

  /// 0 at rest, 1 fully pressed. The face sinks onto the edge.
  final double pressed;

  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double sink = depth * pressed;
    final double faceTop = sink;
    final double faceHeight = size.height - depth;

    final Rect body = Rect.fromLTWH(0, faceTop, size.width, size.height - sink);
    final RRect bodyRRect = RRect.fromRectAndRadius(
      body,
      Radius.circular(radius),
    );

    // Outline first: everything else draws inside it.
    canvas.drawRRect(bodyRRect.inflate(2), Paint()..color = outlineColor);

    // The side of the slab.
    canvas.drawRRect(bodyRRect, Paint()..color = edgeColor);

    // The face sits on top of the side.
    final Rect face = Rect.fromLTWH(0, faceTop, size.width, faceHeight);
    final RRect faceRRect = RRect.fromRectAndRadius(
      face,
      Radius.circular(radius),
    );
    canvas.drawRRect(faceRRect, Paint()..shader = gradient.createShader(face));

    // Gloss across the upper half.
    final Rect gloss = Rect.fromLTWH(
      face.left + face.width * 0.06,
      face.top + face.height * 0.10,
      face.width * 0.88,
      face.height * 0.36,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(gloss, Radius.circular(radius * 0.7)),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(ButtonSlabPainter oldDelegate) =>
      oldDelegate.pressed != pressed ||
      oldDelegate.gradient != gradient ||
      oldDelegate.edgeColor != edgeColor ||
      oldDelegate.depth != depth ||
      oldDelegate.radius != radius;
}

/// A small framed chip, used for currency readouts and counters.
class GameChip extends StatelessWidget {
  const GameChip({
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 6,
    ),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget chip = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF13264C), Color(0xFF091834)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    return onTap == null ? chip : _Pressable(onTap: onTap!, child: chip);
  }
}

/// A banner headline on a ribbon, for moments like GAME OVER.
class RibbonBanner extends StatelessWidget {
  const RibbonBanner({
    required this.text,
    this.color = AppColors.danger,
    this.edgeColor = AppColors.dangerDark,
    this.width = 260,
    super.key,
  });

  final String text;
  final Color color;
  final Color edgeColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 62,
      child: CustomPaint(
        painter: _RibbonPainter(color: color, edgeColor: edgeColor),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: StrokedText(
              text,
              strokeWidth: 4,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({required this.color, required this.edgeColor});

  final Color color;
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double tailW = size.width * 0.09;
    final double bodyTop = size.height * 0.12;
    final double bodyBottom = size.height * 0.88;

    // Folded tails behind the body, which is what makes it read as a ribbon.
    final Paint tailPaint = Paint()..color = edgeColor;
    canvas.drawPath(
      Path()
        ..moveTo(0, bodyTop - 6)
        ..lineTo(tailW * 1.6, bodyTop)
        ..lineTo(tailW * 1.6, bodyBottom)
        ..lineTo(0, size.height)
        ..lineTo(tailW * 0.55, (bodyTop + bodyBottom) / 2)
        ..close(),
      tailPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width, bodyTop - 6)
        ..lineTo(size.width - tailW * 1.6, bodyTop)
        ..lineTo(size.width - tailW * 1.6, bodyBottom)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width - tailW * 0.55, (bodyTop + bodyBottom) / 2)
        ..close(),
      tailPaint,
    );

    final Rect body = Rect.fromLTRB(
      tailW,
      bodyTop,
      size.width - tailW,
      bodyBottom,
    );
    final RRect bodyRRect = RRect.fromRectAndRadius(
      body,
      const Radius.circular(8),
    );

    canvas.drawRRect(
      bodyRRect.inflate(2.5),
      Paint()..color = AppColors.textOutline,
    );
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(color, Colors.white, 0.28)!,
            color,
            edgeColor,
          ],
        ).createShader(body),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.edgeColor != edgeColor;
}

/// The app background: a graded sky with a vignette, so screens have depth
/// instead of being a flat fill.
class GameBackground extends StatelessWidget {
  const GameBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: DecoratedBox(
        // Corner darkening pulls the eye to the middle of the screen, where
        // the board and the buttons are.
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 1.1,
            colors: <Color>[
              Colors.transparent,
              Colors.black.withValues(alpha: 0.45),
            ],
            stops: const <double>[0.55, 1],
          ),
        ),
        child: child,
      ),
    );
  }
}

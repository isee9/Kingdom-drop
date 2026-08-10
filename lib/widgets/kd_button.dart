import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'game_ui.dart';

enum KdButtonSize { small, medium, large, hero }

/// The app's only button.
///
/// Drawn as a physical slab: a dark outline, a glossy coloured face and a solid
/// bottom edge. Pressing sinks the face onto that edge rather than just fading
/// it, which is the single biggest thing separating a game button from an app
/// button.
class KdButton extends StatefulWidget {
  const KdButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient,
    this.color,
    this.size = KdButtonSize.medium,
    this.expand = false,
    this.enabled = true,
    this.badge,
    this.semanticLabel,
    super.key,
  });

  /// Secondary styling: a hollow slab with a metal rim.
  const KdButton.ghost({
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = KdButtonSize.medium,
    this.expand = false,
    this.enabled = true,
    this.badge,
    this.semanticLabel,
    super.key,
  }) : gradient = null,
       color = Colors.transparent;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient? gradient;
  final Color? color;
  final KdButtonSize size;
  final bool expand;
  final bool enabled;

  /// Small pill on the trailing edge, e.g. a price or a count.
  final String? badge;

  final String? semanticLabel;

  @override
  State<KdButton> createState() => _KdButtonState();
}

class _KdButtonState extends State<KdButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: AppDurations.instant,
  );

  bool get _interactive => widget.enabled && widget.onPressed != null;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  double get _height => switch (widget.size) {
    KdButtonSize.small => 42,
    KdButtonSize.medium => 54,
    KdButtonSize.large => 62,
    KdButtonSize.hero => 78,
  };

  double get _fontSize => switch (widget.size) {
    KdButtonSize.small => 13,
    KdButtonSize.medium => 15,
    KdButtonSize.large => 17,
    KdButtonSize.hero => 26,
  };

  double get _radius => switch (widget.size) {
    KdButtonSize.small => AppRadius.md,
    KdButtonSize.medium => AppRadius.lg,
    KdButtonSize.large => AppRadius.lg,
    KdButtonSize.hero => AppRadius.xl,
  };

  /// Thickness of the slab's bottom edge.
  double get _depth => switch (widget.size) {
    KdButtonSize.small => 4,
    KdButtonSize.medium => 5,
    KdButtonSize.large => 6,
    KdButtonSize.hero => 8,
  };

  /// The face gradient, and the darker colour used for the slab's side.
  (Gradient, Color) get _palette {
    if (widget.gradient != null) {
      final Gradient g = widget.gradient!;
      return (g, _edgeFor(g.colors.last));
    }
    if (widget.color != null && widget.color != Colors.transparent) {
      final Color c = widget.color!;
      return (
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_lighten(c), c],
        ),
        _edgeFor(c),
      );
    }
    return (AppColors.primaryGradient, _edgeFor(AppColors.primaryDark));
  }

  static Color _lighten(Color c) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.14).clamp(0.0, 1.0)).toColor();
  }

  static Color _edgeFor(Color c) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - 0.20).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.08).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final bool ghost = widget.color == Colors.transparent;
    final (Gradient gradient, Color edge) = _palette;

    return Semantics(
      button: true,
      enabled: _interactive,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        onTapDown: _interactive ? (_) => _press.forward() : null,
        onTapUp: _interactive ? (_) => _press.reverse() : null,
        onTapCancel: _interactive ? _press.reverse : null,
        onTap: _interactive ? widget.onPressed : null,
        child: AnimatedOpacity(
          duration: AppDurations.fast,
          opacity: _interactive ? 1 : 0.5,
          child: SizedBox(
            height: _height,
            width: widget.expand ? double.infinity : null,
            child: AnimatedBuilder(
              animation: _press,
              builder: (BuildContext context, Widget? child) {
                final double t = _press.value;
                return CustomPaint(
                  painter: ghost
                      ? null
                      : ButtonSlabPainter(
                          gradient: gradient,
                          edgeColor: edge,
                          radius: _radius,
                          depth: _depth,
                          pressed: t,
                        ),
                  foregroundPainter: ghost
                      ? _GhostRimPainter(radius: _radius, pressed: t)
                      : null,
                  child: Padding(
                    // The label rides down with the face when pressed and sits
                    // above the bottom edge at rest.
                    padding: EdgeInsets.only(
                      top: _depth * t,
                      bottom: _depth * (1 - t),
                    ),
                    child: child,
                  ),
                );
              },
              child: _buildLabel(ghost),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(bool ghost) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.size == KdButtonSize.hero
            ? AppSpacing.xxl
            : AppSpacing.lg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (widget.icon != null) ...<Widget>[
            Icon(
              widget.icon,
              size: _fontSize + 5,
              color: Colors.white,
              shadows: const <Shadow>[
                Shadow(
                  color: Colors.black54,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          // Scale down rather than ellipsing: a call to action reading
          // "DOUBLE REWARDS — WATC…" is worse than one a point smaller. This
          // also absorbs large text settings and longer translations.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: StrokedText(
                widget.label,
                strokeWidth: widget.size == KdButtonSize.hero ? 5 : 3.5,
                style: AppTextStyles.button.copyWith(
                  fontSize: _fontSize,
                  letterSpacing: widget.size == KdButtonSize.hero ? 2 : 1,
                  color: ghost ? AppColors.textSecondary : Colors.white,
                ),
              ),
            ),
          ),
          if (widget.badge != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Text(
                widget.badge!,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hollow slab: a metal rim with nothing inside, for secondary actions.
class _GhostRimPainter extends CustomPainter {
  const _GhostRimPainter({required this.radius, required this.pressed});

  final double radius;
  final double pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(2),
      Radius.circular(radius),
    );

    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withValues(alpha: 0.28 - 0.1 * pressed),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.borderStrong,
    );
  }

  @override
  bool shouldRepaint(_GhostRimPainter oldDelegate) =>
      oldDelegate.pressed != pressed || oldDelegate.radius != radius;
}

/// Circular icon button used for settings, close and back affordances.
class KdIconButton extends StatelessWidget {
  const KdIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 46,
    this.background,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                background ?? AppColors.surfaceHigh,
                AppColors.surfaceLow,
              ],
            ),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.55),
              width: 1.6,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: size * 0.5,
            color: AppColors.textPrimary,
            shadows: const <Shadow>[
              Shadow(
                color: Colors.black54,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

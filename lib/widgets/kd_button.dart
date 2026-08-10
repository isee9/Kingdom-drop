import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum KdButtonSize { small, medium, large, hero }

/// The app's only button.
///
/// Everything interactive routes through here so press feel, tap-target size
/// and disabled treatment stay identical across screens. The press animation is
/// a scale-down driven by a local controller, which is cheap: only this
/// subtree rebuilds.
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

  /// Secondary styling: transparent with a border.
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

  /// Small pill drawn on the trailing edge, e.g. a price or a count.
  final String? badge;

  final String? semanticLabel;

  @override
  State<KdButton> createState() => _KdButtonState();
}

class _KdButtonState extends State<KdButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.instant,
    lowerBound: 0,
    upperBound: 0.06,
  );

  bool get _interactive => widget.enabled && widget.onPressed != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _height => switch (widget.size) {
    KdButtonSize.small => 40,
    KdButtonSize.medium => 52,
    KdButtonSize.large => 60,
    KdButtonSize.hero => 74,
  };

  double get _fontSize => switch (widget.size) {
    KdButtonSize.small => 13,
    KdButtonSize.medium => 15,
    KdButtonSize.large => 17,
    KdButtonSize.hero => 24,
  };

  double get _radius => switch (widget.size) {
    KdButtonSize.small => AppRadius.md,
    KdButtonSize.medium => AppRadius.lg,
    KdButtonSize.large => AppRadius.lg,
    KdButtonSize.hero => AppRadius.xl,
  };

  @override
  Widget build(BuildContext context) {
    final bool ghost = widget.color == Colors.transparent;
    final Gradient? gradient = ghost
        ? null
        : (widget.gradient ??
              (widget.color == null
                  ? AppColors.primaryGradient
                  : LinearGradient(
                      colors: <Color>[widget.color!, widget.color!],
                    )));

    return Semantics(
      button: true,
      enabled: _interactive,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        onTapDown: _interactive ? (_) => _controller.forward() : null,
        onTapUp: _interactive ? (_) => _controller.reverse() : null,
        onTapCancel: _interactive ? _controller.reverse : null,
        onTap: _interactive ? widget.onPressed : null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) => Transform.scale(
            scale: 1 - _controller.value,
            child: child,
          ),
          child: AnimatedOpacity(
            duration: AppDurations.fast,
            opacity: _interactive ? 1 : 0.45,
            child: Container(
              height: _height,
              width: widget.expand ? double.infinity : null,
              padding: EdgeInsets.symmetric(
                horizontal: widget.size == KdButtonSize.hero
                    ? AppSpacing.xxl
                    : AppSpacing.xl,
              ),
              decoration: BoxDecoration(
                gradient: gradient,
                color: ghost ? Colors.transparent : null,
                borderRadius: BorderRadius.circular(_radius),
                border: ghost
                    ? Border.all(color: AppColors.borderStrong, width: 1.5)
                    : null,
                boxShadow: ghost || !_interactive
                    ? null
                    : <BoxShadow>[
                        BoxShadow(
                          color: (widget.color ?? AppColors.primaryDark)
                              .withValues(alpha: 0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (widget.icon != null) ...<Widget>[
                    Icon(widget.icon, size: _fontSize + 4, color: Colors.white),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // Scale down rather than ellipsing: a call to action that
                  // reads "DOUBLE REWARDS — WATC…" is worse than one a point
                  // or two smaller, and this also absorbs large text settings
                  // and longer translations.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.button.copyWith(
                          fontSize: _fontSize,
                          letterSpacing: widget.size == KdButtonSize.hero
                              ? 2.5
                              : 1.1,
                        ),
                      ),
                    ),
                  ),
                  if (widget.badge != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        widget.badge!,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon button used for settings, close and back affordances.
class KdIconButton extends StatelessWidget {
  const KdIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.background = AppColors.surface,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.5, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

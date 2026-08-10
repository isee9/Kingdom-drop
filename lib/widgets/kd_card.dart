import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Rounded surface panel. The app's standard container.
class KdCard extends StatelessWidget {
  const KdCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.color,
    this.gradient,
    this.radius = AppRadius.lg,
    this.onTap,
    this.borderColor,
    this.elevated = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: elevated
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTap == null
          ? content
          : _PressableCard(onTap: onTap!, child: content),
    );
  }
}

/// Adds the scale-on-press feel to a tappable card.
class _PressableCard extends StatefulWidget {
  const _PressableCard({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
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

/// Section heading used above grouped content.
class KdSectionHeader extends StatelessWidget {
  const KdSectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.md,
        left: AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Rounded progress bar with an optional label, used for kingdom progress,
/// player level and the daily challenge.
class KdProgressBar extends StatelessWidget {
  const KdProgressBar({
    required this.value,
    this.height = 12,
    this.gradient = AppColors.goldGradient,
    this.background = AppColors.surfaceLow,
    this.animate = true,
    super.key,
  });

  /// 0..1.
  final double value;
  final double height;
  final Gradient gradient;
  final Color background;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final double clamped = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: <Widget>[
          Container(height: height, color: background),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth * clamped;
              final Widget bar = Container(
                height: height,
                width: width,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(height),
                ),
              );
              if (!animate) return bar;
              return AnimatedContainer(
                duration: AppDurations.slow,
                curve: Curves.easeOutCubic,
                height: height,
                width: width,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(height),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

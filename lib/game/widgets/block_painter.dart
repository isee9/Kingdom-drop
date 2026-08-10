import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shared block drawing.
///
/// Every block in the game — on the board, in the tray, under the finger, in
/// the tutorial — is drawn by [paintBlock], so they are guaranteed to look
/// identical and a change to the block style is a one-line change.
abstract final class BlockPainting {
  /// Inset of the visible block inside its cell, as a fraction of cell size.
  static const double inset = 0.055;

  /// Draws one block face into [cell].
  ///
  /// The look is a soft vertical gradient with a lighter top edge and a darker
  /// bottom edge, which reads as a physical tile without needing a texture.
  static void paintBlock(
    Canvas canvas,
    Rect cell,
    int colorIndex, {
    double scale = 1.0,
    double opacity = 1.0,
  }) {
    if (scale <= 0 || opacity <= 0) return;

    final Color base =
        AppColors.blocks[colorIndex.abs() % AppColors.blocks.length];
    final Rect rect = _inset(cell, scale);
    final double radius = rect.width * AppRadius.blockFraction;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Drop shadow grounds the block against the board.
    canvas.drawRRect(
      rrect.shift(Offset(0, rect.height * 0.06)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(base, Colors.white, 0.22)!.withValues(alpha: opacity),
            base.withValues(alpha: opacity),
            Color.lerp(base, Colors.black, 0.20)!.withValues(alpha: opacity),
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(rect),
    );

    // Inner top highlight: a short arc of light along the upper edge.
    final Rect highlight = Rect.fromLTWH(
      rect.left + rect.width * 0.16,
      rect.top + rect.height * 0.12,
      rect.width * 0.68,
      rect.height * 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlight, Radius.circular(radius * 0.6)),
      Paint()..color = Colors.white.withValues(alpha: 0.20 * opacity),
    );
  }

  /// Translucent ghost shown under a dragged piece.
  static void paintGhost(
    Canvas canvas,
    Rect cell, {
    required bool valid,
    double scale = 1.0,
  }) {
    final Rect rect = _inset(cell, scale);
    final double radius = rect.width * AppRadius.blockFraction;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = valid ? AppColors.previewValid : AppColors.previewInvalid,
    );

    // A solid outline as well as the fill: placement validity must not depend
    // on colour alone.
    canvas.drawRRect(
      rrect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = (valid ? AppColors.success : AppColors.danger).withValues(
          alpha: 0.95,
        ),
    );

    if (!valid) {
      // A cross reinforces "no" for players who cannot rely on the red.
      final Paint stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.9);
      final Rect x = rect.deflate(rect.width * 0.30);
      canvas.drawLine(x.topLeft, x.bottomRight, stroke);
      canvas.drawLine(x.topRight, x.bottomLeft, stroke);
    }
  }

  /// Empty board cell.
  static void paintEmptyCell(Canvas canvas, Rect cell, {bool onCross = false}) {
    final Rect rect = _inset(cell, 1);
    final double radius = rect.width * AppRadius.blockFraction;
    // Cross cells are dimmer than the quadrants so the region rule reads at a
    // glance, but they must still look like cells — they are perfectly legal
    // to play into, and a player should never mistake them for a gap.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..color = onCross
            ? Color.lerp(AppColors.boardCell, AppColors.boardBase, 0.45)!
            : AppColors.boardCell,
    );
  }

  static Rect _inset(Rect cell, double scale) {
    final double pad = cell.width * inset;
    final Rect base = cell.deflate(pad);
    if (scale == 1.0) return base;
    return Rect.fromCenter(
      center: base.center,
      width: base.width * scale,
      height: base.height * scale,
    );
  }
}

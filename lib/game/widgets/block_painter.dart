import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Shared block drawing.
///
/// Every block in the game — on the board, in the tray, under the finger, in
/// the tutorial — comes from [paintBlock], so they are guaranteed to match and
/// the block style is a one-place change.
///
/// A block is built from five passes, and each one is doing a job:
/// a dark contact shadow to sit it on the board, a dark outline so it reads
/// against any colour, a solid bottom lip for thickness, the graded face, and a
/// gloss highlight. Flat rectangles are what make a puzzle board look like a
/// prototype; this is the difference.
abstract final class BlockPainting {
  /// Inset of the visible block inside its cell, as a fraction of cell size.
  static const double inset = 0.045;

  /// Thickness of the bottom lip, as a fraction of the block's height.
  static const double _lip = 0.13;

  static void paintBlock(
    Canvas canvas,
    Rect cell,
    int colorIndex, {
    double scale = 1.0,
    double opacity = 1.0,
  }) {
    if (scale <= 0 || opacity <= 0) return;

    final Rect rect = _inset(cell, scale);
    if (rect.width <= 1) return;

    final int i = colorIndex.abs() % AppColors.blocks.length;
    final Color base = AppColors.blocks[i];
    final Color top = AppColors.blockTop(i);
    final Color edge = AppColors.blockEdge(i);

    final double radius = rect.width * AppRadius.blockFraction;
    final double lip = rect.height * _lip;

    // 1. Contact shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(0, rect.height * 0.07),
        Radius.circular(radius),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // 2. Outline. Drawn as a slightly larger solid shape rather than a stroke
    //    so it stays crisp at small tray sizes.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(rect.width * 0.045),
        Radius.circular(radius * 1.1),
      ),
      Paint()..color = AppColors.textOutline.withValues(alpha: 0.85 * opacity),
    );

    // 3. Bottom lip: the whole block in the darker edge colour, with the face
    //    drawn short of the bottom so the lip shows through.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = edge.withValues(alpha: opacity),
    );

    // 4. Face.
    final Rect face = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      rect.height - lip,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(radius)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            top.withValues(alpha: opacity),
            base.withValues(alpha: opacity),
          ],
        ).createShader(face),
    );

    // 5. Gloss across the top, and a soft sheen down the left edge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          face.left + face.width * 0.12,
          face.top + face.height * 0.10,
          face.width * 0.76,
          face.height * 0.30,
        ),
        Radius.circular(radius * 0.8),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.30 * opacity),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          face.left + face.width * 0.10,
          face.top + face.height * 0.18,
          face.width * 0.12,
          face.height * 0.62,
        ),
        Radius.circular(radius * 0.6),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.13 * opacity),
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

    // A solid outline as well as a fill: placement validity must never depend
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

  /// Empty board cell: a shallow socket rather than a flat square.
  static void paintEmptyCell(Canvas canvas, Rect cell, {bool onCross = false}) {
    final Rect rect = _inset(cell, 1);
    if (rect.width <= 1) return;
    final double radius = rect.width * AppRadius.blockFraction;

    // Cross cells are dimmer so the region rule reads at a glance, but they
    // must still look like cells — they are legal to play into, and a player
    // should never mistake one for a gap.
    final Color fill = onCross
        ? Color.lerp(AppColors.boardCell, AppColors.boardBase, 0.5)!
        : AppColors.boardCell;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = fill,
    );

    // Inner shadow along the top edge, which is what makes it read as recessed.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.07
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.05),
          ],
        ).createShader(rect),
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

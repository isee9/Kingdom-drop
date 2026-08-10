import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../engine/board.dart';
import '../engine/shape.dart';
import '../engine/shape_generator.dart';
import 'block_painter.dart';

/// Draws a shape as a grid of blocks. Used by the tray, the drag ghost and the
/// tutorial, so a piece looks the same everywhere it appears.
class ShapeThumbnail extends StatelessWidget {
  const ShapeThumbnail({
    required this.shape,
    required this.colorIndex,
    required this.cellSize,
    this.opacity = 1.0,
    super.key,
  });

  final Shape shape;
  final int colorIndex;
  final double cellSize;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: shape.width * cellSize,
      height: shape.height * cellSize,
      child: CustomPaint(
        painter: _ShapePainter(
          shape: shape,
          colorIndex: colorIndex,
          cellSize: cellSize,
          opacity: opacity,
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter({
    required this.shape,
    required this.colorIndex,
    required this.cellSize,
    required this.opacity,
  });

  final Shape shape;
  final int colorIndex;
  final double cellSize;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    for (final Cell cell in shape.cells) {
      BlockPainting.paintBlock(
        canvas,
        Rect.fromLTWH(
          cell.col * cellSize,
          cell.row * cellSize,
          cellSize,
          cellSize,
        ),
        colorIndex,
        opacity: opacity,
      );
    }
  }

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) =>
      oldDelegate.shape.id != shape.id ||
      oldDelegate.colorIndex != colorIndex ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.opacity != opacity;
}

/// The three-piece tray beneath the board.
///
/// Slots keep their position after a piece is used, so the remaining pieces do
/// not jump around mid-turn. A used slot fades out and leaves an empty well.
class TrayView extends StatelessWidget {
  const TrayView({
    required this.pieces,
    required this.draggingPieceId,
    required this.cellSize,
    required this.board,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.enabled,
    super.key,
  });

  final List<TrayPiece> pieces;
  final int? draggingPieceId;

  /// Tray-space cell size. Smaller than the board's so three pieces fit.
  final double cellSize;

  /// Used to grey out pieces that have nowhere left to go, which tells the
  /// player where the danger is before they run out of moves.
  final Board board;

  final void Function(TrayPiece piece, Offset globalPosition) onDragStart;
  final void Function(Offset globalPosition) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final TrayPiece piece in pieces)
          Expanded(
            child: _TraySlot(
              piece: piece,
              cellSize: cellSize,
              isDragging: piece.id == draggingPieceId,
              hasPlacement: board.hasAnyPlacement(piece.shape),
              enabled: enabled && !piece.used,
              onDragStart: (Offset p) => onDragStart(piece, p),
              onDragUpdate: onDragUpdate,
              onDragEnd: onDragEnd,
              onDragCancel: onDragCancel,
            ),
          ),
      ],
    );
  }
}

class _TraySlot extends StatelessWidget {
  const _TraySlot({
    required this.piece,
    required this.cellSize,
    required this.isDragging,
    required this.hasPlacement,
    required this.enabled,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final TrayPiece piece;
  final double cellSize;
  final bool isDragging;
  final bool hasPlacement;
  final bool enabled;
  final void Function(Offset globalPosition) onDragStart;
  final void Function(Offset globalPosition) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  @override
  Widget build(BuildContext context) {
    // The piece is hidden in the tray while it is under the finger, but the
    // slot keeps its size so the row does not reflow mid-drag.
    final Widget content = piece.used
        ? const SizedBox.shrink()
        : AnimatedOpacity(
            duration: AppDurations.fast,
            opacity: isDragging ? 0.18 : (hasPlacement ? 1 : 0.4),
            child: ShapeThumbnail(
              shape: piece.shape,
              colorIndex: piece.colorIndex,
              cellSize: cellSize,
            ),
          );

    return Semantics(
      label: piece.used
          ? 'Empty slot'
          : 'Piece, ${piece.shape.blockCount} blocks'
                '${hasPlacement ? '' : ', no space left for this piece'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: enabled
            ? (DragStartDetails d) => onDragStart(d.globalPosition)
            : null,
        onPanUpdate: enabled
            ? (DragUpdateDetails d) => onDragUpdate(d.globalPosition)
            : null,
        onPanEnd: enabled ? (_) => onDragEnd() : null,
        onPanCancel: enabled ? onDragCancel : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: !piece.used && !hasPlacement
                  ? AppColors.danger.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/booster.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../controller/game_controller.dart';
import '../engine/board.dart';
import '../engine/shape.dart';
import 'block_painter.dart';

/// Maps between board cells and pixels.
///
/// Both the view and the drag layer need this maths, and getting the two out of
/// step is how drop targets end up one cell off, so it lives in one place.
class BoardGeometry {
  const BoardGeometry({required this.cellSize, required this.size});

  final double cellSize;
  final int size;

  double get extent => cellSize * size;

  Rect cellRect(int row, int col) =>
      Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize);

  Offset cellCentre(int row, int col) =>
      Offset((col + 0.5) * cellSize, (row + 0.5) * cellSize);

  /// Board-local pixel offset to the cell containing it. May be out of range.
  Cell cellAt(Offset local) =>
      Cell((local.dy / cellSize).floor(), (local.dx / cellSize).floor());
}

/// Draws the playfield.
class BoardView extends StatelessWidget {
  const BoardView({
    required this.controller,
    required this.geometry,
    required this.placeAnimation,
    super.key,
  });

  final GameController controller;
  final BoardGeometry geometry;

  /// 0 to 1 pop-in for cells that just landed.
  final Animation<double> placeAnimation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: geometry.extent,
      height: geometry.extent,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BoardPainter(
            controller: controller,
            geometry: geometry,
            placeAnimation: placeAnimation,
            repaint: Listenable.merge(<Listenable>[controller, placeAnimation]),
          ),
          isComplex: true,
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.controller,
    required this.geometry,
    required this.placeAnimation,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GameController controller;
  final BoardGeometry geometry;
  final Animation<double> placeAnimation;

  @override
  void paint(Canvas canvas, Size size) {
    final Board board = controller.board;

    _paintBase(canvas, size);
    _paintRegionPlates(canvas);
    _paintCells(canvas, board);
    _paintClearHighlight(canvas);
    _paintDropPreview(canvas);
    _paintBoosterTargeting(canvas, board);
  }

  /// The board sits in a frame like the rest of the UI, with a sunken well so
  /// the blocks read as sitting inside something rather than floating.
  void _paintBase(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    const double frame = 5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(frame),
        const Radius.circular(AppRadius.lg + frame),
      ),
      Paint()..color = AppColors.textOutline,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(frame - 2),
        const Radius.circular(AppRadius.lg + frame),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF3E5F9E), AppColors.boardFrame],
        ).createShader(rect),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.lg)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0A1731), Color(0xFF122A52)],
        ).createShader(rect),
    );
  }

  /// Tints the four 3x3 quadrants so the region rule is visible at a glance,
  /// and leaves the central cross untinted so it reads as separate.
  void _paintRegionPlates(Canvas canvas) {
    final Paint plate = Paint()..color = Colors.white.withValues(alpha: 0.055);

    for (final BoardRegion region in Board.regions) {
      final Rect rect = Rect.fromLTWH(
        region.leftCol * geometry.cellSize,
        region.topRow * geometry.cellSize,
        region.size * geometry.cellSize,
        region.size * geometry.cellSize,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(geometry.cellSize * 0.02),
          const Radius.circular(AppRadius.md),
        ),
        plate,
      );
    }
  }

  void _paintCells(Canvas canvas, Board board) {
    final Set<Cell> justPlaced = controller.justPlaced;
    final double pop = placeAnimation.value;

    for (int r = 0; r < board.size; r++) {
      for (int c = 0; c < board.size; c++) {
        final Rect rect = geometry.cellRect(r, c);
        final int value = board.cellAt(r, c);

        if (value == Board.emptyCell) {
          BlockPainting.paintEmptyCell(
            canvas,
            rect,
            onCross: Board.isCrossCell(r, c),
          );
          continue;
        }

        // Cells that just landed overshoot slightly then settle.
        double scale = 1;
        if (justPlaced.contains(Cell(r, c)) && pop < 1) {
          scale = 0.55 + 0.55 * Curves.easeOutBack.transform(pop);
        }
        BlockPainting.paintBlock(canvas, rect, value, scale: scale);
      }
    }
  }

  /// Glows the rows/columns/regions that the pending drop would clear.
  void _paintClearHighlight(Canvas canvas) {
    final Set<Cell> cells = controller.hoverClearCells;
    if (cells.isEmpty) return;

    final Paint glow = Paint()..color = AppColors.previewClear;
    for (final Cell cell in cells) {
      final Rect rect = geometry
          .cellRect(cell.row, cell.col)
          .deflate(geometry.cellSize * 0.03);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.sm)),
        glow,
      );
    }
  }

  void _paintDropPreview(Canvas canvas) {
    final Set<Cell> cells = controller.hoverCells;
    if (cells.isEmpty) return;

    final bool valid = controller.hoverValid;
    for (final Cell cell in cells) {
      if (cell.row < 0 ||
          cell.col < 0 ||
          cell.row >= geometry.size ||
          cell.col >= geometry.size) {
        continue;
      }
      BlockPainting.paintGhost(
        canvas,
        geometry.cellRect(cell.row, cell.col),
        valid: valid,
      );
    }
  }

  /// While a hammer or bomb is armed, mark what it would hit.
  void _paintBoosterTargeting(Canvas canvas, Board board) {
    final BoosterType? armed = controller.armedBooster;
    if (armed == null) return;

    final Paint wash = Paint()
      ..color = AppColors.warning.withValues(alpha: 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, geometry.extent, geometry.extent),
        const Radius.circular(AppRadius.lg),
      ),
      wash,
    );

    final Paint outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.warning.withValues(alpha: 0.65);

    for (int r = 0; r < board.size; r++) {
      for (int c = 0; c < board.size; c++) {
        if (!board.isFilled(r, c)) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            geometry.cellRect(r, c).deflate(geometry.cellSize * 0.1),
            const Radius.circular(AppRadius.sm),
          ),
          outline,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => true;
}

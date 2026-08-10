import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart' show Curves;

import '../../theme/app_colors.dart';

/// The particle layer that sits over the board.
///
/// This is where Flame earns its place: it already has a particle system with
/// lifespans, acceleration and automatic cleanup, and it renders on its own
/// surface so bursts never trigger a Flutter widget rebuild mid-drag. The board
/// itself stays a [CustomPaint] because Flutter's gesture system gives far
/// better drag hit-testing than routing pointers through a game loop.
///
/// The widget is laid out to exactly the board's square, so a position in this
/// game's coordinates is the same as a board-local pixel offset.
class BoardFxGame extends FlameGame {
  BoardFxGame({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  Color backgroundColor() => const Color(0x00000000);

  /// Bursts a shower of blocks outward from a cleared cell.
  void burst({
    required Offset position,
    required int colorIndex,
    required double cellSize,
    double power = 1.0,
  }) {
    final Color color =
        AppColors.blocks[colorIndex.abs() % AppColors.blocks.length];
    final int count = (6 + 5 * power).round().clamp(4, 18);
    final double chip = cellSize * 0.16;

    add(
      ParticleSystemComponent(
        position: Vector2(position.dx, position.dy),
        particle: Particle.generate(
          count: count,
          lifespan: 0.55 + 0.15 * power,
          generator: (int i) {
            final double angle = _random.nextDouble() * pi * 2;
            final double speed =
                (cellSize * 1.6 + _random.nextDouble() * cellSize * 2.6) *
                power;
            final double spin = (_random.nextDouble() - 0.5) * 8;
            final double sizeJitter = 0.6 + _random.nextDouble() * 0.8;

            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              // Gravity, so the debris falls away rather than hanging.
              acceleration: Vector2(0, cellSize * 9),
              child: ComputedParticle(
                renderer: (Canvas canvas, Particle particle) {
                  final double life = 1 - particle.progress;
                  final double side = chip * sizeJitter * life;
                  if (side <= 0.2) return;

                  canvas.save();
                  canvas.rotate(spin * particle.progress);
                  canvas.drawRRect(
                    RRect.fromRectAndRadius(
                      Rect.fromCenter(
                        center: Offset.zero,
                        width: side * 2,
                        height: side * 2,
                      ),
                      Radius.circular(side * 0.45),
                    ),
                    Paint()..color = color.withValues(alpha: life),
                  );
                  canvas.restore();
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// A single expanding ring, used to punctuate a multi-line combo.
  void shockwave({required Offset position, required double radius}) {
    add(
      ParticleSystemComponent(
        position: Vector2(position.dx, position.dy),
        particle: ComputedParticle(
          lifespan: 0.42,
          renderer: (Canvas canvas, Particle particle) {
            final double t = particle.progress;
            canvas.drawCircle(
              Offset.zero,
              radius * Curves.easeOutCubic.transform(t),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4 * (1 - t)
                ..color = AppColors.gold.withValues(alpha: 0.55 * (1 - t)),
            );
          },
        ),
      ),
    );
  }
}

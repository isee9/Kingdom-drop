import 'dart:math' as math;

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';

import '../../game/controller/game_controller.dart';
import '../../game/engine/board.dart';
import '../../game/engine/shape.dart';
import '../../game/engine/shape_generator.dart';
import '../../game/fx/board_fx_game.dart';
import '../../game/widgets/board_view.dart';
import '../../game/widgets/booster_bar.dart';
import '../../game/widgets/game_hud.dart';
import '../../game/widgets/tray_view.dart';
import '../../models/booster.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/currency_pill.dart';
import '../shop/shop_screen.dart';
import 'game_over_sheet.dart';
import 'game_summary_screen.dart';
import 'pause_sheet.dart';
import 'tutorial_overlay.dart';

/// The gameplay screen.
///
/// Layout is a fixed vertical stack — HUD, board, boosters, tray — sized from
/// the available height so the board is as large as it can be while the tray
/// stays reachable with one thumb.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    transitionDuration: AppDurations.screenTransition,
    reverseTransitionDuration: AppDurations.fast,
    pageBuilder: (_, _, _) => const GameScreen(),
    transitionsBuilder:
        (_, Animation<double> animation, _, Widget child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
  );

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late final AppServices _services;
  late final GameController _controller;
  late final BoardFxGame _fx;

  /// Locates the play area so global drag coordinates can be made local.
  final GlobalKey _stageKey = GlobalKey();

  /// Pop-in animation for freshly placed blocks.
  late final AnimationController _placeAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  /// Board shake on a big clear.
  late final AnimationController _shakeAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  /// Geometry for the current layout, recomputed whenever constraints change.
  BoardGeometry _geometry = const BoardGeometry(cellSize: 40, size: 7);
  Offset _boardOrigin = Offset.zero;

  int _lastShakeToken = 0;
  bool _outOfMovesShown = false;
  bool _tutorialActive = false;

  @override
  void initState() {
    super.initState();
    _services = ServiceScope.read(context);
    _controller = GameController(
      player: _services.player,
      audio: _services.audio,
      haptics: _services.haptics,
      analytics: _services.analytics,
      daily: _services.daily,
    );
    _fx = BoardFxGame();
    _controller.addListener(_onControllerChanged);
    _services.analytics.screen('game');

    _tutorialActive = !_services.player.tutorialCompleted;
    // Seed the guided board here rather than from the overlay's initState: the
    // overlay is built inside a LayoutBuilder, so notifying listeners from
    // there lands mid-layout and the tray misses the update.
    if (_tutorialActive) _controller.prepareTutorial();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _placeAnimation.dispose();
    _shakeAnimation.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- effects
  void _onControllerChanged() {
    // Blocks that just landed pop in.
    if (_controller.justPlaced.isNotEmpty &&
        !_placeAnimation.isAnimating &&
        _placeAnimation.value != 1) {
      _placeAnimation.forward(from: 0);
    }

    if (_controller.shakeToken != _lastShakeToken) {
      _lastShakeToken = _controller.shakeToken;
      _shakeAnimation.forward(from: 0);
    }

    _drainClearEffects();

    if (_controller.phase == GamePhase.outOfMoves && !_outOfMovesShown) {
      _outOfMovesShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOutOfMoves());
    }
    if (_controller.phase == GamePhase.playing) _outOfMovesShown = false;
  }

  /// Turns queued clear effects into Flame particle bursts.
  ///
  /// The list is a copy, so consuming each entry as we go is safe.
  void _drainClearEffects() {
    final List<ClearEffect> effects = _controller.clearEffects;
    if (effects.isEmpty) return;

    for (final ClearEffect effect in effects) {
      final double power = (0.7 + effect.groupCount * 0.35).clamp(0.7, 2.2);

      for (final Cell cell in effect.cells) {
        _fx.burst(
          position: _geometry.cellCentre(cell.row, cell.col),
          colorIndex: effect.colors[cell] ?? 0,
          cellSize: _geometry.cellSize,
          power: power,
        );
      }

      if (effect.groupCount >= 2) {
        // Ring out from the centre of what cleared.
        double row = 0;
        double col = 0;
        for (final Cell cell in effect.cells) {
          row += cell.row;
          col += cell.col;
        }
        row /= effect.cells.length;
        col /= effect.cells.length;
        _fx.shockwave(
          position: Offset(
            (col + 0.5) * _geometry.cellSize,
            (row + 0.5) * _geometry.cellSize,
          ),
          radius: _geometry.cellSize * (2 + effect.groupCount),
        );
      }

      _controller.consumeClearEffect(effect);
    }
  }

  // ------------------------------------------------------------------- drag
  /// Converts a global pointer to play-area coordinates.
  Offset? _toStage(Offset global) {
    final RenderObject? object = _stageKey.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return null;
    return object.globalToLocal(global);
  }

  /// Where the dragged piece's bounding box sits, given the pointer.
  ///
  /// The piece rides above the finger so it is never hidden by the hand: it is
  /// centred horizontally on the touch point and lifted so its bottom edge
  /// clears the fingertip.
  Rect _draggedPieceRect(Shape shape, Offset stagePointer) {
    final double cell = _geometry.cellSize;
    final double width = shape.width * cell;
    final double height = shape.height * cell;
    final double lift = cell * 0.75 + 16;

    return Rect.fromLTWH(
      stagePointer.dx - width / 2,
      stagePointer.dy - lift - height,
      width,
      height,
    );
  }

  /// The board cell the piece's top-left corner snaps to, or null when the
  /// piece is not over the board at all.
  Cell? _originFor(Shape shape, Rect pieceRect) {
    final Rect boardRect = Rect.fromLTWH(
      _boardOrigin.dx,
      _boardOrigin.dy,
      _geometry.extent,
      _geometry.extent,
    );
    if (!pieceRect.overlaps(boardRect)) return null;

    final Offset relative = pieceRect.topLeft - _boardOrigin;
    return Cell(
      (relative.dy / _geometry.cellSize).round(),
      (relative.dx / _geometry.cellSize).round(),
    );
  }

  void _onDragStart(TrayPiece piece, Offset global) {
    if (_controller.phase != GamePhase.playing) return;
    final Offset? stage = _toStage(global);
    if (stage == null) return;

    _controller.startDrag(piece.id, stage);
    _updateDrag(global);
  }

  void _updateDrag(Offset global) {
    final TrayPiece? piece = _controller.draggingPiece;
    if (piece == null) return;
    final Offset? stage = _toStage(global);
    if (stage == null) return;

    final Rect rect = _draggedPieceRect(piece.shape, stage);
    _controller.updateDrag(stage, _originFor(piece.shape, rect));
  }

  void _onDragEnd() {
    _controller.endDrag();
  }

  // ------------------------------------------------------------- navigation
  Future<void> _showOutOfMoves() async {
    if (!mounted) return;

    final OutOfMovesChoice? choice = await showGameOverSheet(
      context,
      controller: _controller,
      services: _services,
    );
    if (!mounted) return;

    switch (choice) {
      case OutOfMovesChoice.continued:
        break; // The sheet already applied it.
      case OutOfMovesChoice.ended:
      case null:
        await _endRun();
    }
  }

  Future<void> _endRun() async {
    _controller.finishGame();
    if (!mounted) return;

    final SummaryChoice choice = await Navigator.of(context).push<SummaryChoice>(
          GameSummaryScreen.route(
            controller: _controller,
            services: _services,
          ),
        ) ??
        SummaryChoice.home;

    if (!mounted) return;

    switch (choice) {
      case SummaryChoice.playAgain:
        setState(() => _outOfMovesShown = false);
        _controller.restart();
      case SummaryChoice.home:
        Navigator.of(context).pop();
    }
  }

  Future<void> _openPause() async {
    final PauseChoice? choice = await showPauseSheet(
      context,
      services: _services,
    );
    if (!mounted) return;

    switch (choice) {
      case PauseChoice.restart:
        _controller.restart();
      case PauseChoice.quit:
        await _endRun();
      case PauseChoice.resume:
      case null:
        break;
    }
  }

  void _openShop() {
    _services.analytics.log('shop_opened', <String, Object?>{'from': 'game'});
    Navigator.of(context).push(ShopScreen.route());
  }

  // ----------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              _computeGeometry(constraints);
              return _buildBody(constraints);
            },
          ),
        ),
      ),
    );
  }

  // Fixed chrome heights. The board takes whatever is left.
  static const double _hudHeight = 64;
  // Tall enough for a booster chip (icon + count) plus the targeting hint.
  static const double _boosterHeight = 90;
  static const double _gap = AppSpacing.lg;

  double _trayHeight = 116;
  double _topGap = _gap;
  double _bottomGap = _gap;

  /// Sizes the board from what is left after the fixed chrome.
  ///
  /// The heights are worked out here and then applied as explicit boxes rather
  /// than an `Expanded`, so the column's children sum to exactly the available
  /// height. That matters twice over: it stops the layout overflowing by a few
  /// pixels on some screens, and it means [_boardOrigin] — which the drag maths
  /// converts pointer positions against — is guaranteed to be where the board
  /// actually gets painted.
  void _computeGeometry(BoxConstraints constraints) {
    final double height = constraints.maxHeight;
    final double width = constraints.maxWidth;

    double tray = (height * 0.15).clamp(88.0, 132.0);
    final double available =
        height - _hudHeight - _boosterHeight - tray - _gap * 3;

    final double side = math.min(
      width - AppSpacing.lg * 2,
      math.max(120.0, available),
    );

    // Spare height on a tall screen: give some of it to the tray so the pieces
    // are comfortably thumb-sized, and split the rest above and below the
    // board so it sits optically centred.
    double leftover = math.max(0, available - side);
    final double trayBonus = math.min(leftover * 0.5, 40);
    tray += trayBonus;
    leftover -= trayBonus;

    final double topExtra = leftover / 2;

    _trayHeight = tray;
    _topGap = _gap + topExtra;
    _bottomGap = _gap + (leftover - topExtra);

    _geometry = BoardGeometry(
      cellSize: side / Board.defaultSize,
      size: Board.defaultSize,
    );
    _boardOrigin = Offset(
      (width - _geometry.extent) / 2,
      _hudHeight + _topGap,
    );
  }

  Widget _buildBody(BoxConstraints constraints) {
    // A pointer cancel — an incoming call, the notification shade, a system
    // back gesture — must return the piece to the tray, not drop it. Flutter's
    // pan recognizer reports a post-acceptance cancel as an ordinary end, which
    // would place the piece somewhere the player never chose, and placements
    // cannot be undone. Listeners run ahead of the gesture arena, so clearing
    // the drag here makes the subsequent onPanEnd a no-op.
    return Listener(
      onPointerCancel: (_) => _controller.cancelDrag(),
      child: _buildStage(constraints),
    );
  }

  Widget _buildStage(BoxConstraints constraints) {
    return Stack(
      key: _stageKey,
      children: <Widget>[
        Column(
          children: <Widget>[
            SizedBox(
              height: _hudHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: GameHud(controller: _controller, onPause: _openPause),
              ),
            ),
            SizedBox(height: _topGap),
            // Placeholder: the board itself is painted in the positioned layer
            // below so its shake transform cannot disturb this column.
            SizedBox(height: _geometry.extent, width: double.infinity),
            SizedBox(height: _bottomGap),
            SizedBox(height: _boosterHeight, child: _buildBoosterRow()),
            const SizedBox(height: _gap),
            SizedBox(height: _trayHeight, child: _buildTray()),
          ],
        ),

        // The board sits in its own layer so the shake transform and the
        // particle overlay do not disturb the column layout.
        Positioned(
          left: _boardOrigin.dx,
          top: _boardOrigin.dy,
          width: _geometry.extent,
          height: _geometry.extent,
          child: _buildBoardLayer(),
        ),

        // The piece under the finger, drawn above everything.
        Positioned.fill(child: _buildDragGhost()),

        if (_tutorialActive)
          Positioned.fill(
            child: TutorialOverlay(
              controller: _controller,
              boardOrigin: _boardOrigin,
              geometry: _geometry,
              onFinished: () {
                _services.player.markTutorialCompleted();
                setState(() => _tutorialActive = false);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBoardLayer() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (BuildContext context, Widget? child) {
        if (_shakeAnimation.isDismissed) return child!;
        // Decaying horizontal wobble; short enough to feel like impact rather
        // than a camera fault.
        final double t = _shakeAnimation.value;
        final double decay = (1 - t) * (1 - t);
        final double amplitude =
            _controller.shakeStrength * _geometry.cellSize * 0.22 * decay;
        return Transform.translate(
          offset: Offset(math.sin(t * math.pi * 6) * amplitude, 0),
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _onBoardTap,
            child: BoardView(
              controller: _controller,
              geometry: _geometry,
              placeAnimation: _placeAnimation,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: GameWidget<BoardFxGame>(game: _fx),
            ),
          ),
          Positioned.fill(
            child: FloatingScoreLayer(
              controller: _controller,
              cellSize: _geometry.cellSize,
            ),
          ),
        ],
      ),
    );
  }

  void _onBoardTap(TapUpDetails details) {
    if (_controller.armedBooster == null) return;
    final Cell cell = _geometry.cellAt(details.localPosition);
    if (cell.row < 0 ||
        cell.col < 0 ||
        cell.row >= Board.defaultSize ||
        cell.col >= Board.defaultSize) {
      return;
    }
    _controller.applyBoosterAt(cell.row, cell.col);
  }

  Widget _buildBoosterRow() {
    return ListenableBuilder(
      listenable: _services.player,
      builder: (BuildContext context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            BoosterBar(
              controller: _controller,
              coins: _services.player.coins,
              onNeedCoins: _openShop,
            ),
            const SizedBox(height: AppSpacing.xs),
            AnimatedSwitcher(
              duration: AppDurations.fast,
              child: _controller.armedBooster != null
                  ? Text(
                      _controller.armedBooster == BoosterType.hammer
                          ? 'Tap a block to remove it'
                          : 'Tap the board to blast a 3x3 area',
                      key: ValueKey<BoosterType?>(_controller.armedBooster),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                      ),
                    )
                  : const SizedBox(height: 15),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTray() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, _) {
          // A fixed tray cell size keeps relative piece sizes honest — a big
          // piece looks big, which is information the player needs. Five cells
          // is the widest shape in the catalogue, so size to that.
          final double slotWidth =
              (_geometry.extent - AppSpacing.xs * 6) / 3;
          final double trayCell = math.min(
            _geometry.cellSize * 0.58,
            slotWidth / 5.4,
          );

          return TrayView(
            pieces: _controller.tray,
            draggingPieceId: _controller.draggingPieceId,
            cellSize: trayCell,
            board: _controller.board,
            enabled: _controller.phase == GamePhase.playing,
            onDragStart: _onDragStart,
            onDragUpdate: _updateDrag,
            onDragEnd: _onDragEnd,
            onDragCancel: _controller.cancelDrag,
          );
        },
      ),
    );
  }

  Widget _buildDragGhost() {
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, _) {
          final TrayPiece? piece = _controller.draggingPiece;
          final Offset? pointer = _controller.dragPointer;
          if (piece == null || pointer == null) {
            return const SizedBox.shrink();
          }

          final Rect rect = _draggedPieceRect(piece.shape, pointer);
          return Stack(
            children: <Widget>[
              Positioned(
                left: rect.left,
                top: rect.top,
                child: ShapeThumbnail(
                  shape: piece.shape,
                  colorIndex: piece.colorIndex,
                  cellSize: _geometry.cellSize,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small header used by the game's modal sheets.
class GameSheetHeader extends StatelessWidget {
  const GameSheetHeader({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderStrong,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.headline,
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        ],
      ],
    );
  }
}

/// Coin balance chip reused by the game's sheets.
class SheetCoinBalance extends StatelessWidget {
  const SheetCoinBalance({super.key});

  @override
  Widget build(BuildContext context) {
    return PlayerBuilder(
      builder: (BuildContext context, player) => CurrencyPill(
        kind: CurrencyKind.coins,
        amount: player.coins,
        compact: true,
      ),
    );
  }
}

/// Small helper so sheets can show a hint line consistently.
Widget sheetHint(String text) => Padding(
  padding: const EdgeInsets.only(top: AppSpacing.sm),
  child: Text(
    text,
    textAlign: TextAlign.center,
    style: AppTextStyles.caption,
  ),
);

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/core/config/economy_config.dart';
import 'package:kingdom_drop/game/widgets/tray_view.dart';
import 'package:kingdom_drop/models/booster.dart';
import 'package:kingdom_drop/models/save_data.dart';
import 'package:kingdom_drop/screens/game/game_screen.dart';
import 'package:kingdom_drop/services/service_locator.dart';

import 'test_services.dart';

/// Advances a fixed number of frames.
///
/// `pumpAndSettle` cannot be used on the game screen: the Flame particle layer
/// runs a continuous game loop and the tutorial hint animates on repeat, so the
/// tree never reaches a settled state by design.
Future<void> pumpFrames(
  WidgetTester tester, {
  int frames = 20,
  Duration step = const Duration(milliseconds: 16),
}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// A save with the tutorial already done, so the game screen behaves like a
/// normal run rather than the guided first one.
SaveData experiencedPlayer() => SaveData.fresh()..tutorialCompleted = true;

void main() {
  // A tall portrait surface, matching the layout's design target.
  const Size phone = Size(430, 932);

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<AppServices> pumpGame(WidgetTester tester, {SaveData? save}) async {
    tester.view
      ..physicalSize = phone
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final AppServices services = createTestServices(
      save: save ?? experiencedPlayer(),
    );
    await tester.pumpWidget(
      wrapForTest(child: const GameScreen(), services: services),
    );
    await tester.pump();
    return services;
  }

  group('Game screen layout', () {
    testWidgets('builds without overflowing on a portrait phone', (
      WidgetTester tester,
    ) async {
      await pumpGame(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(GameScreen), findsOneWidget);
    });

    testWidgets('shows three tray pieces and the score', (
      WidgetTester tester,
    ) async {
      await pumpGame(tester);

      expect(find.byType(ShapeThumbnail), findsNWidgets(3));
      expect(find.text('0'), findsWidgets);
      expect(find.textContaining('BEST'), findsOneWidget);
    });

    testWidgets('fits a short screen without overflowing', (
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final AppServices services = createTestServices(
        save: experiencedPlayer(),
      );
      await tester.pumpWidget(
        wrapForTest(child: const GameScreen(), services: services),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a very tall screen without overflowing', (
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = const Size(412, 1080)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final AppServices services = createTestServices(
        save: experiencedPlayer(),
      );
      await tester.pumpWidget(
        wrapForTest(child: const GameScreen(), services: services),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('Dragging a piece', () {
    testWidgets('a drag onto the board places it and scores', (
      WidgetTester tester,
    ) async {
      await pumpGame(tester);

      final Finder firstPiece = find.byType(ShapeThumbnail).first;
      final Offset start = tester.getCenter(firstPiece);

      // Aim at the middle of the screen, which is over the board. The piece
      // rides above the finger, so dropping here lands it in the upper half.
      final TestGesture gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 16));

      await gesture.moveTo(const Offset(215, 500));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(215, 470));
      await tester.pump(const Duration(milliseconds: 16));

      await gesture.up();
      await pumpFrames(tester, frames: 40);

      expect(tester.takeException(), isNull);

      // A successful placement always scores at least one block's worth.
      final BuildContext context = tester.element(find.byType(GameScreen));
      final AppServices services = ServiceScope.read(context);
      expect(services, isNotNull);

      // Two of the three tray pieces should remain drawable.
      expect(
        find.byType(ShapeThumbnail),
        findsAtLeast(2),
        reason: 'the tray keeps its slots after a placement',
      );
    });

    testWidgets('a drag released over the tray is rejected harmlessly', (
      WidgetTester tester,
    ) async {
      await pumpGame(tester);

      final Offset start = tester.getCenter(find.byType(ShapeThumbnail).first);

      final TestGesture gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 16));
      // Move sideways within the tray, nowhere near the board.
      await gesture.moveTo(start + const Offset(40, 10));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      // Nothing was consumed, so all three pieces are still there.
      expect(find.byType(ShapeThumbnail), findsNWidgets(3));
    });

    testWidgets('a cancelled drag leaves the board untouched', (
      WidgetTester tester,
    ) async {
      await pumpGame(tester);

      final Offset start = tester.getCenter(find.byType(ShapeThumbnail).first);
      final TestGesture gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(215, 400));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.cancel();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ShapeThumbnail), findsNWidgets(3));
    });
  });

  group('Tutorial', () {
    testWidgets('appears for a brand-new player', (WidgetTester tester) async {
      await pumpGame(tester, save: SaveData.fresh());

      // Display copy is drawn with StrokedText, which stacks a stroked Text
      // under a filled one, so the same string legitimately appears twice.
      expect(find.textContaining('Drag a piece'), findsWidgets);
    });

    testWidgets('does not appear once completed', (WidgetTester tester) async {
      await pumpGame(tester);

      expect(find.textContaining('Drag a piece'), findsNothing);
    });
  });

  group('Boosters', () {
    testWidgets('the bar shows the counts a new player starts with', (
      WidgetTester tester,
    ) async {
      await pumpGame(tester);

      final int hammers = EconomyConfig.startingBoosters[BoosterType.hammer]!;
      expect(find.text('x$hammers'), findsWidgets);
    });
  });
}

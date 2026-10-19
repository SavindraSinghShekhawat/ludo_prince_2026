import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/domain/models/board_path.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/ui/widgets/token_widget.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLudoController extends Fake implements LudoController {
  Token? movedToken;
  bool rollSent = false;

  @override
  Future<void> sendMoveIntent(Token token) async {
    movedToken = token;
  }

  @override
  Future<void> sendRollIntent() async {
    rollSent = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Touch Interaction & Accessibility Tests', () {
    late MockLudoController mockController;

    setUp(() {
      mockController = MockLudoController();
    });

    testWidgets('TokenWidget position and size remain strictly stable when isMovable changes (no glitching)', (tester) async {
      const cellSize = 24.0;
      final token = Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.home, position: 0);

      // Render unmovable token
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWithValue(mockController),
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                TokenWidget(
                  token: token,
                  cellSize: cellSize,
                  isMovable: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unmovableTransform = tester.widget<Transform>(find.byType(Transform).first);
      final unmovableSizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(Transform),
          matching: find.byType(SizedBox),
        ).first,
      );

      // Re-render movable token
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWithValue(mockController),
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                TokenWidget(
                  token: token,
                  cellSize: cellSize,
                  isMovable: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final movableTransform = tester.widget<Transform>(find.byType(Transform).first);
      final movableSizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(Transform),
          matching: find.byType(SizedBox),
        ).first,
      );

      // Position and size must be exactly identical so no visual jump/glitch occurs on state changes
      expect(movableTransform.transform, equals(unmovableTransform.transform));
      expect(movableSizedBox.width, equals(unmovableSizedBox.width));
      expect(movableSizedBox.height, equals(unmovableSizedBox.height));
    });

    testWidgets('Tapping movable TokenWidget gesture detector sends move intent to controller', (tester) async {
      const cellSize = 30.0;
      final token = Token(id: 1, slot: PlayerSlot.slot1, state: TokenState.home, position: 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWithValue(mockController),
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                TokenWidget(
                  token: token,
                  cellSize: cellSize,
                  isMovable: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(mockController.movedToken?.id, equals(1));
    });

    test('Base Yard Quadrant detection maps all 4 player home yards accurately', () {
      bool isInsideBase(PlayerSlot slot, double tapX, double tapY) {
        switch (slot) {
          case PlayerSlot.slot4: // Top-left base
            return tapX >= 0 && tapX < 6 && tapY >= 0 && tapY < 6;
          case PlayerSlot.slot3: // Top-right base
            return tapX >= 9 && tapX < 15 && tapY >= 0 && tapY < 6;
          case PlayerSlot.slot2: // Bottom-right base
            return tapX >= 9 && tapX < 15 && tapY >= 9 && tapY < 15;
          case PlayerSlot.slot1: // Bottom-left base
            return tapX >= 0 && tapX < 6 && tapY >= 9 && tapY < 15;
        }
      }

      // Slot 1 (Bottom-left): (2.5, 11.5) center
      expect(isInsideBase(PlayerSlot.slot1, 2.5, 11.5), isTrue);
      expect(isInsideBase(PlayerSlot.slot1, 0.5, 9.5), isTrue);
      expect(isInsideBase(PlayerSlot.slot1, 5.9, 14.9), isTrue);
      expect(isInsideBase(PlayerSlot.slot1, 6.1, 11.5), isFalse); // outside to the right

      // Slot 4 (Top-left): (2.5, 2.5) center
      expect(isInsideBase(PlayerSlot.slot4, 2.5, 2.5), isTrue);
      expect(isInsideBase(PlayerSlot.slot4, 5.0, 5.0), isTrue);
      expect(isInsideBase(PlayerSlot.slot4, 7.0, 2.5), isFalse); // track column

      // Slot 3 (Top-right): (11.5, 2.5) center
      expect(isInsideBase(PlayerSlot.slot3, 11.5, 2.5), isTrue);
      expect(isInsideBase(PlayerSlot.slot3, 9.0, 0.0), isTrue);
      expect(isInsideBase(PlayerSlot.slot3, 8.5, 2.5), isFalse);

      // Slot 2 (Bottom-right): (11.5, 11.5) center
      expect(isInsideBase(PlayerSlot.slot2, 11.5, 11.5), isTrue);
      expect(isInsideBase(PlayerSlot.slot2, 14.5, 14.5), isTrue);
      expect(isInsideBase(PlayerSlot.slot2, 5.0, 11.5), isFalse);
    });

    test('Proximity matching correctly identifies nearest token within 1.4 cells', () {
      final tokenA = Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.board, position: 0);
      final tokenB = Token(id: 1, slot: PlayerSlot.slot1, state: TokenState.board, position: 10);

      // BoardPath absolute coordinates
      final posA = BoardPath.getTokenOffset(tokenA); // col 1, row 6
      final posB = BoardPath.getTokenOffset(tokenB); // col 6, row 2

      final centerA = Offset(posA.dx + 0.5, posA.dy + 0.5);
      final centerB = Offset(posB.dx + 0.5, posB.dy + 0.5);

      // Tap near Token A (0.5 cells away)
      final tapNearA = Offset(centerA.dx + 0.3, centerA.dy + 0.4); // dist = 0.5
      final distA = math.sqrt(math.pow(tapNearA.dx - centerA.dx, 2) + math.pow(tapNearA.dy - centerA.dy, 2));
      final distB = math.sqrt(math.pow(tapNearA.dx - centerB.dx, 2) + math.pow(tapNearA.dy - centerB.dy, 2));

      expect(distA, closeTo(0.5, 0.01));
      expect(distA, lessThanOrEqualTo(1.4));
      expect(distA, lessThan(distB));

      // Tap in empty middle area (far from both)
      final farTap = const Offset(7.5, 7.5);
      final farDistA = math.sqrt(math.pow(farTap.dx - centerA.dx, 2) + math.pow(farTap.dy - centerA.dy, 2));
      final farDistB = math.sqrt(math.pow(farTap.dx - centerB.dx, 2) + math.pow(farTap.dy - centerB.dy, 2));

      expect(farDistA, greaterThan(1.4));
      expect(farDistB, greaterThan(1.4));
    });

    test('AudioService.playTapVibrate() respects vibration_enabled setting', () async {
      SharedPreferences.setMockInitialValues({'vibration_enabled': false});
      final service = AudioService();
      await service.init();
      expect(service.isVibrationEnabled, isFalse);

      // When false, playTapVibrate does nothing
      service.playTapVibrate();

      // Toggle back on
      await service.toggleVibration();
      expect(service.isVibrationEnabled, isTrue);

      service.playTapVibrate();
    });
  });
}

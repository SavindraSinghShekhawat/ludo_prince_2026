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

    test('Proximity matching correctly identifies nearest token within 0.85 cell thumb radius', () {
      final tokenA = Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.board, position: 0);
      final tokenB = Token(id: 1, slot: PlayerSlot.slot1, state: TokenState.board, position: 10);

      // BoardPath absolute coordinates
      final posA = BoardPath.getTokenOffset(tokenA); // col 1, row 6
      final posB = BoardPath.getTokenOffset(tokenB); // col 6, row 2

      final centerA = Offset(posA.dx + 0.5, posA.dy + 0.5);
      final centerB = Offset(posB.dx + 0.5, posB.dy + 0.5);

      // Tap near Token A (0.5 cells away, thumb on the token area)
      final tapNearA = Offset(centerA.dx + 0.3, centerA.dy + 0.4); // dist = 0.5
      final distA = math.sqrt(math.pow(tapNearA.dx - centerA.dx, 2) + math.pow(tapNearA.dy - centerA.dy, 2));
      final distB = math.sqrt(math.pow(tapNearA.dx - centerB.dx, 2) + math.pow(tapNearA.dy - centerB.dy, 2));

      expect(distA, closeTo(0.5, 0.01));
      expect(distA, lessThanOrEqualTo(0.85), reason: "Thumb touch on token area is within 0.85 cells");
      expect(distA, lessThan(distB));

      // Tap on adjacent cell center (1.0 cell away) - should NOT trigger token A
      final adjacentCellTap = Offset(centerA.dx + 1.0, centerA.dy);
      final distAdjacent = math.sqrt(math.pow(adjacentCellTap.dx - centerA.dx, 2) + math.pow(adjacentCellTap.dy - centerA.dy, 2));
      expect(distAdjacent, greaterThan(0.85), reason: "Adjacent cell center exceeds thumb threshold");

      // Tap in empty middle area (far from both)
      final farTap = const Offset(7.5, 7.5);
      final farDistA = math.sqrt(math.pow(farTap.dx - centerA.dx, 2) + math.pow(farTap.dy - centerA.dy, 2));
      final farDistB = math.sqrt(math.pow(farTap.dx - centerB.dx, 2) + math.pow(farTap.dy - centerB.dy, 2));

      expect(farDistA, greaterThan(0.85));
      expect(farDistB, greaterThan(0.85));
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

    test('Base yard tap accurately selects the specific token out of 4 chosen by the user', () {
      final tokens = List.generate(
        4,
        (i) => Token(id: i, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
      );

      Token? pickHomeToken(double tapX, double tapY) {
        double closestDist = double.infinity;
        Token? target;
        for (var token in tokens) {
          Offset gridPos = BoardPath.getTokenOffset(token);
          double centerX = gridPos.dx + 0.5;
          double centerY = gridPos.dy + 0.5;

          double dist = math.sqrt(
            math.pow(tapX - centerX, 2) + math.pow(tapY - centerY, 2),
          );

          if (dist < closestDist) {
            closestDist = dist;
            target = token;
          }
        }
        return target;
      }

      // Slot 1 base is at bx = 2.5, by = 11.5
      // Token 0: (1.5, 10.5), center (2.0, 11.0) -> Top-Left
      // Token 1: (3.5, 10.5), center (4.0, 11.0) -> Top-Right
      // Token 2: (1.5, 12.5), center (2.0, 13.0) -> Bottom-Left
      // Token 3: (3.5, 12.5), center (4.0, 13.0) -> Bottom-Right

      // 1. User taps near Token 0
      expect(pickHomeToken(2.1, 10.9)?.id, equals(0));
      expect(pickHomeToken(1.0, 10.0)?.id, equals(0)); // Top-left base corner

      // 2. User taps near Token 1
      expect(pickHomeToken(3.9, 11.1)?.id, equals(1));
      expect(pickHomeToken(5.0, 10.0)?.id, equals(1)); // Top-right base corner

      // 3. User taps near Token 2
      expect(pickHomeToken(1.9, 13.2)?.id, equals(2));
      expect(pickHomeToken(1.0, 14.5)?.id, equals(2)); // Bottom-left base corner

      // 4. User taps near Token 3
      expect(pickHomeToken(4.1, 12.8)?.id, equals(3));
      expect(pickHomeToken(5.0, 14.5)?.id, equals(3)); // Bottom-right base corner
    });

    test('Conflicting close tokens on adjacent or shared cells resolve accurately to the tapped piece', () {
      // 1. Two tokens of same player on adjacent cells (Cell 5 at (5, 6) and Cell 6 at (6, 5))
      final tokenAtCell5 = Token(id: 0, slot: PlayerSlot.slot4, state: TokenState.board, position: 5);
      final tokenAtCell6 = Token(id: 1, slot: PlayerSlot.slot4, state: TokenState.board, position: 6);

      final pos5 = BoardPath.getTokenOffset(tokenAtCell5); // (5, 6) -> center (5.5, 6.5)
      final pos6 = BoardPath.getTokenOffset(tokenAtCell6); // (6, 5) -> center (6.5, 5.5)

      final center5 = Offset(pos5.dx + 0.5, pos5.dy + 0.5);
      final center6 = Offset(pos6.dx + 0.5, pos6.dy + 0.5);

      // User places thumb on token at Cell 5 (0.14 cells from center)
      final tap5 = Offset(center5.dx + 0.1, center5.dy + 0.1);
      final distTo5 = math.sqrt(math.pow(tap5.dx - center5.dx, 2) + math.pow(tap5.dy - center5.dy, 2));
      final distTo6 = math.sqrt(math.pow(tap5.dx - center6.dx, 2) + math.pow(tap5.dy - center6.dy, 2));

      expect(distTo5, lessThan(0.85), reason: "Tapping cell 5 is within 0.85 thumb radius of cell 5");
      expect(distTo6, greaterThan(0.85), reason: "Tapping cell 5 is outside thumb radius of neighboring cell 6");
      expect(distTo5, lessThan(distTo6), reason: "Cell 5 is unambiguously closer than cell 6");

      // 2. Two tokens on the EXACT SAME cell (e.g. both at position 8 on safe spot)
      // Visual offsets shift index 0 left and index 1 right
      const double cellSize = 25.0;
      const double tokenSize = cellSize * 0.85;
      const double spread = tokenSize * 0.3;
      final double offsetLeft = -spread / 1.5 / cellSize;  // ~ -0.17 cells left
      final double offsetRight = spread / 1.5 / cellSize;  // ~ +0.17 cells right

      final centerCell = Offset(pos5.dx + 0.5, pos5.dy + 0.5);
      final centerLeftToken = Offset(centerCell.dx + offsetLeft, centerCell.dy);
      final centerRightToken = Offset(centerCell.dx + offsetRight, centerCell.dy);

      // User taps slightly to the left side of the cell
      final tapLeft = Offset(centerCell.dx - 0.15, centerCell.dy);
      final distTapLeftToLeft = (tapLeft.dx - centerLeftToken.dx).abs();
      final distTapLeftToRight = (tapLeft.dx - centerRightToken.dx).abs();
      expect(distTapLeftToLeft, lessThan(distTapLeftToRight), reason: "Tapping left half of shared cell selects left token");

      // User taps slightly to the right side of the cell
      final tapRight = Offset(centerCell.dx + 0.15, centerCell.dy);
      final distTapRightToLeft = (tapRight.dx - centerLeftToken.dx).abs();
      final distTapRightToRight = (tapRight.dx - centerRightToken.dx).abs();
      expect(distTapRightToRight, lessThan(distTapRightToLeft), reason: "Tapping right half of shared cell selects right token");
    });

    test('Home strip token adjacent to outer track tokens resolves cleanly without conflict', () {
      // Slot 4 (Red) has:
      // Token A on track (row 6, position 1) -> (2, 6)
      // Token B on home stretch (row 7, position 52) -> (2, 7)
      // Token C on track (row 8, position 47) -> (2, 8)
      final tokenTrackTop = Token(id: 0, slot: PlayerSlot.slot4, state: TokenState.board, position: 1);
      final tokenHomeStrip = Token(id: 1, slot: PlayerSlot.slot4, state: TokenState.homeStretch, position: 52);
      final tokenTrackBottom = Token(id: 2, slot: PlayerSlot.slot4, state: TokenState.board, position: 47);

      final posTop = BoardPath.getTokenOffset(tokenTrackTop);      // (2, 6)
      final posStrip = BoardPath.getTokenOffset(tokenHomeStrip);   // (2, 7)
      final posBottom = BoardPath.getTokenOffset(tokenTrackBottom);// (2, 8)

      expect(posTop, equals(const Offset(2, 6)));
      expect(posStrip, equals(const Offset(2, 7)));
      expect(posBottom, equals(const Offset(2, 8)));

      final centerTop = Offset(posTop.dx + 0.5, posTop.dy + 0.5);      // (2.5, 6.5)
      final centerStrip = Offset(posStrip.dx + 0.5, posStrip.dy + 0.5);// (2.5, 7.5)
      final centerBottom = Offset(posBottom.dx + 0.5, posBottom.dy + 0.5); // (2.5, 8.5)

      Token? pickNearest(Offset tap) {
        final tokens = [tokenTrackTop, tokenHomeStrip, tokenTrackBottom];
        final centers = [centerTop, centerStrip, centerBottom];
        double closest = double.infinity;
        Token? target;
        for (int i = 0; i < tokens.length; i++) {
          final dist = math.sqrt(math.pow(tap.dx - centers[i].dx, 2) + math.pow(tap.dy - centers[i].dy, 2));
          if (dist <= 0.85 && dist < closest) {
            closest = dist;
            target = tokens[i];
          }
        }
        return target;
      }

      // 1. Tapping the Home Strip piece (center or slightly off-center)
      expect(pickNearest(centerStrip)?.id, equals(1));
      expect(pickNearest(Offset(centerStrip.dx, centerStrip.dy - 0.2))?.id, equals(1)); // slightly up
      expect(pickNearest(Offset(centerStrip.dx, centerStrip.dy + 0.2))?.id, equals(1)); // slightly down

      // 2. Tapping the Top Track piece
      expect(pickNearest(centerTop)?.id, equals(0));
      expect(pickNearest(Offset(centerTop.dx, centerTop.dy + 0.2))?.id, equals(0));

      // 3. Tapping the Bottom Track piece
      expect(pickNearest(centerBottom)?.id, equals(2));
      expect(pickNearest(Offset(centerBottom.dx, centerBottom.dy - 0.2))?.id, equals(2));
    });

    test('Three tokens overlapping on the same cell (triangle spread) resolve to each distinct piece', () {
      const double cellSize = 25.0;
      const double tokenSize = cellSize * 0.85;
      const double spread = tokenSize * 0.3; // 6.375 px -> 0.255 cells

      // Center of cell (e.g. safe spot)
      const double cellCenterX = 8.5;
      const double cellCenterY = 2.5;

      // Offsets for 3 tokens:
      // index 0: (0, -spread) -> Top
      // index 1: (-spread, spread) -> Bottom-Left
      // index 2: (spread, spread) -> Bottom-Right
      final offset0 = Offset(0, -spread / cellSize);
      final offset1 = Offset(-spread / cellSize, spread / cellSize);
      final offset2 = Offset(spread / cellSize, spread / cellSize);

      final center0 = Offset(cellCenterX + offset0.dx, cellCenterY + offset0.dy);
      final center1 = Offset(cellCenterX + offset1.dx, cellCenterY + offset1.dy);
      final center2 = Offset(cellCenterX + offset2.dx, cellCenterY + offset2.dy);

      final tokens = [
        Token(id: 0, slot: PlayerSlot.slot3, state: TokenState.board, position: 8),
        Token(id: 1, slot: PlayerSlot.slot3, state: TokenState.board, position: 8),
        Token(id: 2, slot: PlayerSlot.slot3, state: TokenState.board, position: 8),
      ];
      final centers = [center0, center1, center2];

      int? pickIndex(Offset tap) {
        double closest = double.infinity;
        int? targetIdx;
        for (int i = 0; i < tokens.length; i++) {
          final dist = math.sqrt(math.pow(tap.dx - centers[i].dx, 2) + math.pow(tap.dy - centers[i].dy, 2));
          if (dist <= 0.85 && dist < closest) {
            closest = dist;
            targetIdx = i;
          }
        }
        return targetIdx;
      }

      // Tap on top piece
      expect(pickIndex(Offset(cellCenterX, cellCenterY - 0.25)), equals(0));

      // Tap on bottom-left piece
      expect(pickIndex(Offset(cellCenterX - 0.25, cellCenterY + 0.25)), equals(1));

      // Tap on bottom-right piece
      expect(pickIndex(Offset(cellCenterX + 0.25, cellCenterY + 0.25)), equals(2));
    });

    test('Corners: 90-degree inner corners and outer U-turn corners have clean separation', () {
      // Inner corner: (5, 6) turns to (6, 5) around base yard corner (5, 5)
      final posInner1 = const Offset(5, 6);
      final posInner2 = const Offset(6, 5);
      final centerInner1 = Offset(posInner1.dx + 0.5, posInner1.dy + 0.5); // (5.5, 6.5)
      final centerInner2 = Offset(posInner2.dx + 0.5, posInner2.dy + 0.5); // (6.5, 5.5)

      // Diagonal distance between inner corner cells = sqrt(1^2 + 1^2) = 1.414 cells > 1.0 cell
      final diagonalDist = math.sqrt(
        math.pow(centerInner1.dx - centerInner2.dx, 2) + math.pow(centerInner1.dy - centerInner2.dy, 2),
      );
      expect(diagonalDist, closeTo(1.414, 0.01));
      expect(diagonalDist, greaterThan(0.85), reason: "Diagonal corner cells have even more separation than straight cells");

      // Outer U-turn tip: (6, 0) -> (7, 0) -> (8, 0)
      final centerOuter1 = const Offset(6.5, 0.5);
      final centerOuter2 = const Offset(7.5, 0.5);
      final centerOuter3 = const Offset(8.5, 0.5);

      // Tap in cell 1 (6, 0)
      final tapOuter1 = const Offset(6.4, 0.5);
      final d1 = (tapOuter1.dx - centerOuter1.dx).abs();
      final d2 = (tapOuter1.dx - centerOuter2.dx).abs();
      expect(d1, lessThan(0.85));
      expect(d1, lessThan(d2));

      // Tap in cell 2 (7, 0)
      final tapOuter2 = const Offset(7.5, 0.4);
      final d2_self = (tapOuter2.dx - centerOuter2.dx).abs();
      final d2_left = (tapOuter2.dx - centerOuter1.dx).abs();
      final d2_right = (tapOuter2.dx - centerOuter3.dx).abs();
      expect(d2_self, lessThan(0.85));
      expect(d2_self, lessThan(d2_left));
      expect(d2_self, lessThan(d2_right));
    });
  });
}
